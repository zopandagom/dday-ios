# 제품 결정

이 앱이 정한 것이다. 프로젝트 소유 문서라 이 프로젝트에서 고친다. 하네스 문서(`docs/harness/`)는 고치지 않고, 이 앱에 더하는 규칙은 §3 에 쓴다. 하네스 규칙과 부딪히는 규칙은 쓰지 않는다. 하네스 규칙을 바꿔야 하면 ios-harness 에 반영하고 `/ios-harness:update-harness` 로 받는다.

## 1. 제품 약속
앱이 사용자에게 지키기로 한 약속(데이터가 어디로 가는지, 무엇을 기록하지 않는지)과 그 강제 수단이다. `/arch-review` 와 CI 리뷰가 이 절을 기준으로 본다.

| ✅ | ❌ | 강제 |
|---|---|---|
| 모든 처리는 기기 안에서 | `URLSession` 등 네트워크 코드 추가 (필요하면 사전 합의 후 별도 Client) | `no_network` |
| 로그에는 개수·소요 시간 같은 메타데이터만. `Logger` 는 `privacy: .private` 기본 | 사용자 데이터·식별자를 `print`/`Logger` 로 출력 | |
| 서드파티 SDK 는 합의 후에만 | 분석·크래시 SDK 를 합의 없이 추가 | |
| 권한은 필요한 시점에 요청하고 거부·제한도 정상 흐름으로 처리 | 앱 시작 즉시 권한 팝업 | |
| 완전 무료. 광고·인앱 결제 없음 | 광고 SDK·StoreKit 결제 추가 | |
| 디데이·사진은 기기 안(SwiftData)에만 저장. 서버·로그인 없음 | 사진이나 디데이 내용을 기기 밖으로 전송 | `no_network` |
| 사진은 사용자가 고른 것만 받는다 (PhotosPicker, 사진 라이브러리 권한 요청 없음) | 사진 라이브러리 전체 접근 권한 요청 | |
| 알림 권한은 첫 실행 안내의 마지막 장이나 알림을 켤 때 요청 | 앱 시작 즉시 알림 권한 팝업 | |

## 2. 확정된 기술 결정
| 결정 | 이유 |
|---|---|
| 서버 없음 | 앱이 네트워크를 쓰지 않는다. 필요해지면 사전 합의 후 별도 Client 로 추가하고 lint `no_network` 를 조정한다 |
| TCA 등 외부 아키텍처 라이브러리 | 사용하지 않음. 외부 의존성 0 을 유지하고, 추가하려면 사전 합의 |
| 저장소: SwiftData (이미지는 압축본 1600px + 썸네일 400px, `.externalStorage`). Client `DDayStore` 가 감싼다. 스키마는 `VersionedSchema`(V1 부터) + `SchemaMigrationPlan` 으로 버전 관리. 저장소는 처음 쓰는 호출에서 연다. 열지 못하면 그 호출이 `.loadFailed` 를 던지고 실패를 기억하지 않아 다음 호출이 다시 연다 (앱에 열기 실패 화면은 없고 목록의 불러오기 오류·다시 시도로 보인다) | 기기 안 저장만 필요하고 외부 의존성 없이 쓸 수 있다. 출시 뒤 저장 형식을 바꿔도 기존 데이터를 옮길 수 있다. 첫 잠금 해제 전 실행처럼 일시적인 열기 실패에서 앱을 다시 켜지 않고 회복한다 |
| 알림: UserNotifications 로컬 알림. 가까운 순 최대 60개 예약 후 다시 계산. 무엇을 예약할지는 Core `NotificationPlanner`(순수 로직)가 정한다: 지난 알림 제외. D-day 방식은 목표일(매년 반복은 다음 날짜 2번까지), D+·1일째 방식은 시작일(오늘 이후면)과 기념일(100일 단위: 화면 숫자 기준 — D+ 는 시작일+100k일, 1일째는 +100k−1일 / N주년: 시작일과 같은 날짜, 2/29·음력은 매년 반복 규칙)에 같은 N일 전·시간으로 알린다. 기념일은 N일 전마다 알림 날짜가 오늘 이후인 다음 2번까지, 100일과 주년이 같은 날이면 주년 하나. 반복 규칙은 D-day 방식에서만 쓴다. 알림 날짜는 고정 4개(30일 전·7일 전·2일 전·당일, `ReminderSettings.daysBeforeChoices`)를 디데이마다 켜고 끈다 (새 디데이는 7일 전·2일 전·당일 켜짐, 30일 전 꺼짐). 선택지 밖 값은 `ReminderSettings` 가 버리고, 계획기에는 켜진 날짜(`scheduledDaysBefore`)만 넘긴다. 디데이마다 '100일마다'·'매년(N주년)'을 켜고 끈다(기본 켜짐, D+·1일째일 때만 편집 화면에 보이고 값은 늘 저장. 알림 전체를 끄면 기념일 알림도 없다) | iOS 예약 한도 64개. 고정 토글이라 입력 검증이 없고 끈 날짜도 늘 화면에 보인다. 30일 전은 달마다 간격이 달라지지 않게 날짜 수로 정하고, 화면에도 "30일 전"으로 보여 헷갈리지 않게 한다. 기념일 표시(화면)는 2차, 알림만 MVP |
| 음력: 한국천문연구원 기준 표(음력 1900~2050년, korean-lunar-calendar 0.3.1 의 MIT 데이터에서 추출, 라이선스 고지 포함: `Projects/Shared/Core/Sources/Calendar/KoreanLunarTable.swift`). 변환 범위는 원본이 검증한 양력 1900-01-31 ~ 2050-12-31(음력 2050-11-18까지)이고 밖이면 `nil`. 날짜 차이는 Core `CalendarDay` 의 율리우스 일(JDN)로 계산 | Foundation `.chinese` 달력은 중국 기준이라 한국 날짜와 다른 해가 있다 (예: 2027 설날 한국 2/7, 중국 2/6) |
| 사진 선택: PhotosUI `PhotosPicker` | 사진 권한 없이 사용자가 고른 사진만 받는다 |
| 다국어: String Catalog, 한국어·영어. Feature 문구는 자기 `Sources/Localizable.xcstrings`(Tuist 가 `<Feature>_<Feature>.bundle` 과 `Bundle.module` 생성, 코드는 `.atURL(Bundle.module.bundleURL)`). 앱 Info.plist `CFBundleLocalizations` = ko·en (`Env.appInfoPlist`) | 없으면 하위 번들 언어가 메인 앱 developmentRegion 하나로 고정된다 (App 은 항상 한국어, Example 은 항상 영어) |
| 최소 지원: iOS 18.0, iPhone 만 | 더 많은 기기 지원 |
| 디자인 팔레트(라이트/다크): Blush Pink #FF8FB1(강조색·연인), Lavender #C9B6FF/#A996F0(기타), Peach #FFC6A8/#F0A989(생일), Mint #A8E6CF/#7FCFB2(가족), Butter #FFE8A3/#E8CF7E(당일 배지), 배경 #FFF8F6/#1E1A22, 카드 #FFFFFF/#2A2430, 글자 #4A3F4B/#F3ECF5 | 10~20대 여성 타깃의 파스텔·다꾸 감성 |
| 폰트: 한글 Pretendard(OFL), D-day 숫자 SF Pro Rounded | |
| 디자인 에셋(앱 아이콘·폴더 아이콘·일러스트·기본 배경)은 사용자가 ChatGPT 로 만든다 | |
| "오늘" 기준: `CalendarDay(Date(), in: .autoupdatingCurrent)`(기기 현재 시간대의 날짜)를 App 이 클로저로 `HomeModel` 에 주입. 앱 복귀(scenePhase active)·자정(`.NSCalendarDayChanged`)·시간대 변경(`.NSSystemTimeZoneDidChange`) 때 다시 구해 바뀌었을 때만 다시 정렬한다 (저장소는 다시 읽지 않음) | 테스트에서 날짜를 고정하고, 자정·여행 중에도 카운트가 맞게 |

## 3. 프로젝트 규칙
하네스 규칙(`docs/harness/`)에 더하는 이 앱의 규칙이다. 리뷰는 하네스 규칙과 같은 기준으로 본다 (CONVENTIONS §5 "리뷰 기준"). lint 로 막는 규칙은 "강제" 열에 `.swiftlint.yml` 의 규칙 이름을 적는다.

| ✅ 해야 할 것 | ❌ 하지 말아야 할 것 | 강제 |
|---|---|---|
| 저장 형식(`@Model` 필드·저장 문자열)을 바꿀 때는 새 `VersionedSchema` 와 `SchemaMigrationPlan` 단계를 추가한다 | 출시된 스키마 버전(`DDaySchemaV1` 등)의 `@Model` 필드나 저장 문자열을 직접 고치기 | |
| 앱 화면(Feature `Sources`·App) 문구는 그 Feature 의 String Catalog 에 ko·en 을 모두 넣는다 (Example 데모 앱의 시나리오 이름 같은 개발용 문구는 제외). 숫자는 문자열(`String(n)`)로 넘겨 자릿수 구분 없이 표시한다 | 앱 화면에 문자열 하드코딩, `LunarDate.description`·`CalendarDay.description` 으로 화면 표시 | |
