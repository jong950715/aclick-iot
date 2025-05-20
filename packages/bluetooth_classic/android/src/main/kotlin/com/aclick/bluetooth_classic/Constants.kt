package com.aclick.bluetooth_classic

import java.util.UUID

/**
 * Bluetooth Classic 구현에 사용되는 공통 상수
 */
object Constants {
    // Request codes
    const val REQUEST_ENABLE_BT = 1
    const val REQUEST_DISCOVERABLE = 2
    
    // Log tag
    const val TAG = "BluetoothClassic"
    
    // Standard UUIDs
    val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // Serial Port Profile UUID
    
    // Timeouts (in milliseconds)
    const val CONNECTION_TIMEOUT = 10000L // 10 seconds
    const val DISCOVERY_TIMEOUT = 30000L // 30 seconds
    const val SERVER_RESTART_DELAY = 1000L // 1 second
    
    // Buffer sizes
    const val READ_BUFFER_SIZE = 4096
    const val WRITE_BUFFER_SIZE = 4096
}
