package com.aclick.bluetooth_classic

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothServerSocket
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
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.IOException
import java.util.UUID

/**
 * 블루투스 서버 소켓 관련 기능 담당
 * 애플리케이션 수명주기와 연결하여 메모리 누수 방지
 */
class ServerSocketManager(
    private val context: Context,
    private val channel: MethodChannel,
    private val bluetoothAdapter: BluetoothAdapter?,
    private val connectionManager: ConnectionManager
) : LifecycleEventObserver {
    // 서버 소켓
    private var serverSocket: BluetoothServerSocket? = null
    
    // 리스닝 상태
    private var isListening = false
    
    /**
     * 리스닝 상태 확인
     */
    fun isListening(): Boolean {
        return isListening
    }
    
    /**
     * 현재 서버 소켓 가져오기
     */
    fun getServerSocket(): BluetoothServerSocket? {
        return serverSocket
    }
    
    // 서버 소켓 구성 저장
    private var serverSocketName: String? = null
    private var serverSocketUuid: UUID? = null
    private var serverSocketSecured: Boolean = true
    
    // 코루틴 관리를 위한 job 분리
    private val job = SupervisorJob()
    private val coroutineScope = CoroutineScope(Dispatchers.IO + job)
    
    // 현재 리스닝 작업
    private var acceptJob: Job? = null
    
    init {
        // 생명주기 관찰자로 등록
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
    }
    
    /**
     * 생명주기 이벤트 처리
     */
    override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
        when (event) {
            Lifecycle.Event.ON_PAUSE -> {
                // 앱이 배경으로 이동하면 리스닝 상태만 저장하고 소켓 작업 중지
                if (isListening) {
                    Log.d(Constants.TAG, "앱 배경으로 이동 - 서버소켓 임시 중단")
                }
            }
            Lifecycle.Event.ON_STOP -> {
                // 앱이 완전히 가려져도 상태는 유지
            }
            Lifecycle.Event.ON_DESTROY -> dispose()
            else -> {}
        }
    }
    
    /**
     * 서버 소켓 리스닝 시작
     */
    fun listenUsingRfcomm(name: String, uuid: UUID, secured: Boolean = true, callback: (Boolean) -> Unit) {
        // 사용할 UUID 결정 (커스텀 UUID 또는 입력 UUID)
        val actualUuid = connectionManager.getConnectionUuid()
        Log.d(Constants.TAG, "🔑 리스닝용 사용할 UUID: $actualUuid${if (connectionManager.getConnectionUuid() != Constants.SPP_UUID) " (커스텀)" else " (기본)"}")
        
        // 블루투스 가용성 확인
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
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
        
        // 현재 설정 저장 (연결 끊김 시 재시작을 위해)
        serverSocketName = name
        serverSocketUuid = uuid
        serverSocketSecured = secured
        
        // 기존 리스닝 중지
        stopListening()
        
        try {
            // 새 서버 소켓 생성
            val btAdapter = bluetoothAdapter ?: throw IOException("Bluetooth adapter not available")
            
            // 서버 소켓 생성 (actualUuid 사용)
            val socket = if (secured) {
                btAdapter.listenUsingRfcommWithServiceRecord(name, actualUuid)
            } else {
                btAdapter.listenUsingInsecureRfcommWithServiceRecord(name, actualUuid)
            }
            
            // 서버 소켓 저장
            serverSocket = socket
            isListening = true
            
            // 연결 수락 쓰레드 시작
            startAcceptThread(socket)
            
            // 성공 알림
            callback(true)
            
            // Flutter에 리스닝 상태 알림
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onListening", mapOf(
                    "uuid" to uuid.toString(),
                    "name" to name,
                    "secured" to secured
                ))
            }
            
        } catch (e: IOException) {
            Log.e(Constants.TAG, "Failed to create server socket", e)
            stopListening()
            callback(false)
        }
    }
    
    /**
     * 리스닝 중지
     */
    fun stopListening() {
        try {
            if (serverSocket != null) {
                Log.d(Constants.TAG, "Closing server socket")
                serverSocket?.close()
            }
        } catch (e: IOException) {
            Log.e(Constants.TAG, "Failed to close server socket", e)
        }
        
        serverSocket = null
        isListening = false
    }
    
    /**
     * 연결 수락 쓰레드 시작
     */
    private fun startAcceptThread(serverSocket: BluetoothServerSocket) {
        // 기존 작업 취소
        acceptJob?.cancel()
        acceptJob = coroutineScope.launch {
            try {
                while (isListening) {
                    try {
                        Log.d(Constants.TAG, "Waiting for incoming connections...")
                        val socket = serverSocket.accept() // 연결 수락될 때까지 차단
                        
                        // 연결 수락됨
                        Log.d(Constants.TAG, "Connection accepted from: ${socket.remoteDevice.address}")
                        
                        // 서버 소켓을 닫고 상태 업데이트
                        serverSocket.close()
                        isListening = false
                        this@ServerSocketManager.serverSocket = null
                        
                        // 연결 처리
                        handleIncomingConnection(socket)
                        
                        // 잠시 후 리스닝 재시작
                        delay(Constants.SERVER_RESTART_DELAY)
                        restartListening()
                        
                        break // 루프 종료
                    } catch (e: IOException) {
                        if (!isListening) {
                            // 의도적으로 중지된 경우
                            Log.d(Constants.TAG, "Accept thread stopped normally")
                            break
                        } else {
                            // 예상치 못한 오류
                            Log.e(Constants.TAG, "Error accepting connection", e)
                            delay(Constants.SERVER_RESTART_DELAY * 2) // 더 긴 지연 후 재시도
                            restartListening()
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(Constants.TAG, "Error in accept thread", e)
            }
        }
    }
    
    /**
     * 서버소켓 연결 처리 - 이 함수가 startAcceptThread에서만 호출되도록 수정
     */
    private fun handleIncomingConnection(socket: BluetoothSocket) {
        val device = socket.remoteDevice
        Log.d(Constants.TAG, "📞 서버소켓에서 연결 받음: ${device.address}")
        
        try {
            // 연결 객체 설정을 ConnectionManager에 위임
            val uuid = connectionManager.getConnectionUuid()
            
            // 기존 연결 종료
            connectionManager.disconnect()
            
            // 연결 객체 생성 및 설정을 connectionManager에 위임
            val connection = BluetoothConnection(device, context, channel, uuid, socket)
            connectionManager.setCurrentConnection(connection)
            
            // 이벤트 발행
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onDeviceConnected", mapOf(
                    "address" to device.address,
                    "name" to (device.name ?: "Unknown Device"),
                    "type" to "classic"
                ))
            }
            
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Error handling incoming connection", e)
            try {
                socket.close()
            } catch (e2: IOException) {
                Log.e(Constants.TAG, "Error closing socket", e2)
            }
        }
    }
    
    /**
     * ACL_CONNECTED 이벤트에서 호출되는 함수 - 혈속을 향상시켜 startAcceptThread에서 소켓을 받도록 유도
     */
    fun handleIncomingConnection(device: BluetoothDevice, connectionManager: ConnectionManager) {
        Log.d(Constants.TAG, "📟 ACL_CONNECTED 이벤트 받음: ${device.address}")
        
        // 어떤 경우든 소켓 처리는 startAcceptThread에서 처리되바라
        // 여기서는 로그만 출력하고 현재 리스닝 상태만 확인
        if (isListening && serverSocket != null) {
            Log.d(Constants.TAG, "현재 리스닝 중: 서버소켓에서 연결 처리 예정")
        } else {
            Log.e(Constants.TAG, "서버 소켓이 리스닝 상태아님. ConnectionManager에서 처리 필요")
        }
    }
    
    /**
     * 서버 소켓 리스닝 재시작
     */
    fun restartListening() {
        // 저장된 설정이 있는 경우에만 재시작
        val name = serverSocketName
        val uuid = serverSocketUuid
        val secured = serverSocketSecured
        
        if (name != null && uuid != null && !isListening) {
            Log.d(Constants.TAG, "Restarting server socket: name=$name, uuid=$uuid, secured=$secured")
            
            listenUsingRfcomm(name, uuid, secured) { success ->
                if (success) {
                    Log.d(Constants.TAG, "Server socket restarted successfully")
                } else {
                    Log.e(Constants.TAG, "Failed to restart server socket")
                }
            }
        }
    }
    
    /**
     * 리소스 정리
     */
    fun dispose() {
        stopListening()
        serverSocketName = null
        serverSocketUuid = null
        // 생명주기 관찰자 제거
        ProcessLifecycleOwner.get().lifecycle.removeObserver(this)
        
        // 코루틴 작업 취소
        acceptJob?.cancel()
        job.cancelChildren()
        job.cancel()
    }
}
