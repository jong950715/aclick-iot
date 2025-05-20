package com.aclick.bluetooth_classic

import android.app.Activity
import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID

/** BluetoothClassicPlugin */
class BluetoothClassicPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    
    // Managers
    private lateinit var bluetoothManager: BluetoothManager
    private lateinit var permissionManager: PermissionManager
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.aclick.bluetooth_classic/android")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        // Initialize permission manager
        permissionManager = PermissionManager(context)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initializeAdapter" -> {
                handleInitializeAdapter(result)
            }
            "requestEnable" -> {
                handleRequestEnable(result)
            }
            "startScan" -> {
                handleStartScan(call, result)
            }
            "stopScan" -> {
                handleStopScan(result)
            }
            "getPairedDevices" -> {
                handleGetPairedDevices(result)
            }
            "connect" -> {
                handleConnect(call, result)
            }
            "disconnect" -> {
                handleDisconnect(result)
            }
            "sendData" -> {
                handleSendData(call, result)
            }
            "isEnabled" -> {
                handleIsEnabled(result)
            }
            "isConnected" -> {
                handleIsConnected(result)
            }
            "getAndroidInfo" -> {
                handleGetAndroidInfo(result)
            }
            "requestPermissions" -> {
                handleRequestPermissions(call, result)
            }
            "listenUsingRfcomm" -> {
                handleListenUsingRfcomm(call, result)
            }
            "setCustomUuid" -> {
                handleSetCustomUuid(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun handleInitializeAdapter(result: Result) {
        try {
            // Lazy initialize bluetooth manager if needed
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            val isEnabled = bluetoothManager.isEnabled()
            result.success(mapOf(
                "isAvailable" to bluetoothManager.isAvailable(),
                "isEnabled" to isEnabled
            ))
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }
    
    private fun handleRequestEnable(result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            if (activity == null) {
                result.error("ACTIVITY_UNAVAILABLE", "Activity is not available", null)
                return
            }
            
            bluetoothManager.requestEnable(activity!!) { success ->
                result.success(success)
            }
        } catch (e: Exception) {
            result.error("REQUEST_ENABLE_ERROR", e.message, null)
        }
    }
    
    private fun handleStartScan(call: MethodCall, result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            val onlyPaired = call.argument<Boolean>("onlyPaired") ?: false
            
            if (activity == null) {
                result.error("ACTIVITY_UNAVAILABLE", "Activity is not available", null)
                return
            }
            
            bluetoothManager.startScan(activity!!, onlyPaired) { success ->
                result.success(success)
            }
        } catch (e: Exception) {
            result.error("START_SCAN_ERROR", e.message, null)
        }
    }
    
    private fun handleStopScan(result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            bluetoothManager.stopScan()
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_SCAN_ERROR", e.message, null)
        }
    }
    
    private fun handleGetPairedDevices(result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            if (activity == null) {
                result.error("ACTIVITY_UNAVAILABLE", "Activity is not available", null)
                return
            }
            
            bluetoothManager.getPairedDevices(activity!!) { devices ->
                result.success(devices)
            }
        } catch (e: Exception) {
            result.error("GET_PAIRED_DEVICES_ERROR", e.message, null)
        }
    }
    
    private fun handleConnect(call: MethodCall, result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            val address = call.argument<String>("address")
            if (address == null) {
                result.error("INVALID_ARGUMENT", "Device address is required", null)
                return
            }
            
            bluetoothManager.connect(address) { success ->
                result.success(success)
            }
        } catch (e: Exception) {
            result.error("CONNECT_ERROR", e.message, null)
        }
    }
    
    private fun handleDisconnect(result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            bluetoothManager.disconnect()
            result.success(true)
        } catch (e: Exception) {
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }
    
    private fun handleSendData(call: MethodCall, result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            // Flutter에서 오는 바이트 데이터는 List<Byte>나 ByteArray로 받아야 함
            // call.argument<ByteArray> 방식은 작동하지 않을 수 있으므로 다음과 같이 처리
            val dataObj = call.argument<Any>("data")
            if (dataObj == null) {
                result.error("INVALID_ARGUMENT", "Data is required", null)
                return
            }
            
            // 두 가지 가능한 데이터 형식 처리
            val byteData = when (dataObj) {
                is ByteArray -> dataObj
                is List<*> -> {
                    // List<*>를 ByteArray로 변환
                    val byteArray = ByteArray(dataObj.size)
                    for (i in dataObj.indices) {
                        val elem = dataObj[i]
                        byteArray[i] = when (elem) {
                            is Byte -> elem
                            is Int -> elem.toByte() 
                            else -> {
                                result.error("INVALID_DATA_TYPE", "Expected list of bytes", null)
                                return
                            }
                        }
                    }
                    byteArray
                }
                else -> {
                    result.error("INVALID_DATA_TYPE", "Expected byte array or list", null)
                    return
                }
            }
            
            // 변환된 바이트 데이터를 Int 리스트로 변환하여 전송
            // Byte를 Int로 변환할 때 and 0xFF를 해주면 음수 바이트가 올바르게 처리됨
            bluetoothManager.sendData(byteData.map { it.toInt() and 0xFF }.toList()) { success ->
                result.success(success)
            }
        } catch (e: Exception) {
            result.error("SEND_DATA_ERROR", e.message, null)
        }
    }
    
    private fun handleIsEnabled(result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            result.success(bluetoothManager.isEnabled())
        } catch (e: Exception) {
            result.error("IS_ENABLED_ERROR", e.message, null)
        }
    }
    
    private fun handleIsConnected(result: Result) {
        try {
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            result.success(bluetoothManager.isConnected())
        } catch (e: Exception) {
            result.error("IS_CONNECTED_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        
        // Clean up resources
        if (::bluetoothManager.isInitialized) {
            bluetoothManager.dispose()
        }
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        
        // Register activity result listener for enable bluetooth request
        if (::bluetoothManager.isInitialized) {
            binding.addActivityResultListener(bluetoothManager)
        }
        
        // Register request permission handler
        if (::permissionManager.isInitialized) {
            binding.addRequestPermissionsResultListener(permissionManager)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        
        // Re-register activity result listener
        if (::bluetoothManager.isInitialized) {
            binding.addActivityResultListener(bluetoothManager)
        }
        
        // Re-register request permission handler
        if (::permissionManager.isInitialized) {
            binding.addRequestPermissionsResultListener(permissionManager)
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
    
    private fun handleGetAndroidInfo(result: Result) {
        try {
            // Get and return Android SDK version information
            val sdkInt = android.os.Build.VERSION.SDK_INT
            val release = android.os.Build.VERSION.RELEASE
            
            result.success(mapOf(
                "sdkInt" to sdkInt,
                "release" to release
            ))
        } catch (e: Exception) {
            result.error("ANDROID_INFO_ERROR", "Failed to get Android info: ${e.message}", null)
        }
    }
    
    private fun handleRequestPermissions(call: MethodCall, result: Result) {
        try {
            if (activity == null) {
                result.error("ACTIVITY_UNAVAILABLE", "Activity is not available for permissions", null)
                return
            }
            
            // Get permission type from arguments (if not specified, use automatic permission detection)
            val permissionType = call.argument<String>("permissionType")
            
            if (permissionType == null || permissionType == "auto") {
                // 기기 Android 버전에 맞는 적절한 권한 자동 요청
                permissionManager.requestAppropriatePermissions(activity!!) { granted ->
                    result.success(granted)
                }
            } else {
                // 특정 권한 타입 요청(오래된 코드와의 호환성 유지)
                permissionManager.requestPermissionsByType(activity!!, permissionType) { granted ->
                    result.success(granted)
                }
            }
        } catch (e: Exception) {
            result.error("PERMISSION_REQUEST_ERROR", "Failed to request permissions: ${e.message}", null)
        }
    }
    
    private fun handleListenUsingRfcomm(call: MethodCall, result: Result) {
        try {
            // Lazy initialize bluetooth manager if needed
            if (!::bluetoothManager.isInitialized) {
                bluetoothManager = BluetoothManager(context, channel, permissionManager)
            }
            
            // Get arguments from the call
            val name = call.argument<String>("name") ?: "BluetoothServer"
            val uuid = call.argument<String>("uuid") ?: "00001101-0000-1000-8000-00805F9B34FB" // Default SPP UUID
            val secured = call.argument<Boolean>("secured") ?: true

            // Set UUID
            bluetoothManager.setCustomUuid(UUID.fromString(uuid))
            
            // Start listening for connections
            bluetoothManager.listenUsingRfcomm(name, UUID.fromString(uuid), secured) { success ->
                result.success(success)
            }
        } catch (e: Exception) {
            result.error("LISTEN_ERROR", "Failed to start listening: ${e.message}", null)
        }
    }
    
    // 2025-05-17: handleAcceptConnection 메서드 삭제됨
    // 연결은 이제 네이티브 이벤트(ACTION_ACL_CONNECTED, ACTION_ACL_DISCONNECTED)를 통해 처리됩니다.
    
    /**
     * 커스텀 UUID 설정 처리
     * Flutter 측에서 지정한 커스텀 UUID를 사용하여 블루투스 통신을 설정합니다.
     */
    private fun handleSetCustomUuid(call: MethodCall, result: Result) {
        try {
            // 지정된 UUID 중 속성이 없을 경우를 대비해 기본값 설정
            val uuidString = call.argument<String>("uuid") ?: "00001101-0000-1000-8000-00805F9B34FB" // 기본 SPP UUID
            
            // UUID 형식 검증
            try {
                val uuid = UUID.fromString(uuidString)
                
                // Lazy initialize bluetooth manager if needed
                if (!::bluetoothManager.isInitialized) {
                    bluetoothManager = BluetoothManager(context, channel, permissionManager)
                }
                
                // 블루투스 매니저에 UUID 전달
                bluetoothManager.setCustomUuid(uuid)
                
                result.success(true)
            } catch (e: IllegalArgumentException) {
                result.error("INVALID_UUID", "잘못된 UUID 형식: $uuidString", null)
            }
        } catch (e: Exception) {
            result.error("UUID_SETTING_ERROR", "UUID 설정 오류: ${e.message}", null)
        }
    }
}
