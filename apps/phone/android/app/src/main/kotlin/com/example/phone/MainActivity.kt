package com.example.phone

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler {
    private val CHANNEL = "com.aclick.iot/bluetooth"
    private val REQUEST_ENABLE_BT = 1
    private val REQUEST_FINE_LOCATION = 2
    private val REQUEST_BLUETOOTH_PERMISSIONS = 3

    private lateinit var methodChannel: MethodChannel
    private var bluetoothAdapter: BluetoothAdapter? = null
    
    // Holds pending method calls waiting for permission results
    private var pendingMethodCall: MethodCall? = null
    private var pendingResult: MethodChannel.Result? = null
    
    // Broadcast receiver for discovery
    private var discoveryReceiver: BroadcastReceiver? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Initialize method channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler(this)
        
        // Initialize Bluetooth adapter
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeAdapter" -> initializeAdapter(result)
            "requestEnable" -> requestEnable(result)
            "startScan" -> startScan(call, result)
            "stopScan" -> stopScan(result)
            "getPairedDevices" -> getPairedDevices(result)
            else -> result.notImplemented()
        }
    }
    
    private fun initializeAdapter(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.success(mapOf("isAvailable" to false, "isEnabled" to false))
            return
        }
        
        result.success(mapOf(
            "isAvailable" to true,
            "isEnabled" to (bluetoothAdapter?.isEnabled == true)
        ))
    }
    
    private fun requestEnable(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not available on this device", null)
            return
        }
        
        if (bluetoothAdapter?.isEnabled == true) {
            result.success(true)
            return
        }
        
        pendingResult = result
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                    REQUEST_BLUETOOTH_PERMISSIONS
                )
                return
            }
        }
        
        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
        startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
    }
    
    private fun checkBluetoothPermissions(result: MethodChannel.Result): Boolean {
        // For Android 12+ (API 31+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val bluetoothScanPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN)
            val bluetoothConnectPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
            
            if (bluetoothScanPermission != PackageManager.PERMISSION_GRANTED ||
                bluetoothConnectPermission != PackageManager.PERMISSION_GRANTED) {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.BLUETOOTH_SCAN,
                        Manifest.permission.BLUETOOTH_CONNECT
                    ),
                    REQUEST_BLUETOOTH_PERMISSIONS
                )
                return false
            }
        } 
        // For Android 6.0+ (API 23+), we need location permission for scanning to work
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val locationPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            
            if (locationPermission != PackageManager.PERMISSION_GRANTED) {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                    REQUEST_FINE_LOCATION
                )
                return false
            }
        }
        
        return true
    }
    
    private fun startScan(call: MethodCall, result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not available on this device", null)
            return
        }
        
        if (bluetoothAdapter?.isEnabled != true) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null)
            return
        }
        
        // Check for necessary permissions
        if (!checkBluetoothPermissions(result)) {
            pendingMethodCall = call
            return
        }
        
        // Stop any ongoing discovery
        bluetoothAdapter?.cancelDiscovery()
        
        // Set up the broadcast receiver for discovery
        if (discoveryReceiver == null) {
            discoveryReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    when(intent.action) {
                        BluetoothDevice.ACTION_FOUND -> {
                            val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                            }
                            
                            device?.let {
                                val deviceName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                                        device.name
                                    } else {
                                        "Unknown"
                                    }
                                } else {
                                    @Suppress("DEPRECATION")
                                    device.name
                                }
                                
                                val deviceMap = mapOf(
                                    "address" to device.address,
                                    "name" to deviceName,
                                    "rssi" to intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt(),
                                    "isPaired" to false,
                                    "deviceClass" to (device.bluetoothClass?.deviceClass ?: 0)
                                )
                                
                                methodChannel.invokeMethod("deviceFound", deviceMap)
                            }
                        }
                        BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                            methodChannel.invokeMethod("scanFinished", null)
                        }
                    }
                }
            }
            
            // Register for broadcasts
            val filter = IntentFilter().apply {
                addAction(BluetoothDevice.ACTION_FOUND)
                addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            }
            
            registerReceiver(discoveryReceiver, filter)
        }
        
        // Start discovery
        val success = bluetoothAdapter?.startDiscovery() ?: false
        result.success(success)
    }
    
    private fun stopScan(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not available on this device", null)
            return
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "Bluetooth SCAN permission denied", null)
                return
            }
        }
        
        val success = bluetoothAdapter?.cancelDiscovery() ?: false
        result.success(success)
    }
    
    private fun getPairedDevices(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not available on this device", null)
            return
        }
        
        if (bluetoothAdapter?.isEnabled != true) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null)
            return
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                    REQUEST_BLUETOOTH_PERMISSIONS
                )
                return
            }
        }
        
        val pairedDevices = bluetoothAdapter?.bondedDevices ?: setOf()
        val devicesList = pairedDevices.map { device ->
            val deviceName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                    device.name
                } else {
                    "Unknown"
                }
            } else {
                @Suppress("DEPRECATION")
                device.name
            }
            
            mapOf(
                "address" to device.address,
                "name" to deviceName,
                "isPaired" to true,
                "deviceClass" to (device.bluetoothClass?.deviceClass ?: 0)
            )
        }
        
        result.success(devicesList)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_ENABLE_BT) {
            pendingResult?.let { result ->
                result.success(resultCode == RESULT_OK)
                pendingResult = null
            }
        }
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        
        when (requestCode) {
            REQUEST_BLUETOOTH_PERMISSIONS -> {
                if (allGranted) {
                    pendingMethodCall?.let { call ->
                        pendingResult?.let { result ->
                            when (call.method) {
                                "startScan" -> startScan(call, result)
                                "requestEnable" -> requestEnable(result)
                                "getPairedDevices" -> getPairedDevices(result)
                                else -> { /* Do nothing */ }
                            }
                        }
                    } ?: pendingResult?.let { result ->
                        result.success(true)
                    }
                } else {
                    pendingResult?.error("PERMISSION_DENIED", "Bluetooth permissions denied", null)
                }
                
                pendingMethodCall = null
                pendingResult = null
            }
            REQUEST_FINE_LOCATION -> {
                if (allGranted) {
                    pendingMethodCall?.let { call ->
                        pendingResult?.let { result ->
                            when (call.method) {
                                "startScan" -> startScan(call, result)
                                else -> { /* Do nothing */ }
                            }
                        }
                    }
                } else {
                    pendingResult?.error("PERMISSION_DENIED", "Location permission denied", null)
                }
                
                pendingMethodCall = null
                pendingResult = null
            }
        }
    }
    
    override fun onDestroy() {
        discoveryReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (e: IllegalArgumentException) {
                // Receiver not registered, do nothing
            }
            discoveryReceiver = null
        }
        
        super.onDestroy()
    }
}
