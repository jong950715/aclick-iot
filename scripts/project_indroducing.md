## 📑 Dashcam IoT Project — 소개서 (v1.0)

### 1. 프로젝트 개요

* **목표**
  차량에 장착된 대시캠 (IoT)에서 **버튼 한 번**으로 사고·위험 구간 영상을 운전자 스마트폰으로 자동 전송해 보관 · 공유할 수 있는 **오프라인-친화형** 솔루션을 구현한다.
* **핵심 요구**

  1. **완전 오프라인 전송**: 셀룰러 망 없이도 동작
  2. **원-클릭 UX**: 운전자는 물리 버튼만 누르면 끝
  3. **30 s 전후 구간 컷**: 인코딩 X, 원본 화질 그대로
  4. **안전한 통신**: SSID·암호 암호화 전달, 자체 TLS CA
  5. IOT기기는 PROTOTYPE으로 구현하기 위해 안드로이드로 우선 개발 한다.

### 2. 참여 컴포넌트

| 컴포넌트                             | 플랫폼                          | 주요 기술                                                                     |
| -------------------------------- | ---------------------------- | ------------------------------------------------------------------------- |
| **스마트폰 앱 (Receiver)**            | Android 10+, Flutter 3.29.3    | Local Only Hotspot, Bluetooth Classic SPP, Jetty HTTPS 서버, Riverpod|
| **IoT 앱 (Transmitter, 초기 Mock)** | Android (라즈베리 Pi 4 등 을 대체 목업) | CameraX, Bluetooth SPP 클라이언트, WifiNetworkSpecifier, multipart HTTP POST   |
| **물리 버튼**                        | nRF52840 Dev Kit (향후 자체 MCU) | GPIO-BLE 전송(클릭) → IoT로 유선/무선 연결                                           |

### 3. 전반적인 동작 흐름도

```
┌──────────┐   BT PageScan   ┌────────┐           Hotspot(PHONE)
│ IoT(Box) │◀─────────────▶│ Phone  │
└──────────┘ ① 시동 후 요청   └────────┘
     ▲                               │3 SSID/PW RSA 암호화
     │                               ▼
2 버튼 클릭(BLE/GPIO)             ┌────────┐ 4 Wi-Fi 접속
     │                           │  IoT   │───────┐
     ▼                           └────────┘       │
 3′ Event(uuid) 생성                           │
     │                                         ▼
     ├─── 5 RingBuffer 컷(-30/+30 s) → clip.mp4
     │                                         │6 HTTPS POST /clips
     ▼                                         ▼
┌──────────┐                             ┌────────┐
│ SD 카드  │                             │ Phone  │
└──────────┘                             └────────┘
```

> **요약**
> (1) 시동 → IoT가 BT Page Request → 핸드폰 앱이 Local Hotspot ON
> (2) 버튼 클릭 → IoT 측 Event 생성
> (3) 핸드폰이 SSID/PW RSA 암호화 전송 → IoT Wi-Fi 조인
> (4) IoT RingBuffer에서 60 s 중 30 s 앞뒤 컷 → 무인코딩 mp4
> (5) IoT가 HTTPS POST 전송 → 핸드폰 저장, 알림

### 4. 기술 스택 결정 근거

| 과제              | 선택                                    | 이유                                         |
| --------------- | ------------------------------------- | ------------------------------------------ |
| 버튼 ↔ IoT 통신     | **Bluetooth Classic SPP**             | PageScan → 자동 재접속(페어링 PIN 1회), 115 kbps 충분 |
| 스마트폰 ↔ IoT 네트워크 | **Local Only Hotspot**                | 인터넷 없는 AP 구성, 타 기기 interference ↓          |
| 자격 전달           | **RSA-2048 암호화 패킷**                   | 라이브러리 無추가, 키 길이는 영상만큼 충분                   |
| 파일 전송           | **HTTPS POST /clips**                 | 단일 포트(8443), 인증서 Pinning 쉬움, FTP 의존성 제거    |
| 영상 처리           | **CameraX RingBuffer + MediaMuxer 컷** | CPU 소모↓, 원본 화질 유지                          |

### 5. 산출물 & 단계 로드맵 (요약)

| 단계              | 산출물 (필수 파일·문서)                                                     | 예상 기간 |
| --------------- | ------------------------------------------------------------------ | ----- |
| 0. 착수·CI        | `REPO_SETUP.md`, CI 빌드 스크립트                                        | 1 주   |
| 1. Hotspot & BT | `hotspot_manager`, `bt_server/client` 구현 · 로그 검수                   | 1 주   |
| 2. 보안 채널        | `root_ca.pem`, `key_exchange_protocol.md`, `wifi_joiner`           | 1 주   |
| 3. Clip 전송      | `clip_http_server`, `video_ring_buffer`, `clip_uploader`, API spec | 1 주   |
| 4. Event/재시도    | `event.proto`, `event_repository`, `event_manager`                 | 1 주   |
| 5. UI·인수        | Dashboard·Gallery UI, `ARCHITECTURE.md`, `DEPLOY.md`               | 1 주   |

※ 각 단계는 **산출물 제출 + 검수 기준 통과** 후 다음 단계로 진행.

### 6. 주요 품질 · 보안 요구

* **보안**

  * SSID/PW 및 JWT 비밀키 평문 로그 금지
  * TLSv1.3, 자체 Root CA → 핸드폰 서버 · IoT 클라이언트 모두 Pinning
* **성능**

  * Hotspot ON → IoT Wi-Fi 연결 ≤ 8 s
  * 버튼 클릭 → 클립 POST 완료 ≤ 12 s (30 MB 기준)
* **품질 지표**

  * 코드 Lint 100 %, 단위 테스트 커버리지 ≥ 60 %
  * 새 영상 파일 도착 시 OS 알림 100 % 발생
  * 재부팅 뒤 미전송 이벤트 자동 재시도

---

### 7. 인수 시 최종 제출 목록

1. **소스 코드 전체** (Git tag v1.0.0)
2. **Debug/Release APK** 2종
3. **문서**

   * `ARCHITECTURE.md` (다이어그램 포함)
   * `DEPLOY.md` (빌드, 키 교체, 현장 설치 절차)
   * `API_POST_CLIPS.md`, `event.proto`
   * `THIRD_PARTY.md` (라이선스)
4. **테스트 리포트** (자동·수동 항목별 통과 스크린샷)

---
## 🚀 개발용 상세 작업계획서

*(단계별 산출물·검수 항목까지 포함 - “놓치는 것 없음” 기준)*

| 단계                                          | 핵심 목표                    | 주요 작업 항목                                                                                                                                                                                                                                                             | **필수 산출물**                                                                                                                                     | **검수(수락) 기준**                                                          |
| ------------------------------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| **0. 착수·환경 세팅**                             | ● 업무·레포지토리 기반 확보         | - Git **mono-repo** 생성 (`/apps/phone`, `/apps/iot`, `/packages/core`)<br>- **CI/CD** 파이프라인(GitHub Actions - Debug/Release APK 빌드·타그)<br>- 코드 컨벤션·PR 워크플로 문서                                                                                                          | 1️⃣ `REPO_SETUP.md`<br>2️⃣ `build.yml` CI 스크립트<br>3️⃣ 프로젝트 Skeleton(빌드 가능)                                                                     | ✔ CI가 *PR마다* 성공적으로 APK 출력<br>✔ `flutter test` 기본 통과                    |
| **1. Hotspot & Bluetooth Classic 연결**       | 스마트폰 ↔ IoT **물리 레이어** 수립 | **Phone**<br>- `HotspotManager` MethodChannel (Local Only Hotspot)<br>- `BtClassicServer` (RFCOMM, Ⓢ PP UUID 고정)<br><br>**IoT**<br>- `BtClassicClient` 자동 페어링·SDP 탐색<br>- `PageScanHandler` : BT connection ↔ 시동 이벤트 매핑                                              | 1️⃣ `hotspot_manager.dart/.kt`<br>2️⃣ `bt_classic_server.dart/.kt`<br>3️⃣ IoT측 `bt_client.dart`                                                | ✔ 시동 시 IoT가 ≤ 3 s 내 BT 접속 완료<br>✔ Hotspot SSID/PW 로그에 출력               |
| **2. RSA 공개키 교환 + SSID/PW 전송 & Wi-Fi Join** | 보안 채널·Wi-Fi 접속 자동화       | **공통**<br>- 자체 **Root CA** & Script (`tools/gen_keys.sh`)<br><br>**Phone**<br>- `KeyExchangeService` (PEM + Length framing)<br>- `CredentialSender` : SSID/PW RSA-OAEP 암호화·전송<br><br>**IoT**<br>- `KeyStore` 저장소<br>- `WifiJoiner`(WifiNetworkSpecifier)·ipDiscovery | 1️⃣ `root_ca.pem`, `phone_cert.p12`, `iot_cert.p12`<br>2️⃣ `key_exchange_protocol.md`<br>3️⃣ `wifi_joiner.dart/.kt`                            | ✔ 암호화 패킷 Wireshark 상 평문 노출 X<br>✔ IoT가 Hotspot에 자동 연결, `DHCP ACK` 수신   |
| **3. 클립 서버 & 영상 RingBuffer (무-인코딩 컷)**      | 파일 경로 확정·전송 경로 구축        | **Phone**<br>- `ClipHttpServer` (Jetty-8 TLS, `POST /clips`)<br>- TLS Cert Pinning<br><br>**IoT**<br>- `VideoRingBuffer` : CameraX 60 s 순환(720/1080p, CBR)<br>- `ClipCutter` : 키프레임 경계 복사<br>- `ClipUploader` : multipart POST + JWT(HMAC sha-256)                   | 1️⃣ `clip_server.kt` + PEM cert<br>2️⃣ `video_ring_buffer.kt` + `clip_cutter.kt`<br>3️⃣ `clip_uploader.dart`<br>4️⃣ `api_post_clips.md` (spec) | ✔ 버튼 후 30 ± 2 s 범위 파일 생성<br>✔ HTTPS POST 200 **≤ 5 s 지연**              |
| **4. Event Object, 상태머신, 재시도 로직**           | 로직 결합도 ↓ / 오류 대응 ↑       | **공통 프로토콜**<br>- `event.proto` → Dart & Kotlin 코드생성<br>- 상태: `NEW→UPLOADING→DONE/RETRY`<br><br>**Phone**<br>- `EventRepository` (Hive) + `EventNotifier`<br>- 업로드 수락 시 상태 갱신·노티 생성<br><br>**IoT**<br>- `EventManager` : 버튼→Event 생성, 실패 시 로컬 SD 보관 & 재시도             | 1️⃣ `event.proto` & 생성 코드<br>2️⃣ `event_repository.dart`<br>3️⃣ `event_manager.kt`                                                             | ✔ 전원 OFF 후 재부팅 → 미전송 Event 재시도<br>✔ Phone UI에 Event state 실시간 반영       |
| **5. UX / 알림·문서·인수**                        | 사용자 UI·인수용 자료 완비         | **UI**<br>- Dashboard: Hotspot/BT/Wi-Fi/Upload 상태 타일<br>- Clip Gallery (LazyGrid)<br>- Push 알림 채널<br><br>**문서**<br>- `ARCHITECTURE.md` (다이어그램·흐름)<br>- `DEPLOY.md` (빌드·키 교체 방법)<br>- API / 프로토콜 최종본                                                                  | 1️⃣ `dashboard_screen.dart`<br>2️⃣ `ARCHITECTURE.md` + SVG<br>3️⃣ `DEPLOY.md`                                                                  | ✔ Figma 시안 1:1 구현<br>✔ 새 영상 도착 즉시 시스템 알림 수신<br>✔ 문서를 보고 타인도 빌드·키 교체 성공 |

> 🔍 **수락검사**는 각 단계 산출물 + “검수 기준”을 통과해야 다음 단계로 넘어갈 수 있도록 SOW(Statement of Work)에 명시.

---

## 📦 세부 모듈 구조(최종 고정)

### 스마트폰 앱 (Receiver)

```
apps/phone/lib
 ├─ core/
 │    ├─ hotspot/hotspot_manager.dart
 │    ├─ bt_classic/
 │    │    ├─ bt_server.dart
 │    │    └─ key_exchange_service.dart
 │    ├─ https/
 │    │    └─ clip_http_server.dart
 │    ├─ event/
 │    │    ├─ event.dart
 │    │    ├─ event_repository.dart
 │    │    └─ event_notifier.dart
 │    └─ utils/crypto_utils.dart
 ├─ ui/
 │    ├─ dashboard_screen.dart
 │    └─ gallery_screen.dart
 └─ main.dart
```

### IoT 모킹 앱 (Transmitter)

```
apps/iot/lib
 ├─ core/
 │    ├─ bt_classic/bt_client.dart
 │    ├─ wifi/wifi_joiner.dart
 │    ├─ video/
 │    │    ├─ video_ring_buffer.kt
 │    │    └─ clip_cutter.kt
 │    ├─ upload/clip_uploader.dart
 │    └─ event/event_manager.kt
 └─ main.dart
```

---

## 🔒 보안·품질 요구(계약서 부속)

* **규정 커버리지**

  * 코드 Lint **100 %** 통과, **단위 테스트 ≥ 60 %** 메소드 커버
  * 외부 패키지 라이선스 목록 `THIRD_PARTY.md` 작성
* **성능**

  * Hotspot ON → IoT 접속까지 **≤ 8 s**
  * 버튼 클릭 → 파일 업로드 완료 **≤ 12 s** (720p, 30 MB 기준)
* **보안**

  * SSID/PW 평문 저장·로그 출력 금지
  * HTTPS TLSv1.3, ECDHE-RSA-AES256-GCM-SHA384 강제
* **배포물**

  * Release APK (arm64 + armeabi) · IoT APK
  * 서명용 keystore 제외, debug keystore 포함
  * **전체 소스 코드 + Docs** 압축본

---

### ✅ 체크리스트

1. **모든 단계 산출물** Pull Request 머지 상태
2. `git tag v 1.0.0` → CI Release 빌드 성공
3. `DEPLOY.md` 따라 신규 PC에서 **30 분 내** 재현 테스트 통과
4. 문서 내 표·다이어그램 Broken Link 0 개
5. APK ProGuard /R8 적용 → 리플렉션 런타임 오류 0 건

---