package com.aclick.bluetooth_classic

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry

private const val REQUEST_BLUETOOTH_PERMISSIONS = 2
private const val TAG = "PermissionManager"

/**
 * Manages Bluetooth-related permissions
 */
class PermissionManager(private val context: Context) : PluginRegistry.RequestPermissionsResultListener {
    
    // Current callback waiting for permission result
    private var permissionCallback: ((Boolean) -> Unit)? = null
    
    /**
     * Get required Bluetooth permissions based on Android version
     */
    private fun getRequiredBluetoothPermissions(): Array<String> {
        val permissions = mutableListOf<String>()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ (API 31+)
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            // Android 11 and below
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        
        return permissions.toTypedArray()
    }
    
    /**
     * Get Android 12+ (API 31+) specific Bluetooth permissions
     */
    private fun getAndroid12BluetoothPermissions(): Array<String> {
        return arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT
        )
    }
    
    /**
     * Get basic Bluetooth permissions for Android 11 and below
     */
    private fun getBasicBluetoothPermissions(): Array<String> {
        return arrayOf(
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
    }
    
    /**
     * Check if all required Bluetooth permissions are granted
     */
    private fun checkBluetoothPermissions(): Boolean {
        val permissions = getRequiredBluetoothPermissions()
        
        return permissions.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
    }
    
    /**
     * Request Bluetooth permissions
     */
    fun requestBluetoothPermissions(activity: Activity, callback: (Boolean) -> Unit) {
        if (checkBluetoothPermissions()) {
            // Permissions already granted
            callback(true)
            return
        }
        
        // Set callback to handle permission result
        permissionCallback = callback
        
        // Request permissions
        val permissions = getRequiredBluetoothPermissions()
        ActivityCompat.requestPermissions(activity, permissions, REQUEST_BLUETOOTH_PERMISSIONS)
    }
    
    /**
     * Request Android 12+ specific Bluetooth permissions (BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
     */
    fun requestAndroid12Permissions(activity: Activity, callback: (Boolean) -> Unit) {
        // Check if permissions are already granted
        val permissions = getAndroid12BluetoothPermissions()
        val allGranted = permissions.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
        
        if (allGranted) {
            // Permissions already granted
            callback(true)
            return
        }
        
        // Set callback to handle permission result
        permissionCallback = callback
        
        // Request permissions
        ActivityCompat.requestPermissions(activity, permissions, REQUEST_BLUETOOTH_PERMISSIONS)
    }
    
    /**
     * Request basic Bluetooth permissions for Android 11 and below
     */
    fun requestBasicPermissions(activity: Activity, callback: (Boolean) -> Unit) {
        // Check if permissions are already granted
        val permissions = getBasicBluetoothPermissions()
        val allGranted = permissions.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
        
        if (allGranted) {
            // Permissions already granted
            callback(true)
            return
        }
        
        // Set callback to handle permission result
        permissionCallback = callback
        
        // Request permissions
        ActivityCompat.requestPermissions(activity, permissions, REQUEST_BLUETOOTH_PERMISSIONS)
    }
    
    /**
     * Check if Bluetooth permission was permanently denied
     */
    fun shouldShowBluetoothPermissionRationale(activity: Activity): Boolean {
        val permissions = getRequiredBluetoothPermissions()
        
        return permissions.any { permission ->
            ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
        }
    }
    
    /**
     * Handle permission request result
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_BLUETOOTH_PERMISSIONS) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            
            Log.d(TAG, "Bluetooth permissions ${if (allGranted) "granted" else "denied"}")
            
            permissionCallback?.invoke(allGranted)
            permissionCallback = null
            
            return true
        }
        return false
    }
}
