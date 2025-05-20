package com.aclick.bluetooth_classic

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.lifecycleScope
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import java.io.IOException
import java.util.UUID

/**
 * 블루투스 연결 관련 기능 담당
 * 애플리케이션 수명주기와 연결하여 메모리 누수 방지
 */
class ConnectionManager(
    private val context: Context,
    private val channel: MethodChannel,
    private val bluetoothAdapter: BluetoothAdapter?
) : LifecycleEventObserver {
    // 현재 연결
    private var currentConnection: BluetoothConnection? = null
    
    // 커스텀 UUID
    private var customUuid: UUID? = null
    
    // 코루틴 관리를 위한 job 분리
    private val job = SupervisorJob()
    private val coroutineScope = CoroutineScope(Dispatchers.IO + job)
    
    // 현재 진행 중인 작업
    private var currentJob: Job? = null
    
    init {
        // 생명주기 관찰자로 등록
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
    }
    
    /**
     * 생명주기 이벤트 처리
     */
    override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
        when (event) {
            Lifecycle.Event.ON_DESTROY -> dispose()
            else -> {}
        }
    }
    
    /**
     * 현재 연결된 연결 가져오기
     */
    fun getCurrentConnection(): BluetoothConnection? = currentConnection
    
    /**
     * 현재 연결 설정
     */
    fun setCurrentConnection(connection: BluetoothConnection?) {
        currentConnection = connection
        connection?.setupStreamsFromSocket()
    }
    
    /**
     * 커스텀 UUID 설정
     */
    fun setCustomUuid(uuid: UUID) {
        Log.d(Constants.TAG, "🔑 커스텀 UUID 설정: $uuid")
        customUuid = uuid
    }
    
    /**
     * 연결에 사용할 UUID 가져오기
     */
    fun getConnectionUuid(): UUID {
        return customUuid ?: Constants.SPP_UUID
    }
    
    /**
     * 블루투스 연결 상태 확인
     */
    fun isConnected(): Boolean {
        return currentConnection != null && currentConnection?.isConnected() == true
    }
    
    /**
     * 주소로 블루투스 기기에 연결
     */
    fun connect(address: String, callback: (Boolean) -> Unit) {
        // 블루투스 어댑터 확인
        if (bluetoothAdapter == null) {
            callback(false)
            return
        }
        
        // 권한 확인
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasPermission = context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            if (!hasPermission) {
                callback(false)
                return
            }
        }
        
        try {
            // 주소로 기기 가져오기
            val device = bluetoothAdapter.getRemoteDevice(address)
            connect(device, callback)
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to connect by address", e)
            callback(false)
        }
    }
    
    /**
     * 블루투스 기기에 연결
     */
    fun connect(device: BluetoothDevice, callback: (Boolean) -> Unit) {
        // 이미 연결된 경우 해제
        if (currentConnection?.getDevice()?.address == device.address && currentConnection?.isConnected() == true) {
            callback(true)
            return
        }
        
        // 기존 연결 해제
        disconnect()
        
        // 새 연결 시작
        coroutineScope.launch {
            try {
                withTimeout(Constants.CONNECTION_TIMEOUT) {
                    // 사용할 UUID 결정
                    val uuid = getConnectionUuid()
                    
                    Log.d(Constants.TAG, "Connecting to device: ${device.address} with UUID: $uuid")
                    
                    // 소켓 생성 시도
                    val socket = createBluetoothSocket(device, uuid)
                    
                    // 연결 시도
                    socket.connect()
                    
                    // 연결 성공
                    val connection = BluetoothConnection(device, context, channel, uuid, socket)
                    currentConnection = connection
                    connection.setupStreamsFromSocket()
                    
                    // Flutter에 연결 알림
                    coroutineScope.launch(Dispatchers.Main) {
                        channel.invokeMethod("onDeviceConnected", mapOf(
                            "address" to device.address,
                            "name" to (device.name ?: "Unknown Device")
                        ))
                    }
                    
                    callback(true)
                }
            } catch (e: Exception) {
                Log.e(Constants.TAG, "Failed to connect to device: ${device.address}", e)
                disconnect()
                callback(false)
            }
        }
    }
    
    /**
     * 블루투스 소켓 생성
     */
    private fun createBluetoothSocket(device: BluetoothDevice, uuid: UUID): BluetoothSocket {
        try {
            // 기본 방식으로 소켓 생성 시도
            return device.createRfcommSocketToServiceRecord(uuid)
        } catch (e: IOException) {
            Log.e(Constants.TAG, "Failed to create socket using createRfcommSocketToServiceRecord", e)
            
            // 대체 방식 시도 (리플렉션)
            try {
                val method = device.javaClass.getMethod("createRfcommSocket", Int::class.java)
                return method.invoke(device, 1) as BluetoothSocket
            } catch (e2: Exception) {
                Log.e(Constants.TAG, "Failed to create socket using reflection", e2)
                throw e
            }
        }
    }
    
    /**
     * 현재 연결 해제
     */
    fun disconnect() {
        currentConnection?.disconnect()
        currentConnection = null
    }
    
    /**
     * 데이터 전송
     */
    fun sendData(data: List<Int>, callback: (Boolean) -> Unit) {
        if (currentConnection == null || !isConnected()) {
            callback(false)
            return
        }
        
        // 전송 시도
        coroutineScope.launch {
            try {
                val byteArray = ByteArray(data.size) { i -> data[i].toByte() }
                val success = currentConnection?.sendData(byteArray) ?: false
                callback(success)
            } catch (e: Exception) {
                Log.e(Constants.TAG, "Failed to send data", e)
                callback(false)
            }
        }
    }
    
    /**
     * 연결 해제 처리
     */
    fun handleDisconnection(device: BluetoothDevice) {
        if (currentConnection?.getDevice()?.address == device.address) {
            Log.d(Constants.TAG, "Current device disconnected: ${device.address}")
            
            // 현재 연결 정리
            currentConnection?.disconnect()
            currentConnection = null
            
            // Flutter에 연결 해제 알림
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onDeviceDisconnected", mapOf(
                    "address" to device.address,
                    "name" to (device.name ?: "Unknown Device"),
                    "error" to "Device disconnected"
                ))
            }
        }
    }
    
    /**
     * ACL_CONNECTED 이벤트 처리
     */
    fun handleAclConnected(device: BluetoothDevice, serverSocketManager: ServerSocketManager): Boolean {
        try {
            Log.d(Constants.TAG, "🔵 장치 연결됨: ${device.address} (${device.name ?: "Unknown"})")
            
            // 이미 동일한 장치에 연결되어 있는지 확인
            if (currentConnection?.getDevice()?.address == device.address) {
                Log.d(Constants.TAG, "이미 연결된 장치: ${device.address}")
                return true
            }

            // 현재 연결이 있으면 종료
            disconnect()
            
            // 서버 소켓 리스닝 중인지 확인
            if (serverSocketManager.isListening()) {
                // 서버 소켓 모드에서는 서버소켓이 장치 처리
                serverSocketManager.handleIncomingConnection(device, this)
            } else {
                // 클라이언트 모드에서는 기존 연결 처리
                Log.d(Constants.TAG, "클라이언트 모드에서 연결 처리: ${device.address}")
                handleExistingConnection(device, getConnectionUuid())
            }
            
            // Flutter에 연결 이벤트 알림
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onDeviceConnected", mapOf(
                    "address" to device.address,
                    "name" to (device.name ?: "Unknown Device"),
                    "type" to "classic"
                ))
            }
            
            return true
        } catch (e: Exception) {
            Log.e(Constants.TAG, "연결 처리 실패: ${e.message}")
            return false
        }
    }
    
    /**
     * 이미 연결된 장치 처리
     */
    fun handleExistingConnection(device: BluetoothDevice, uuid: UUID): Boolean {
        try {
            Log.d(Constants.TAG, "기존 연결 처리: ${device.address} (UUID: $uuid)")
            
            // 현재 연결이 없으면
            if (currentConnection == null) {
                // 새 연결 생성
                currentConnection = BluetoothConnection(device, context, channel, uuid)
            }
            
            // Flutter에 연결 알림
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onDeviceConnected", mapOf(
                    "address" to device.address,
                    "name" to (device.name ?: "Unknown Device"),
                    "type" to "classic"
                ))
            }
            
            return true
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to handle existing connection: ${device.address}", e)
            return false
        }
    }
    
    /**
     * 리소스 정리
     */
    fun dispose() {
        disconnect()
        // 생명주기 관찰자 제거
        ProcessLifecycleOwner.get().lifecycle.removeObserver(this)
        
        // 코루틴 작업 취소
        currentJob?.cancel()
        job.cancelChildren()
        job.cancel()
    }
}
