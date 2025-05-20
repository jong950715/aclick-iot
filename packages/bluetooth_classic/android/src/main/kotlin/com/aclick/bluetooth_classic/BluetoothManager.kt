package com.aclick.bluetooth_classic

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import kotlinx.coroutines.*
import java.io.IOException
import java.util.*
import kotlin.collections.HashMap

// Constants
private const val REQUEST_ENABLE_BT = 1
private const val TAG = "BluetoothManager"
private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // Serial Port Profile UUID

/**
 * Manages Bluetooth functionality including:
 * - Device discovery
 * - Connection handling
 * - Data transfer
 */
class BluetoothManager(
    private val context: Context,
    private val channel: MethodChannel,
    private val permissionManager: PermissionManager
) : ActivityResultListener {
    
    // 커스텀 UUID 관리를 위한 변수
    private var customUuid: UUID? = null
    
    // Bluetooth adapter
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothManager?.adapter
    }

    // Connection and Discovery related variables
    private var discoveryCallback: ((Boolean) -> Unit)? = null
    private var enableBluetoothCallback: ((Boolean) -> Unit)? = null
    private var currentConnection: BluetoothConnection? = null
    
    /**
     * 커스텀 UUID 설정 메서드
     * Flutter에서 지정한 UUID를 설정하여 모든 블루투스 연결에 사용합니다.
     */
    fun setCustomUuid(uuid: UUID) {
        Log.d(TAG, "🔑 커스텀 UUID 설정: $uuid")
        customUuid = uuid
    }
    
    /**
     * 현재 사용할 UUID 반환
     * 커스텀 UUID가 설정되어 있으면 해당 UUID를 반환하고,
     * 그렇지 않으면 기본 SPP UUID를 반환합니다.
     */
    fun getConnectionUuid(): UUID {
        return customUuid ?: BluetoothConnection.SPP_UUID
    }
    
    private var isDiscovering = false
    
    // Server socket related variables
    private var serverSocket: android.bluetooth.BluetoothServerSocket? = null
    private var isListening = false
    // acceptThread 변수 삭제됨 - 2025-05-17
    
    // List of discovered devices (address -> device map)
    private val discoveredDevices = HashMap<String, BluetoothDevice>()
    
    // Coroutine scope for async operations
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /**
     * BroadcastReceiver for Bluetooth discovery and state changes
     */
    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    handleDeviceFound(intent)
                }
                BluetoothAdapter.ACTION_DISCOVERY_STARTED -> {
                    isDiscovering = true
                    Log.d(TAG, "Discovery started")
                }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    isDiscovering = false
                    Log.d(TAG, "Discovery finished")
                    // Notify that discovery has finished
                    discoveryCallback?.invoke(true)
                    discoveryCallback = null
                }
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    handleBluetoothStateChange(state)
                }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    
                    val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                    handleBondStateChanged(device, state)
                }
                BluetoothDevice.ACTION_ACL_CONNECTED -> {
                    // 장치 연결 이벤트
                    Log.d(TAG, "🔵 ACTION_ACL_CONNECTED 이벤트 수신")
                    val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    
                    if (device != null) {
                        Log.d(TAG, "🔵 장치 연결됨: ${device.address} (${device.name ?: "Unknown"})")
                        
                        // 현재 연결된 장치와 비교하여 새로운 연결인지 확인
                        if (currentConnection?.getDevice()?.address != device.address) {
                            try {
                                // 현재 연결이 있으면 종료
                                currentConnection?.disconnect()
                                
                                // 리스닝 상태인지 확인
                                if (isListening && serverSocket != null) {
                                    Log.d(TAG, "📟 리스닝 모드에서 서버 소켓 accept() 호출: ${device.address}")
                                    
                                    // 블로킹 작업이므로 코루틴에서 실행
                                    coroutineScope.launch(Dispatchers.IO) {
                                        try {
                                            // 서버 소켓의 accept() 호출
                                            val clientSocket = serverSocket?.accept()
                                            
                                            if (clientSocket != null) {
                                                // Main 스레드에서 UI 갱신
                                                withContext(Dispatchers.Main) {
                                                    Log.d(TAG, "📞 Accept 성공: ${device.address}")
                                                    
                                                    // 새 연결 객체 생성 (소켓 직접 활용)
                                                    val newConnection = BluetoothConnection(device, context, channel, getConnectionUuid(), clientSocket)
                                                    currentConnection = newConnection
                                                    
                                                    // 스트림 열고 리스닝 시작
                                                    val success = newConnection.setupStreamsFromSocket()
                                                    Log.d(TAG, "📶 서버 소켓 연결 완료(${if (success) "성공" else "실패"}): ${device.address}")
                                                    
                                                    // Flutter에 연결 성공 알림
                                                    channel.invokeMethod("onDeviceConnected", mapOf(
                                                        "address" to device.address,
                                                        "name" to (device.name ?: "Unknown Device"),
                                                        "type" to "classic"
                                                    ))
                                                }
                                            } else {
                                                Log.e(TAG, "❌ Accept 가 null 반환: ${device.address}")
                                            }
                                        } catch (e: IOException) {
                                            Log.e(TAG, "❌ Accept 에서 예외 발생: ${e.message}")
                                        }
                                    }
                                } else {
                                    // 리스닝 상태가 아닐 경우 (클라이언트 역할), 기존의 방식으로 처리
                                    Log.d(TAG, "👁 클라이언트 역할로 연결 처리: ${device.address}")
                                    
                                    // 새 BluetoothConnection 생성 및 설정 (커스텀 UUID 전달)
                                    val newConnection = BluetoothConnection(device, context, channel, getConnectionUuid())
                                    currentConnection = newConnection
                                    Log.d(TAG, "🔵 새 연결 객체 생성(UUID: ${getConnectionUuid()}): ${device.address}")
                                    
                                    // 이미 연결된 장치를 위한 특별 메서드 호출
                                    val success = newConnection.setupAlreadyConnected(getConnectionUuid())
                                    Log.d(TAG, "🔵 연결 초기화 및 리스닝 시작(${if (success) "성공" else "실패"}): ${device.address}")
                                }
                                
                                // Flutter에서 이미 이벤트를 받았을 수 있으므로 한 번 더 알림
                                coroutineScope.launch(Dispatchers.Main) {
                                    channel.invokeMethod("onDeviceConnected", mapOf(
                                        "address" to device.address,
                                        "name" to (device.name ?: "Unknown Device"),
                                        "type" to "classic"
                                    ))
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "🔴 연결 객체 생성 실패: ${e.message}")
                            }
                        }
                    }
                }
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                    // 장치 연결 해제 이벤트 ACTION_CONNECTION_STATE_CHANGED
                    Log.d(TAG, "🔴 ACTION_ACL_DISCONNECTED 이벤트 수신")
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    
                    if (device != null) {
                        Log.d(TAG, "🔴 장치 연결 해제됨: ${device.address} (${device.name ?: "Unknown"})")
                        
                        // Flutter에게 연결 해제 이벤트 알림
                        channel.invokeMethod("onDeviceDisconnected", mapOf(
                            "address" to device.address
                        ))
                        
                        // 현재 연결 객체 해제
                        if (currentConnection?.getDevice()?.address == device.address) {
                            currentConnection = null
                        }
                    }
                }
            }
        }
    }
    
    init {
        registerBluetoothReceivers()
    }
    
    /**
     * Register broadcast receivers for Bluetooth events
     */
    private fun registerBluetoothReceivers() {
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            
            // 찾았다! 연결 이벤트가 등록되지 않았음 (2025-05-17)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        context.registerReceiver(bluetoothReceiver, filter)
    }
    
    /**
     * Handle a newly discovered device
     */
    private fun handleDeviceFound(intent: Intent) {
        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
        
        val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt()
        
        device?.let {
            discoveredDevices[it.address] = it
            
            // Get device info and send to Flutter
            val deviceInfo = mapOf(
                "address" to it.address,
                "name" to (it.name ?: "Unknown Device"),
                "rssi" to rssi,
                "isPaired" to (it.bondState == BluetoothDevice.BOND_BONDED),
                "deviceClass" to it.bluetoothClass.majorDeviceClass
            )
            
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onDeviceFound", deviceInfo)
            }
        }
    }
    
    /**
     * Handle Bluetooth state changes
     */
    private fun handleBluetoothStateChange(state: Int) {
        when (state) {
            BluetoothAdapter.STATE_ON -> {
                Log.d(TAG, "Bluetooth turned on")
                coroutineScope.launch(Dispatchers.Main) {
                    channel.invokeMethod("onBluetoothStateChanged", mapOf("state" to "enabled"))
                    enableBluetoothCallback?.invoke(true)
                    enableBluetoothCallback = null
                }
            }
            BluetoothAdapter.STATE_OFF -> {
                Log.d(TAG, "Bluetooth turned off")
                coroutineScope.launch(Dispatchers.Main) {
                    channel.invokeMethod("onBluetoothStateChanged", mapOf("state" to "disabled"))
                    
                    // Disconnect if we were connected
                    currentConnection?.let {
                        disconnect()
                    }
                }
            }
            BluetoothAdapter.STATE_TURNING_ON -> {
                Log.d(TAG, "Bluetooth turning on")
                coroutineScope.launch(Dispatchers.Main) {
                    channel.invokeMethod("onBluetoothStateChanged", mapOf("state" to "turningOn"))
                }
            }
            BluetoothAdapter.STATE_TURNING_OFF -> {
                Log.d(TAG, "Bluetooth turning off")
                coroutineScope.launch(Dispatchers.Main) {
                    channel.invokeMethod("onBluetoothStateChanged", mapOf("state" to "turningOff"))
                }
            }
        }
    }
    
    /**
     * Handle bond state changes
     */
    private fun handleBondStateChanged(device: BluetoothDevice?, state: Int) {
        device?.let {
            when (state) {
                BluetoothDevice.BOND_BONDED -> {
                    Log.d(TAG, "Device bonded: ${it.address}")
                    coroutineScope.launch(Dispatchers.Main) {
                        channel.invokeMethod("onDevicePaired", mapOf(
                            "address" to it.address,
                            "name" to (it.name ?: "Unknown Device")
                        ))
                    }
                }
                BluetoothDevice.BOND_NONE -> {
                    Log.d(TAG, "Device bond removed: ${it.address}")
                    coroutineScope.launch(Dispatchers.Main) {
                        channel.invokeMethod("onDeviceUnpaired", mapOf(
                            "address" to it.address,
                            "name" to (it.name ?: "Unknown Device")
                        ))
                    }
                }
                BluetoothDevice.BOND_BONDING -> {
                    Log.d(TAG, "Device bonding in progress: ${it.address}")
                    // 페어링 진행 중인 경우에는 추가 작업이 필요하지 않을 수 있습니다.
                }
                else -> {
                    Log.d(TAG, "Unknown bond state: $state for device: ${it.address}")
                }
            }
        }
    }
    
    /**
     * Check if Bluetooth is available
     */
    fun isAvailable(): Boolean {
        return bluetoothAdapter != null
    }
    
    /**
     * Check if Bluetooth is enabled
     */
    fun isEnabled(): Boolean {
        return bluetoothAdapter?.isEnabled == true
    }
    
    /**
     * Check if connected to any device
     */
    fun isConnected(): Boolean {
        return currentConnection?.isConnected() == true
    }
    
    /**
     * Request Bluetooth to be enabled
     */
    fun requestEnable(activity: Activity, callback: (Boolean) -> Unit) {
        if (!isAvailable()) {
            callback(false)
            return
        }
        
        if (isEnabled()) {
            callback(true)
            return
        }
        
        // Check for required permissions
        permissionManager.requestBluetoothPermissions(activity) { granted ->
            if (!granted) {
                callback(false)
                return@requestBluetoothPermissions
            }
            
            // Save callback to be invoked when Bluetooth is enabled
            enableBluetoothCallback = callback
            
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            activity.startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
        }
    }
    
    /**
     * Start Bluetooth device discovery
     */
    fun startScan(activity: Activity, onlyPaired: Boolean, callback: (Boolean) -> Unit) {
        if (!isAvailable()) {
            callback(false)
            return
        }
        
        if (!isEnabled()) {
            callback(false)
            return
        }
        
        // Check for required permissions
        permissionManager.requestBluetoothPermissions(activity) { granted ->
            if (!granted) {
                callback(false)
                return@requestBluetoothPermissions
            }
            
            // Clear previous discovered devices
            if (!onlyPaired) {
                discoveredDevices.clear()
                
                // If already discovering, cancel it first
                if (isDiscovering) {
                    bluetoothAdapter?.cancelDiscovery()
                }
                
                // Start new discovery
                discoveryCallback = callback
                bluetoothAdapter?.startDiscovery()
            } else {
                // Get only paired devices
                sendPairedDevices()
                callback(true)
            }
        }
    }
    
    /**
     * Stop Bluetooth device discovery
     */
    fun stopScan() {
        if (isAvailable() && isEnabled() && isDiscovering) {
            bluetoothAdapter?.cancelDiscovery()
        }
    }
    
    /**
     * Get paired devices
     */
    fun getPairedDevices(activity: Activity, callback: (List<Map<String, Any>>) -> Unit) {
        if (!isAvailable() || !isEnabled()) {
            callback(emptyList())
            return
        }
        
        // Check for required permissions
        permissionManager.requestBluetoothPermissions(activity) { granted ->
            if (!granted) {
                callback(emptyList())
                return@requestBluetoothPermissions
            }
            
            val devices = bluetoothAdapter?.bondedDevices?.map { device ->
                mapOf(
                    "address" to device.address,
                    "name" to (device.name ?: "Unknown Device"),
                    "isPaired" to true,
                    "deviceClass" to device.bluetoothClass.majorDeviceClass
                )
            } ?: emptyList()
            
            callback(devices)
        }
    }
    
    /**
     * Send paired devices to Flutter
     */
    private fun sendPairedDevices() {
        if (!isAvailable() || !isEnabled()) {
            return
        }
        
        bluetoothAdapter?.bondedDevices?.forEach { device ->
            val deviceInfo = mapOf(
                "address" to device.address,
                "name" to (device.name ?: "Unknown Device"),
                "isPaired" to true,
                "deviceClass" to device.bluetoothClass.majorDeviceClass
            )
            
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onDeviceFound", deviceInfo)
            }
        }
    }
    
    /**
     * Connect to a Bluetooth device by address
     */
    fun connect(address: String, callback: (Boolean) -> Unit) {
        if (!isAvailable() || !isEnabled()) {
            callback(false)
            return
        }
        
        // Find the device
        val device = bluetoothAdapter?.getRemoteDevice(address)
        if (device == null) {
            Log.e(TAG, "❌ 기기를 찾을 수 없습니다: $address")
            callback(false)
            return
        }
        
        // Connect to the found device
        connect(device, callback)
    }
    
    /**
     * Connect to a Bluetooth device directly
     */
    fun connect(device: BluetoothDevice, callback: (Boolean) -> Unit) {
        Log.d(TAG, "🔌 연결 시도: ${device.address}")
        
        // Cancel discovery because it's resource intensive
        bluetoothAdapter?.cancelDiscovery()
        
        // Disconnect from current device if any
        currentConnection?.disconnect()
        
        // Create a new connection
        val connectionUuid = getConnectionUuid()
        Log.d(TAG, "🔑 연결에 사용할 UUID: $connectionUuid")
        val connection = BluetoothConnection(device, context, channel, connectionUuid)
        currentConnection = connection
        
        try {
            // Connect to the device
            val success = connection.connect()
            if (success) {
                // 연결 성공 시 콜백 전달
                callback(true)
            } else {
                // 실패 시 currentConnection 초기화
                currentConnection = null
                callback(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 연결 오류: ${e.message}")
            currentConnection = null
            callback(false)
        }
    }
    
    /**
     * Disconnect from the current device
     */
    fun disconnect() {
        currentConnection?.disconnect()
        currentConnection = null
    }
    
    /**
     * Send data to the connected device
     */
    fun sendData(data: List<Int>, callback: (Boolean) -> Unit) {
        if (currentConnection?.isConnected() != true) {
            Log.e(TAG, "📤 전송 실패: 연결되지 않음")
            callback(false)
            return
        }
        
        try {
            // Convert List<Int> to ByteArray
            val byteArray = data.map { it.toByte() }.toByteArray()
            
            // Send data - 새로운 구현은 직접 Boolean 반환
            val success = currentConnection?.sendData(byteArray) ?: false
            callback(success)
        } catch (e: Exception) {
            Log.e(TAG, "📤 데이터 전송 오류: ${e.message}")
            callback(false)
        }
    }
    
    /**
     * Clean up resources
     */
    fun dispose() {
        // Unregister receiver
        try {
            context.unregisterReceiver(bluetoothReceiver)
        } catch (e: IllegalArgumentException) {
            // Receiver not registered, ignore
        }
        
        // Cancel discovery
        if (isDiscovering) {
            bluetoothAdapter?.cancelDiscovery()
        }
        
        // Stop listening and clean up server socket
        stopListening()
        
        // Disconnect any existing connection
        currentConnection?.disconnect()
        currentConnection = null
        
        // Cancel coroutines
        coroutineScope.cancel()
    }
    
    /**
     * Handle activity result (for enable Bluetooth request)
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_ENABLE_BT) {
            val success = resultCode == Activity.RESULT_OK
            enableBluetoothCallback?.invoke(success)
            enableBluetoothCallback = null
            return true
        }
        return false
    }
    
    /**
     * Start listening for incoming connections using RFCOMM
     *
     * @param name Service name for SDP record
     * @param uuid UUID for SDP record (if custom UUID is set, it will override this)
     * @param secured If true, will use a secure socket
     * @param callback Result callback with success flag
     */
    fun listenUsingRfcomm(name: String, uuid: UUID, secured: Boolean = true, callback: (Boolean) -> Unit) {
        // 사용할 UUID를 결정 (커스텀 UUID가 설정되어 있으면 그것을 사용)
        val actualUuid = customUuid ?: uuid
        Log.d(TAG, "🔑 리스닝용 사용할 UUID: $actualUuid${if (customUuid != null) " (커스텀)" else " (입력된 값)"}")
        
        if (!isAvailable() || !isEnabled()) {
            callback(false)
            return
        }
        
        // Check permissions first
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasPermission = context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            if (!hasPermission) {
                callback(false)
                return
            }
        }
        
        // Stop any existing listening
        stopListening()
        
        try {
            // Create a new listening server socket
            val btAdapter = bluetoothAdapter ?: throw IOException("Bluetooth adapter not available")
            
            // Create the server socket (actualUuid 사용)
            val serverSocket = if (secured) {
                btAdapter.listenUsingRfcommWithServiceRecord(name, actualUuid)
            } else {
                btAdapter.listenUsingInsecureRfcommWithServiceRecord(name, actualUuid)
            }
            
            // Store the server socket for later use
            this.serverSocket = serverSocket
            isListening = true
            
            // Notify success
            callback(true)
            
            // Notify Flutter that we're listening
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onListening", mapOf(
                    "uuid" to uuid.toString(),
                    "name" to name,
                    "secured" to secured
                ))
            }
        } catch (e: IOException) {
            Log.e(TAG, "Failed to create server socket", e)
            stopListening()
            callback(false)
        }
    }
    
    // NOTE: acceptConnection 메서드가 이 위치에 존재했지만 완전히 삭제되었습니다.
    // 이 메서드는 실제로 과거에 제대로 동작한 적이 없었으며,
    // 네이티브와 Flutter 사이의 교착 상태를 출벌하는 코드였습니다.
    // 이제 연결은 ACTION_ACL_CONNECTED 및 ACTION_ACL_DISCONNECTED 브로드캐스트를 통해
    // 자동으로 감지되고 처리됩니다.
    // BluetoothReceiver의 onReceive 메서드에서 이벤트를 처리합니다.
    //
    // 이 코드가 제거된 날짜: 2025-05-17
    
    /**
     * Stop listening for incoming connections
     */
    fun stopListening() {
        // Close the server socket
        try {
            serverSocket?.close()
        } catch (e: IOException) {
            Log.e(TAG, "Failed to close server socket", e)
        }
        
        serverSocket = null
        isListening = false
    }
    
    // NOTE: AcceptThread 클래스가 이 위치에 존재했지만 완전히 삭제되었습니다. (2025-05-17)
    // 연결은 이제 ACTION_ACL_CONNECTED 브로드캐스트 이벤트를 통해 처리됩니다.
}
