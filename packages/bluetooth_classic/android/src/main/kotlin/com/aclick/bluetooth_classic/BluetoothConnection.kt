package com.aclick.bluetooth_classic

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.IOException
import java.io.OutputStream
import java.util.*
import kotlinx.coroutines.*

private const val TAG = "BluetoothConnection"

/**
 * 블루투스 연결 관리 클래스
 * 
 * @param device 연결할 블루투스 장치
 * @param context 앱 컨텍스트
 * @param channel Flutter가 이벤트를 받을 수 있는 메서드 채널
 * @param uuid 연결에 사용할 UUID (기본값은 SPP UUID)
 * @param existingSocket 그룹 소유자로부터 이미 받은 소켓이 있는 경우 지정 (기본값은 null)
 */
class BluetoothConnection @JvmOverloads constructor(
    private val device: BluetoothDevice, 
    private val context: Context, 
    private val channel: MethodChannel, 
    private val uuid: UUID = SPP_UUID,
    existingSocket: BluetoothSocket? = null
) {
    companion object {
        // Serial Port Profile UUID - 기본값으로 사용됨
        val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
    
    private var socket: BluetoothSocket? = null
    
    init {
        // 생성자에서 전달받은 소켓이 있으면 사용
        if (existingSocket != null) {
            socket = existingSocket
            Log.d(TAG, "📱 전달받은 소켓으로 초기화: ${device.address}")
        }
    }
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null
    private var isConnecting = false
    private var isConnected = false
    
    /**
     * 서버 소켓의 accept()로 얻은 클라이언트 소켓을 사용하여 스트림 설정
     * 이미 소켓이 초기화되어 있다고 가정하고 스트림만 설정함
     * 
     * @return 스트림 설정 성공 여부
     */
    fun setupStreamsFromSocket(): Boolean {
        if (socket == null) {
            Log.e(TAG, "❌ 소켓이 null임: ${device.address}")
            return false
        }
        
        Log.d(TAG, "📢 서버 소켓에서 스트림 설정: ${device.address}")
        
        try {
            // 입출력 스트림 초기화
            inputStream = socket?.inputStream
            outputStream = socket?.outputStream
            
            if (inputStream == null || outputStream == null) {
                Log.e(TAG, "❌ 스트림 가져오기 실패: ${device.address}")
                return false
            }
            
            // 연결 상태 업데이트
            isConnected = true
            isConnecting = false
            
            // 데이터 수신 리스너 시작
            startListening()
            
            // Flutter에 연결 성공 알림
            notifyConnectionEstablished()
            
            Log.d(TAG, "💡 스트림 설정 완료: ${device.address}")
            return true
            
        } catch (e: IOException) {
            Log.e(TAG, "❌ 스트림 설정 오류: ${e.message}")
            closeSocket()
            return false
        }
    }
    private var isListening = false
    private var readJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // 통계 변수
    private var packetsReceived = 0
    private var packetsSent = 0
    private var errorCount = 0
    
    init {
        // 객체 생성 시 자동으로 연결하지 않음
        Log.d(TAG, "⚙️ BluetoothConnection 객체 생성됨: ${device.address}")
    }
    
    /**
     * 블루투스 장치에 연결
     * 일반적인 연결 시나리오에서 사용 (디바이스를 선택해서 연결하는 경우)
     */
    fun connect(): Boolean {
        if (isConnected) {
            Log.d(TAG, "이미 연결됨: ${device.address}")
            return true
        }
        
        if (isConnecting) {
            Log.d(TAG, "연결 중: ${device.address}")
            return false
        }
        
        isConnecting = true
        
        try {
            Log.d(TAG, "🔌 소켓 연결 시도: ${device.address}")
            
            // 지정된 커스텀 UUID 사용
            Log.d(TAG, "🔑 사용할 UUID: $uuid")
            socket = device.createRfcommSocketToServiceRecord(uuid)
            
            // 연결 시도
            socket?.connect()
            
            // 스트림 열기 및 리스닝 시작
            return setupStreamsAndListen()
            
        } catch (e: IOException) {
            Log.e(TAG, "❌ 연결 실패: ${e.message}")
            errorCount++
            closeSocket()
            isConnecting = false
            isConnected = false
            return false
        }
    }
    
    /**
     * 이미 연결된 장치를 위한 설정 (ACL_CONNECTED 이벤트에서 호출됨)
     * 이미 소켓이 연결된 경우, 스트림 관련 처리만 수행
     */
    /**
     * 이미 연결된 장치를 위한 설정 (ACL_CONNECTED 이벤트에서 호출됨)
     * 이미 소켓이 연결된 경우, 스트림 관련 처리만 수행
     * 
     * @param externalUuid 외부에서 전달한 UUID가 있으면 사용함 (기본값은 null)
     * @return 연결 성공 여부
     */
    fun setupAlreadyConnected(externalUuid: UUID? = null): Boolean {
        if (isConnected) {
            Log.d(TAG, "이미 연결됨: ${device.address}")
            return true
        }
        
        Log.d(TAG, "🔌 이미 연결된 장치 설정: ${device.address}")
        isConnecting = true
        
        // 사용할 UUID 결정 (외부에서 전달된 UUID를 우선시하고, 없는 경우 생성자에서 전달받은 UUID 사용)
        val uuidToUse = externalUuid ?: uuid
        
        try {
            // 지정된 커스텀 UUID 사용
            Log.d(TAG, "🔑 이미 연결된 장치에 사용할 UUID: $uuidToUse")
            socket = device.createRfcommSocketToServiceRecord(uuidToUse)
            
            socket?.connect()
            return setupStreamsAndListen()
            
        } catch (e: IOException) {
            Log.e(TAG, "❌ 이미 연결된 장치 설정 실패: ${e.message}")
            errorCount++
            closeSocket()
            isConnecting = false
            isConnected = false
            return false
        }
    }
    
    /**
     * 스트림 열고 리스닝 시작 (내부 메서드)
     */
    private fun setupStreamsAndListen(): Boolean {
        try {
            // 스트림 열기
            inputStream = socket?.inputStream
            outputStream = socket?.outputStream
            
            // 상태 업데이트
            isConnected = true
            isConnecting = false
            
            // 데이터 수신 리스너 시작
            startListening()
            
            // Flutter에 연결 성공 알림
            notifyConnectionEstablished()
            
            Log.d(TAG, "✅ 연결 성공: ${device.address}")
            return true
        } catch (e: IOException) {
            Log.e(TAG, "❌ 스트림 열기 실패: ${e.message}")
            closeSocket()
            isConnected = false
            isConnecting = false
            return false
        }
    }
    
    /**
     * Flutter에 연결 성공 이벤트 알림
     */
    private fun notifyConnectionEstablished() {
        scope.launch(Dispatchers.Main) {
            val deviceInfo = mapOf(
                "address" to device.address,
                "name" to (device.name ?: "Unknown Device"),
                "type" to "classic"
            )
            
            channel.invokeMethod("onDeviceConnected", deviceInfo)
        }
    }
    
    /**
     * 데이터 리스닝 시작
     */
    private fun startListening() {
        val localInputStream = inputStream // 지역 변수로 보호
        
        if (isListening || localInputStream == null) {
            Log.w(TAG, "🛡️ 리스닝 시작 실패: isListening=$isListening, inputStream=${localInputStream != null}")
            return
        }
        
        Log.d(TAG, "📻 데이터 리스닝 시작")
        isListening = true
        readJob = scope.launch(Dispatchers.IO) {
            Log.d(TAG, "🔗 리스닝 코루틴 시작")
            val buffer = ByteArray(1024)
            var bytes: Int
            
            try {
                var counter = 0
                while (isActive && isConnected) {
                    if (counter % 30 == 0) { // 30번마다 로그 출력(과도한 로깅 방지)
                        Log.d(TAG, "📯 리스닝 원활: 수신=$packetsReceived, 전송=$packetsSent")
                    }
                    counter++
                    
                    // 현재 스트림 상태 체크 및 데이터 읽기
                    val localBuffer = buffer  // 로컬 참조로 복사
                    val streamReadResult = readFromStreamSafely(localBuffer)
                    
                    when {
                        streamReadResult.error != null -> {
                            Log.e(TAG, "⚠️ 스트림 읽기 오류: ${streamReadResult.error}")
                            errorCount++
                            break
                        }
                        streamReadResult.bytesRead < 0 -> {
                            Log.w(TAG, "❌ 소켓 연결 종료: bytesRead=${streamReadResult.bytesRead}")
                            break
                        }
                        streamReadResult.bytesRead > 0 -> {
                            val bytesRead = streamReadResult.bytesRead
                            packetsReceived++
                            val data = localBuffer.copyOfRange(0, bytesRead) 
                            val dataString = String(data)
                            
                            Log.d(TAG, "📥 데이터 수신: $bytesRead 바이트 - '$dataString'")
                            
                            // Flutter에 데이터 전달
                            withContext(Dispatchers.Main) {
                                channel.invokeMethod("onDataReceived", mapOf(
                                    "address" to device.address,
                                    "data" to data.map { it.toInt() and 0xFF }
                                ))
                                Log.d(TAG, "✅ Flutter에 데이터 전달 완료")
                            }
                        }
                        else -> {
                            Log.d(TAG, "📋 읽은 바이트 없음 (bytesRead=0)")
                        }
                    }
                }
                Log.d(TAG, "📚 리스닝 루프 종료: isActive=$isActive, isConnected=$isConnected")
            } catch (e: Exception) {
                Log.e(TAG, "⛔ 리스닝 스레드 오류: ${e.message}")
            } finally {
                // 루프 종료 시 연결도 종료
                Log.d(TAG, "🔴 리스닝 코루틴 종료")
                if (isConnected) {
                    disconnect()
                }
                isListening = false
            }
        }
    }
    
    /**
     * 데이터 전송
     */
    fun sendData(data: ByteArray): Boolean {
        if (!isConnected || outputStream == null) {
            Log.e(TAG, "📤 전송 실패: 연결되지 않음")
            return false
        }
        
        return try {
            outputStream?.write(data)
            outputStream?.flush()
            packetsSent++
            Log.d(TAG, "📤 데이터 전송: ${data.size} 바이트")
            true
        } catch (e: IOException) {
            Log.e(TAG, "📤 데이터 전송 오류: ${e.message}")
            errorCount++
            disconnect()
            false
        }
    }
    
    /**
     * 소켓과 스트림 닫기
     */
    private fun closeSocket() {
        try {
            inputStream?.close()
            outputStream?.close()
            socket?.close()
        } catch (e: IOException) {
            Log.e(TAG, "소켓 닫기 오류: ${e.message}")
        } finally {
            socket = null
            inputStream = null
            outputStream = null
        }
    }
    
    /**
     * 스트림에서 안전하게 데이터 읽기
     * null 참조 문제를 방지하기 위한 보호 메서드
     */
    private data class StreamReadResult(val bytesRead: Int, val error: String?)
    
    /**
     * 스트림에서 안전하게 데이터 읽기
     */
    private fun readFromStreamSafely(buffer: ByteArray): StreamReadResult {
        // 이 전체 메서드를 동기화
        // 실행 중에 다른 스레드가 inputStream을 변경하지 못하게 함
        return synchronized(this) {
            try {
                // 로컬 변수로 복사
                val localInputStream = inputStream
                
                if (localInputStream == null) {
                    Log.e(TAG, "🛑 읽기 시도 중 inputStream이 null입니다")
                    return@synchronized StreamReadResult(-1, "InputStream is null")
                }
                
                if (!isConnected) {
                    Log.e(TAG, "🛑 읽기 시도 중 isConnected=false")
                    return@synchronized StreamReadResult(-1, "Not connected")
                }
                
                Log.d(TAG, "📝 데이터 읽기 시도 중...")
                try {
                    val bytesRead = try {
                        // 안전하게 읽기 시도
                        localInputStream.read(buffer)
                    } catch (npe: NullPointerException) {
                        // 매우 드물게 발생하는 NPE를 잡아서 로그
                        Log.e(TAG, "🛑 실제 read() 호출 시 NPE 발생!")
                        -1
                    }
                    
                    if (bytesRead > 0) {
                        Log.d(TAG, "📝 데이터 읽기 성공: $bytesRead 바이트")
                        StreamReadResult(bytesRead, null)
                    } else if (bytesRead == 0) {
                        Log.d(TAG, "📋 읽은 바이트 없음")
                        StreamReadResult(0, null)
                    } else {
                        Log.w(TAG, "❌ 연결 종료 감지: read() 반환값=$bytesRead")
                        // 연결이 종료된 경우, 연결 상태 업데이트
                        isConnected = false
                        StreamReadResult(bytesRead, "Connection closed")
                    }
                } catch (e: IOException) {
                    Log.e(TAG, "⚠️ 데이터 읽기 IOException: ${e.message}")
                    StreamReadResult(-1, "IOException: ${e.message}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "⛔ 데이터 읽기 오류: ${e.javaClass.simpleName}: ${e.message}")
                StreamReadResult(-1, "${e.javaClass.simpleName}: ${e.message}")
            }
        }
    }
    
    /**
     * 연결 종료 및 자원 해제
     */
    fun disconnect() {
        if (!isConnected && !isConnecting) return
        
        // 읽기 작업 취소
        readJob?.cancel()
        isListening = false
        
        // 소켓 닫기
        closeSocket()
        
        // 상태 업데이트
        isConnected = false
        isConnecting = false
        
        // Flutter에 연결 종료 알림
        scope.launch(Dispatchers.Main) {
            channel.invokeMethod("onDeviceDisconnected", mapOf(
                "address" to device.address,
                "name" to (device.name ?: "Unknown Device")
            ))
        }
        
        Log.d(TAG, "🔌 연결 종료: ${device.address}")
    }
    
    /**
     * 연결된 BluetoothDevice 객체 반환
     */
    fun getDevice(): BluetoothDevice {
        return device
    }
    
    /**
     * 연결 상태 반환
     */
    fun isConnected(): Boolean {
        return isConnected && socket?.isConnected == true
    }
    
    /**
     * 연결 통계 반환
     */
    fun getConnectionStats(): Map<String, Any> {
        return mapOf(
            "packetsReceived" to packetsReceived,
            "packetsSent" to packetsSent,
            "errorCount" to errorCount,
            "isConnected" to isConnected(),
            "deviceAddress" to device.address
        )
    }
}
