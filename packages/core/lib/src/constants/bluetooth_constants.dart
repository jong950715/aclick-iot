/// 블루투스 관련 상수 정의
/// 
/// IoT 프로젝트에서 사용되는 블루투스 통신 관련 상수들입니다.

/// Phone 앱과 IoT 기기 간의 통신에 사용되는 고유 UUID
/// 
/// SPP (Serial Port Profile)와 유사한 형식을 가지지만, 
/// 프로젝트 고유의 UUID를 사용하여 통신 채널을 구분합니다.
const String BLUETOOTH_IOT_UUID = "3435cb4a-f69e-4329-a9be-f2d72be9fbf3";
const String BLE_SERVICE_UUID = "e892a4d8-0565-46a3-93ba-57f44e9f873b";
const String BLE_GATT_WIFI_UUID = "e892b4d8-0566-46a3-93ba-57f44e9f873b";
const String BLE_GATT_PING_UUID = "e892c4d8-0566-46a3-93ba-57f44e9f873b";
const String BLE_GATT_NEW_EVENT_CLIP_UUID = "e893c4d8-0566-46af-91ba-57f44e9f873b";