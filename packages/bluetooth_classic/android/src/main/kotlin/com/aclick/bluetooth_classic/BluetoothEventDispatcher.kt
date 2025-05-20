package com.aclick.bluetooth_classic

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import kotlinx.coroutines.launch
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren

/**
 * 블루투스 관련 이벤트 수신 및 처리 담당
 * 생명주기 관련 메모리 누수를 방지하기 위해 LifecycleEventObserver 구현
 */
class BluetoothEventDispatcher(
    private val context: Context,
    private val channel: MethodChannel,
    private val discoveryManager: DiscoveryManager,
    private val connectionManager: ConnectionManager,
    private val serverSocketManager: ServerSocketManager
) : LifecycleEventObserver {
    // 이벤트 리시버
    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    
                    device?.let { discoveryManager.handleDeviceFound(it) }
                }
                
                BluetoothAdapter.ACTION_DISCOVERY_STARTED -> {
                    Log.d(Constants.TAG, "Discovery started")
                }
                
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    Log.d(Constants.TAG, "Discovery finished")
                }
                
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    handleBluetoothStateChange(state)
                }
                
                BluetoothDevice.ACTION_ACL_CONNECTED -> {
                    Log.d(Constants.TAG, "🔵 ACTION_ACL_CONNECTED 이벤트 수신")
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    
                    // 장치가 유효하면 ConnectionManager에 처리 위임
                    device?.let {
                        connectionManager.handleAclConnected(it, serverSocketManager)
                    }
                }
                
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    
                    device?.let {
                        Log.d(Constants.TAG, "Device disconnected: ${it.address}")
                        connectionManager.handleDisconnection(it)
                        
                        // 서버 소켓 재시작
                        serverSocketManager.restartListening()
                    }
                }
                
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    
                    val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                    
                    device?.let {
                        when (bondState) {
                            BluetoothDevice.BOND_BONDED -> {
                                Log.d(Constants.TAG, "Device bonded: ${it.address}")
                            }
                            BluetoothDevice.BOND_BONDING -> {
                                Log.d(Constants.TAG, "Device bonding: ${it.address}")
                            }
                            BluetoothDevice.BOND_NONE -> {
                                Log.d(Constants.TAG, "Device not bonded: ${it.address}")
                            }
                            else -> {
                                Log.d(Constants.TAG, "Unknown bond state: $bondState for device: ${it.address}")
                            }
                        }
                    }
                }
                
                else -> {
                    Log.d(Constants.TAG, "Unhandled action: ${intent.action}")
                }
            }
        }
    }
    
    // 코루틴 관리를 위한 job 분리
    private val job = SupervisorJob()
    private val coroutineScope = CoroutineScope(Dispatchers.IO + job)
    
    // 등록 여부
    private var isRegistered = false
    
    init {
        // 생성 시 생명주기 관찰자로 등록
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
    }
    
    /**
     * 생명주기 이벤트 처리
     */
    override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
        when (event) {
//            Lifecycle.Event.ON_START -> register()
//            Lifecycle.Event.ON_STOP -> unregister()
            Lifecycle.Event.ON_CREATE -> register()
            Lifecycle.Event.ON_DESTROY -> dispose()
            else -> {}
        }
    }
    
    /**
     * 이벤트 리시버 등록 - 앱이 시작될 때 자동으로 호출됨
     */
    fun register() {
        if (isRegistered) {
            return
        }
        
        try {
            val filter = IntentFilter().apply {
                addAction(BluetoothDevice.ACTION_FOUND)
                addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
                addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
                addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
                addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
                addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            }
            
            context.registerReceiver(bluetoothReceiver, filter)
            isRegistered = true
            Log.d(Constants.TAG, "Bluetooth event receiver registered")
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to register bluetooth receiver", e)
        }
    }
    
    /**
     * 이벤트 리시버 해제
     */
    fun unregister() {
        if (!isRegistered) {
            return
        }
        
        try {
            context.unregisterReceiver(bluetoothReceiver)
            isRegistered = false
            Log.d(Constants.TAG, "Bluetooth event receiver unregistered")
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to unregister bluetooth receiver", e)
        }
    }
    
    /**
     * 블루투스 상태 변경 처리
     */
    private fun handleBluetoothStateChange(state: Int) {
        val stateMap = mapOf(
            "state" to when (state) {
                BluetoothAdapter.STATE_OFF -> "STATE_OFF"
                BluetoothAdapter.STATE_TURNING_ON -> "STATE_TURNING_ON"
                BluetoothAdapter.STATE_ON -> "STATE_ON"
                BluetoothAdapter.STATE_TURNING_OFF -> "STATE_TURNING_OFF"
                else -> "STATE_UNKNOWN"
            }
        )
        
        coroutineScope.launch(Dispatchers.Main) {
            channel.invokeMethod("onStateChanged", stateMap)
        }
        
        // 블루투스가 꺼졌을 때 모든 리소스 정리
        if (state == BluetoothAdapter.STATE_OFF || state == BluetoothAdapter.STATE_TURNING_OFF) {
            discoveryManager.stopScan()
            connectionManager.disconnect()
            serverSocketManager.stopListening()
        }
    }
    
    /**
     * 리소스 정리
     */
    fun dispose() {
        unregister()
        // 생명주기 관찰자에서 제거
        ProcessLifecycleOwner.get().lifecycle.removeObserver(this)
        
        // 코루틴 작업 취소
        job.cancelChildren()
        job.cancel()
    }
}
