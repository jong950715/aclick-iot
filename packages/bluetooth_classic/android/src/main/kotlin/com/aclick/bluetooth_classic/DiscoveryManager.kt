package com.aclick.bluetooth_classic

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.HashMap

/**
 * 블루투스 기기 검색 관련 기능 담당
 */
class DiscoveryManager(
    private val context: Context,
    private val channel: MethodChannel,
    private val permissionManager: PermissionManager,
    private val bluetoothAdapter: BluetoothAdapter?
) {
    // 검색된 기기 목록
    private val discoveredDevices = HashMap<String, BluetoothDevice>()
    
    // 검색 상태 추적
    private var isDiscovering = false
    
    // 콜백 저장
    private var discoveryCallback: ((Boolean) -> Unit)? = null
    
    // 코루틴 관리를 위한 job 분리
    private val job = SupervisorJob()
    private val coroutineScope = CoroutineScope(Dispatchers.IO + job)
    
    /**
     * 블루투스 기기 검색 시작
     */
    fun startScan(activity: Activity, onlyPaired: Boolean, callback: (Boolean) -> Unit) {
        // 콜백 저장
        discoveryCallback = callback
        
        // 다른 검색이 진행 중인 경우 중지
        if (isDiscovering) {
            stopScan()
        }
        
        // 블루투스 사용 가능 여부 확인
        if (bluetoothAdapter == null) {
            callback(false)
            return
        }
        
        // 블루투스 활성화 여부 확인
        if (!bluetoothAdapter.isEnabled) {
            callback(false)
            return
        }
        
        // 권한 확인
        val permissionsNeeded = mutableListOf<String>()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.BLUETOOTH_SCAN)
            }
        } else {
            if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        }
        
        if (permissionsNeeded.isNotEmpty()) {
            permissionManager.requestSpecificPermissions(
                activity,
                permissionsNeeded.toTypedArray()
            ) { granted ->
                if (granted) {
                    startDiscoveryProcess(onlyPaired)
                } else {
                    callback(false)
                }
            }
        } else {
            startDiscoveryProcess(onlyPaired)
        }
    }
    
    /**
     * 기기 검색 프로세스 시작
     */
    private fun startDiscoveryProcess(onlyPaired: Boolean) {
        // 페어링된 기기만 요청된 경우
        if (onlyPaired) {
            sendPairedDevices()
            discoveryCallback?.invoke(true)
            discoveryCallback = null
            return
        }
        
        discoveredDevices.clear()
        
        try {
            // 검색 시작
            val success = bluetoothAdapter?.startDiscovery() ?: false
            
            if (success) {
                isDiscovering = true
                
                // 타임아웃 처리
                coroutineScope.launch {
                    delay(Constants.DISCOVERY_TIMEOUT)
                    if (isDiscovering) {
                        stopScan()
                        discoveryCallback?.invoke(true)
                        discoveryCallback = null
                    }
                }
            } else {
                discoveryCallback?.invoke(false)
                discoveryCallback = null
            }
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to start discovery", e)
            discoveryCallback?.invoke(false)
            discoveryCallback = null
        }
    }
    
    /**
     * 블루투스 기기 검색 중지
     */
    fun stopScan() {
        if (isDiscovering && bluetoothAdapter?.isDiscovering == true) {
            try {
                bluetoothAdapter.cancelDiscovery()
            } catch (e: Exception) {
                Log.e(Constants.TAG, "Failed to stop discovery", e)
            }
        }
        isDiscovering = false
    }
    
    /**
     * 페어링된 기기 목록 가져오기
     */
    fun getPairedDevices(activity: Activity, callback: (List<Map<String, Any>>) -> Unit) {
        if (bluetoothAdapter == null) {
            callback(emptyList())
            return
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasPermission = context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            if (!hasPermission) {
                permissionManager.requestSpecificPermissions(
                    activity,
                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT)
                ) { granted ->
                    if (granted) {
                        sendPairedDeviceList(callback)
                    } else {
                        callback(emptyList())
                    }
                }
                return
            }
        }
        
        sendPairedDeviceList(callback)
    }
    
    /**
     * 페어링된 기기 목록을 콜백으로 전송
     */
    private fun sendPairedDeviceList(callback: (List<Map<String, Any>>) -> Unit) {
        try {
            val pairedDevices = bluetoothAdapter?.bondedDevices ?: setOf()
            val deviceList = pairedDevices.map { device ->
                mapOf(
                    "name" to (device.name ?: "Unknown Device"),
                    "address" to device.address,
                    "type" to device.type,
                    "bondState" to device.bondState
                )
            }
            callback(deviceList)
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to get paired devices", e)
            callback(emptyList())
        }
    }
    
    /**
     * 페어링된 기기 목록을 Flutter로 전송
     */
    fun sendPairedDevices() {
        try {
            val pairedDevices = bluetoothAdapter?.bondedDevices ?: setOf()
            val devices = pairedDevices.map { device -> 
                mapOf(
                    "name" to (device.name ?: "Unknown Device"),
                    "address" to device.address,
                    "type" to device.type,
                    "bondState" to device.bondState
                )
            }
            
            coroutineScope.launch(Dispatchers.Main) {
                channel.invokeMethod("onPairedDevices", mapOf("devices" to devices))
            }
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Failed to send paired devices", e)
        }
    }
    
    /**
     * 발견된 기기 처리
     */
    fun handleDeviceFound(device: BluetoothDevice) {
        try {
            if (!discoveredDevices.containsKey(device.address)) {
                discoveredDevices[device.address] = device
                
                val deviceMap = mapOf(
                    "name" to (device.name ?: "Unknown Device"),
                    "address" to device.address,
                    "type" to device.type,
                    "bondState" to device.bondState
                )
                
                // Flutter에 기기 정보 전송
                coroutineScope.launch(Dispatchers.Main) {
                    channel.invokeMethod("onDeviceFound", deviceMap)
                }
            }
        } catch (e: Exception) {
            Log.e(Constants.TAG, "Error handling found device", e)
        }
    }
    
    /**
     * 리소스 정리
     */
    fun dispose() {
        stopScan()
        discoveredDevices.clear()
        discoveryCallback = null
        
        // 코루틴 작업 취소
        job.cancelChildren() // 현재 실행 중인 모든 자식 코루틴 취소
        job.cancel() // 메인 job 취소
    }
}
