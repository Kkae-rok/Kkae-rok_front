# ⏰ 깨록 (Kkae-rok)

> **비대면 온라인 학습 환경에서 학습자의 졸음과 집중력 저하를 기술적으로 해결하고, 올바른 학습 습관 형성을 돕는 AI 기반 디지털 학습 감독관 플랫폼입니다.**

- **개발 기간**: 2026.03.05 ~ 2026.05.27 (중간 보고 기준: 2026.05.08 Version 1.1)
- **개발 인원**: 팀 프로젝트 (2명 - 연정호, 이혜빈)
- **지도 교수**: 이수정 교수님

---

# 💡 프로젝트 개요 및 필요성

## 1. 개요
비대면 교육 시장의 급격한 성장으로 온라인 강의 및 재택 학습 환경이 보편화되었으나, 강제성이 없는 환경에서 학습자가 스스로 집중력을 유지하고 졸음을 제어하는 데 어려움을 겪고 있습니다. 기존의 졸음 방지 서비스들은 주로 운전자를 대상으로 하거나 단순 타이머 기능에만 치중되어 있어, 혼자 공부하는 학습자를 위한 디지털 학습 감독관 플랫폼인 **깨록**을 기획하게 되었습니다.

## 2. 문제 정의 (필요성)

- **정적 타이머의 한계**  
  기존 학습 타이머 앱들은 공부 중에 발생하는 불필요한 수면이나 집중력 저하를 능동적으로 관리하지 못합니다.

- **운전자 중심의 기존 솔루션**  
  시중의 졸음 방지 서비스는 대부분 운전자 경고에 집중되어 있어 학습 공간(도서관, 카페 등)에 특화된 기능이 부재합니다.

- **소음 및 주변 피해 문제**  
  독서실이나 도서관 등 공공 학습 장소에서는 일반적인 소리 알림을 사용할 수 없어, 주변에 피해를 주지 않는 스마트한 알림 방식이 필요합니다.

- **배터리 소모 한계 극복**  
  카메라 사용으로 인한 배터리 소모 단점을 학습 환경(도서관, 카페 등)이 대부분 충전기 사용이 가능하다는 현실적 조건에 착안하여 수용하고, 대신 **감지 정확도를 극대화**하는 데 집중했습니다.

---

# 🛠 기술 스택 및 아키텍처

## 1. 기술 스택

- **Framework**: Flutter / Dart (iOS 및 Android 크로스 플랫폼 지원 및 하드웨어 호환성 확보)
- **IDE**: VS Code
- **AI / Library**: Google ML Kit (Face Detection, Face Mesh 안면 매핑), OpenCV
- **Backend**: Firebase (Authentication 회원 데이터 관리 및 Firestore NoSQL 기반 데이터 구조 활용)
- **Hardware Connectivity**: Watch Connectivity (iPhone - Apple Watch 간 연동)

## 2. 시스템 아키텍처

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    AI / Core    │    │    Backend      │
│   (Flutter)     │    │ (Google ML Kit) │    │   (Firebase)    │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • UI Components │◄──►│ • Face Mesh     │◄──►│ • Auth (Social) │
│ • State Mgmt    │    │ • Drowsiness    │    │ • Timer DB      │
│ • Watch Conn    │    │ • Head Pitch    │    │ • Record DB     │
│ • Notification  │    │ • OpenCV        │    │ • Statistics    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
     iOS / AOS            Real-time Logic       Firestore / Cloud
```

---

# 🚀 빠른 시작

## 필수 요구사항

- Flutter SDK (최신 안정 버전)
- Dart SDK
- Android Studio / Xcode (에뮬레이터 및 실기기 테스트 환경)
- Firebase 프로젝트 연동용 설정 파일 (`google-services.json` / `GoogleService-Info.plist`)

---

# 환경 변수 및 인프라 설정

## Backend (Firebase Firestore 구조)

별도의 백엔드 서버 호스팅 대신 Firebase 프레임워크를 활용하여 안전한 토큰 관리 및 REST API 기반 통신을 수행합니다.

- 인증 인프라: Firebase Authentication (구글, 카카오, 네이버 소셜 로그인 인동)
- 데이터베이스: 실시간 클라우드 NoSQL (Firestore)

---

# 실행 가이드

## 💻 로컬 개발 및 테스트 환경 실행

```bash
# 1. 저장소 클론
git clone https://github.com/Kkae-rok/Kkae-rok_front.git
cd Kkae-rok_front

# 2. 의존성 패키지 설치 (pubspec.yaml 반영)
flutter pub get

# 3. 연결된 디바이스 또는 에뮬레이터 상태 확인
flutter devices

# 4. 애플리케이션 실행
flutter run
```

---

# ✨ 주요 기능

## 1. AI 기반 실시간 얼굴 모니터링 (상세 졸음 감지 로직)

### 다각도 안면 분석
단순 눈 감김 외에도 하품과 고개 떨굼(Pitch 각도) 분석을 종합하여 오판단을 줄이고 객관적인 판단 기준을 적용합니다.

```typescript
// ML Kit 공식 예제 코드 및 연구 논문 기반 세분화된 감지 임계값(Threshold) 설정
const recommendChart = (
  eyeOpenProbability: number,
  mouthDistance: number,
  headPitch: number
) => {

  // 1. 눈 감김(Drowsiness):
  // 눈을 뜨고 있을 확률이 0.3 미만인 상태가 3초 이상 지속될 때
  if (eyeOpenProbability < 0.3 && isOverThreeSeconds()) {
    return "Drowsiness";
  }

  // 2. 하품(Yawning):
  // 윗입술-아랫입술 y좌표 차이(입 벌어짐 거리)가 임계값을 넘고
  // 1초 이상 지속될 때
  if (mouthDistance > threshold && isOverOneSecond()) {
    return "Yawning";
  }

  // 3. 고개 떨굼(Head Pitch):
  // 얼굴의 Pitch 각도가 -20도 이하로 내려갈 때
  // (졸기 직전 또는 집중력 저하)
  if (headPitch <= -20) {
    return "HeadPitch";
  }

  // 4. 진짜 졸음(Danger):
  // 눈 감김과 고개 숙임(Pitch < -15도)이 동시에 감지되는 위험 상태
  if (eyeOpenProbability < 0.3 && headPitch < -15) {
    return "Danger";
  }
};
```

---

## 2. 다중 알림 시스템 (Hardware Connectivity)

### 선택형 알림 매체
학습 환경(독서실, 집, 카페 등)에 구애받지 않도록 소리, 진동, 무음 알림 수단을 선택할 수 있습니다.

### 주변 소음 방지
애플워치의 진동 알림을 활용하거나 에어팟 모션 센서/오디오 알림을 활용함으로써 공공장소에서도 타인에게 소음 피해를 주지 않고 학습자를 깨웁니다.

---

## 3. 학습 시간 관리 및 통계

### ⏱ 수동 타이머 및 실시간 졸음 감지 피드백
사용자가 직접 타이머를 시작하고 중지하는 직관적인 방식을 통해 학습 시간을 정확하게 기록할 수 있습니다. 이와 동시에 AI 기반 얼굴 인식을 활성화하여 실시간으로 졸음을 감지하고 맞춤형 알림을 제공함으로써 학습의 연속성을 유지하도록 돕습니다.

### 📊 공부 시간 확인 및 월별 비교 통계
단순한 시간 측정을 넘어, 타이머를 통해 축적된 학습 일지와 AI 탐지 데이터를 바탕으로 일별/주별/월별 순수 공부 시간을 한눈에 확인할 수 있습니다. 특히 월별 비교 분석 기능을 직관적인 그래프로 제공하여 학습자가 자신의 학습량 추이와 졸음 패턴을 객관적으로 파악하고 스스로 피드백할 수 있도록 돕습니다.

### 🔑 소셜 로그인 및 환경 설정
구글 등 소셜 연동을 통해 진입 장벽을 낮추고, 사용자 맞춤형 알림 및 개인화된 학습 환경 설정을 안전하게 저장합니다.

---

# 🗄 데이터베이스 설계 (Core Collections)

## 1. 타이머 DB

사용자의 학습 몰입도와 시간 데이터를 관리하는 핵심 컬렉션입니다.

- 사용자 고유 식별자 (`uid`)별 문서 관리
- 당일 학습 시작 시각, 종료 시각 및 총 순수 학습 시간 계산값 저장

---

## 2. 기록 DB

학습 도중 일어나는 AI 탐지 이벤트 로그를 누적하는 통계용 컬렉션입니다.

- 일자별 눈 감김 지속 횟수
- 하품 발생 횟수
- 고개 숙임(Pitch 과임계) 감지 이력 세부 저장

---

## 관계형 설계 특징

### User ↔ Dashboard
1:N 관계를 형성하여 사용자별로 독립적인 타이머 환경과 맞춤 알림 설정을 제공합니다.

### 확장 가능한 구조
NoSQL의 이점을 활용하여 추후 시선 추적(Eye Tracking) 등 새로운 집중도 측정 지표가 추가되더라도 유연하게 대응 가능하도록 스키마를 최적화했습니다.

---

# 🔄 시스템 구성도 및 플로우

## 1. Flutter UI 및 위젯 아키텍처

정교한 디자인 시스템과 로고 에셋을 Flutter 컴포넌트 내에 이식하고 로딩 화면, 메인 타이머, 알림 설정, 통계 화면 간의 유기적인 라우팅 흐름을 처리합니다.

---

## 2. Google ML Kit & OpenCV 실시간 파이프라인

카메라의 실시간 영상 스트림이 Flutter Framework 레이어를 통해 Google ML Kit 인프라로 즉각 전달되며, 안면의 특징점을 분석하여 수초 내에 졸음 로직 결과를 도출하는 고속 데이터 파이프라인입니다.

---

## 3. 하드웨어 동기화 플로우

AI Core 단에서 Danger 또는 Drowsiness 이벤트가 트리거되는 즉시, Watch Connectivity 통신을 통해 실시간 백그라운드로 연동된 애플워치나 에어팟에 진동 및 소리 신호를 송신하는 처리 흐름입니다.
