package com.aclick.bluetooth_classic

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager as AndroidBluetoothManager
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import java.util.*

/**
 * 블루투스 기능 총괄 관리 클래스
 *
 * 이 클래스는 다음과 같은 특화된 매니저 클래스들을 통해 각 책임을 위임합니다:
 * - DiscoveryManager: 디바이스 검색 담당
 * - ConnectionManager: 연결 관리 담당
 * - ServerSocketManager: 서버 소켓 및 리스닝 담당
 * - BluetoothEventDispatcher: 이벤트 처리 담당
 */
class BluetoothManager(
    private val context: Context,
    private val channel: MethodChannel,
    private val permissionManager: PermissionManager
) : ActivityResultListener {

    // Bluetooth adapter
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? AndroidBluetoothManager
        bluetoothManager?.adapter
    }

    // 특화된 매니저 클래스들
    private val discoveryManager: DiscoveryManager by lazy {
        DiscoveryManager(context, channel, permissionManager, bluetoothAdapter)
    }

    private val connectionManager: ConnectionManager by lazy {
        ConnectionManager(context, channel, bluetoothAdapter)
    }

    private val serverSocketManager: ServerSocketManager by lazy {
        ServerSocketManager(context, channel, bluetoothAdapter, connectionManager)
    }

    private val eventDispatcher: BluetoothEventDispatcher by lazy {
        BluetoothEventDispatcher(context, channel, discoveryManager, connectionManager, serverSocketManager)
    }

    // 블루투스 활성화 콜백
    private var enableBluetoothCallback: ((Boolean) -> Unit)? = null

    init {
        // 이벤트 디스패처 등록
        eventDispatcher.register()
    }

    /**
     * 커스텀 UUID 설정 메서드
     * Flutter에서 지정한 UUID를 설정하여 모든 블루투스 연결에 사용합니다.
     */
    fun setCustomUuid(uuid: UUID) {
        Log.d(Constants.TAG, "🔑 커스텀 UUID 설정: $uuid")
        connectionManager.setCustomUuid(uuid)
    }

    /**
     * 블루투스 가용성 확인
     */
    fun isAvailable(): Boolean {
        return bluetoothAdapter != null
    }

    /**
     * 블루투스 활성화 상태 확인
     */
    fun isEnabled(): Boolean {
        return bluetoothAdapter?.isEnabled == true
    }

    /**
     * 디바이스 연결 상태 확인
     */
    fun isConnected(): Boolean {
        return connectionManager.isConnected()
    }

    /**
     * 블루투스 활성화 요청
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

        enableBluetoothCallback = callback

        try {
            val intent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            activity.startActivityForResult(intent, Constants.REQUEST_ENABLE_BT)
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to request Bluetooth enable", e)
            enableBluetoothCallback?.invoke(false)
            enableBluetoothCallback = null
        }
    }

    /**
     * 디바이스 검색 시작
     */
    fun startScan(activity: Activity, onlyPaired: Boolean, callback: (Boolean) -> Unit) {
        discoveryManager.startScan(activity, onlyPaired, callback)
    }

    /**
     * 디바이스 검색 중지
     */
    fun stopScan() {
        discoveryManager.stopScan()
    }

    /**
     * 페어링된 디바이스 목록 가져오기
     */
    fun getPairedDevices(activity: Activity, callback: (List<Map<String, Any>>) -> Unit) {
        discoveryManager.getPairedDevices(activity, callback)
    }

    /**
     * 페어링된 디바이스 목록 Flutter로 전송
     */
    fun sendPairedDevices() {
        discoveryManager.sendPairedDevices()
    }

    /**
     * 디바이스 주소로 연결
     */
    fun connect(address: String, callback: (Boolean) -> Unit) {
        connectionManager.connect(address, callback)
    }

    /**
     * 디바이스 객체로 연결
     */
    fun connect(device: BluetoothDevice, callback: (Boolean) -> Unit) {
        connectionManager.connect(device, callback)
    }

    /**
     * 현재 연결 해제
     */
    fun disconnect() {
        connectionManager.disconnect()
    }

    /**
     * 데이터 전송
     */
    fun sendData(data: List<Int>, callback: (Boolean) -> Unit) {
        connectionManager.sendData(data, callback)
    }

    /**
     * 서버 소켓 리스닝 시작
     */
    fun listenUsingRfcomm(name: String, uuid: UUID, secured: Boolean = true, callback: (Boolean) -> Unit) {
        serverSocketManager.listenUsingRfcomm(name, uuid, secured, callback)
    }

    /**
     * 서버 소켓 리스닝 중지
     */
    fun stopListening() {
        serverSocketManager.stopListening()
    }

    /**
     * 액티비티 결과 처리 (블루투스 활성화 요청 등)
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == Constants.REQUEST_ENABLE_BT) {
            val enabled = resultCode == Activity.RESULT_OK
            enableBluetoothCallback?.invoke(enabled)
            enableBluetoothCallback = null
            return true
        }
        return false
    }

    /**
     * 리소스 정리
     */
    fun dispose() {
        eventDispatcher.unregister()
        discoveryManager.dispose()
        connectionManager.dispose()
        serverSocketManager.dispose()
        eventDispatcher.dispose()
    }
}