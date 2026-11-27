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
| 저장소: SwiftData. 사진은 3:2 로 자른 JPEG 두 벌(품질 0.8, 원본 메타데이터 없음·방향은 픽셀에 반영): 압축본 긴 변 최대 1600px·썸네일 최대 400px(작으면 키우지 않음). 썸네일은 `DDayRecord.photoThumbnail`, 압축본은 별도 모델 `DDayPhotoRecord`(디데이 id unique) 이고 둘 다 `.externalStorage`, 사진 id(`photoID`, 사진을 바꿀 때마다 새로 만듦)로 짝을 맞춘다. 목록(`fetchAll`)은 썸네일만 읽고 압축본은 `fetchPhoto(id:)` 로만 읽는다(디데이 상세에서만. 언제 읽는지는 "디데이 상세" 행). 사진 바꾸기·지우기·디데이 삭제는 썸네일·압축본을 한 번의 save 로 한다. Client `DDayStore` 가 감싼다. 스키마는 `VersionedSchema`(V1 부터) + `SchemaMigrationPlan` 으로 버전 관리. 저장소는 처음 쓰는 호출에서 연다. 열지 못하면 그 호출이 `.loadFailed` 를 던지고 실패를 기억하지 않아 다음 호출이 다시 연다 (앱에 열기 실패 화면은 없고 목록의 불러오기 오류·다시 시도로 보인다) | 기기 안 저장만 필요하고 외부 의존성 없이 쓸 수 있다. 출시 뒤 저장 형식을 바꿔도 기존 데이터를 옮길 수 있다. 첫 잠금 해제 전 실행처럼 일시적인 열기 실패에서 앱을 다시 켜지 않고 회복한다 |
| 알림: UserNotifications 로컬 알림. 가까운 순 최대 60개 예약 후 다시 계산. 무엇을 예약할지는 Core `NotificationPlanner`(순수 로직)가 정한다: 지난 알림 제외. D-day 방식은 목표일(매년 반복은 다음 날짜 2번까지), D+·1일째 방식은 시작일(오늘 이후면)과 기념일(100일 단위: 화면 숫자 기준 — D+ 는 시작일+100k일, 1일째는 +100k−1일 / N주년: 시작일과 같은 날짜, 2/29·음력은 매년 반복 규칙)에 같은 N일 전·시간으로 알린다. 기념일은 N일 전마다 알림 날짜가 오늘 이후인 다음 2번까지, 100일과 주년이 같은 날이면 주년 하나. 반복 규칙은 D-day 방식에서만 쓴다. 알림 날짜는 고정 4개(30일 전·7일 전·2일 전·당일, `ReminderSettings.daysBeforeChoices`)를 디데이마다 켜고 끈다 (새 디데이는 7일 전·2일 전·당일 켜짐, 30일 전 꺼짐). 선택지 밖 값은 `ReminderSettings` 가 버리고, 계획기에는 켜진 날짜(`scheduledDaysBefore`)만 넘긴다. 디데이마다 '100일마다'·'매년(N주년)'을 켜고 끈다(기본 켜짐, D+·1일째일 때만 편집 화면에 보이고 값은 늘 저장. 알림 전체를 끄면 기념일 알림도 없다) | iOS 예약 한도 64개. 고정 토글이라 입력 검증이 없고 끈 날짜도 늘 화면에 보인다. 30일 전은 달마다 간격이 달라지지 않게 날짜 수로 정하고, 화면에도 "30일 전"으로 보여 헷갈리지 않게 한다. 기념일 표시(화면)는 2차, 알림만 MVP |
| 음력: 한국천문연구원 기준 표(음력 1900~2050년, korean-lunar-calendar 0.3.1 의 MIT 데이터에서 추출, 라이선스 고지 포함: `Projects/Shared/Core/Sources/Calendar/KoreanLunarTable.swift`). 변환 범위는 원본이 검증한 양력 1900-01-31 ~ 2050-12-31(음력 2050-11-18까지)이고 밖이면 `nil`. 날짜 차이는 Core `CalendarDay` 의 율리우스 일(JDN)로 계산 | Foundation `.chinese` 달력은 중국 기준이라 한국 날짜와 다른 해가 있다 (예: 2027 설날 한국 2/7, 중국 2/6) |
| 사진 선택: PhotosUI `PhotosPicker` (보관함 인자 없이 써서 권한 요청 없음). Client `Photo` 의 Impl `PhotoPickerButton` 이 감싸고, App 이 편집 View 슬롯(`PhotoPickerButtonConfiguration` 을 받는 클로저)에 주입한다. Feature·App 은 PhotosUI 를 import 하지 않는다 (Example 은 Testing 의 `PhotoPickerButtonFake`). 사진 처리(읽기·방향 반영 디코딩·자르기·JPEG 만들기, ImageIO·CoreGraphics)도 Photo Impl 이 `@concurrent` 로 하고, 자르기 영역 규칙(3:2·확대 1~3배·클램프·출력 크기)은 Core `PhotoCropGeometry`. 입력 한도 100MiB·1억 화소(넘으면 `.tooLarge`), 자르기용 작업 이미지 긴 변 최대 3200px | 사진 권한 없이 사용자가 고른 사진만 받는다. `PhotosPicker` 는 SwiftUI 뷰라 Client 경계 안에 두려면 View 째로 주입해야 하고, Feature 는 결과(`PickedPhoto`)만 받는다 |
| 썸네일 표시: 홈 카드·상세·편집 미리보기는 `UIImage(data:)` 를 `byPreparingForDisplay()` 로 메인 밖에서 디코딩해 View 의 `@State` 에 둔다 (`.task(id:)` 로 디코딩한다: 키는 홈 카드·상세가 사진 id, 편집 미리보기가 썸네일 Data. 키가 바뀔 때와 View 가 다시 나타날 때 다시 디코딩하며 캐시는 두지 않는다. 실패하면 기본 배경·사진 아이콘) | 앱 코드가 픽셀을 다루지 않고 시스템 비동기 표시 준비 API 를 부르는 것이고, 결과는 화면을 떠나면 사라지는 View 일시 상태(ARCHITECTURE 규칙 8)다. 400px 썸네일 디코딩에 Client 를 두면 Home 이 Photo 에 의존하고 HomeModel 에 사진별 상태가 생겨 얻는 것 없이 복잡해진다. 이미지 처리(자르기·인코딩)는 Photo Impl 에서 `@concurrent`(CONVENTIONS §2) |
| 다국어: String Catalog, 한국어·영어. Feature 문구는 자기 `Sources/Localizable.xcstrings`(Tuist 가 `<Feature>_<Feature>.bundle` 과 `Bundle.module` 생성, 코드는 `.atURL(Bundle.module.bundleURL)`). 앱 Info.plist `CFBundleLocalizations` = ko·en (`Env.appInfoPlist`) | 없으면 하위 번들 언어가 메인 앱 developmentRegion 하나로 고정된다 (App 은 항상 한국어, Example 은 항상 영어) |
| 최소 지원: iOS 18.0, iPhone 만 | 더 많은 기기 지원 |
| 디자인 팔레트(라이트/다크): Blush Pink #FF8FB1(강조색·연인), Lavender #C9B6FF/#A996F0(기타), Peach #FFC6A8/#F0A989(생일), Mint #A8E6CF/#7FCFB2(가족), Butter #FFE8A3/#E8CF7E(당일 배지), 배경 #FFF8F6/#1E1A22, 카드 #FFFFFF/#2A2430, 글자 #4A3F4B/#F3ECF5 | 10~20대 여성 타깃의 파스텔·다꾸 감성 |
| 폰트: 한글 Pretendard(OFL), D-day 숫자 SF Pro Rounded | |
| 디자인 에셋(앱 아이콘·폴더 아이콘·일러스트·기본 배경)은 사용자가 ChatGPT 로 만든다. 사진 없는 카드·상세의 기본 배경은 지금 자리 표시 `DefaultCardBackground`(Home `Sources/Assets.xcassets`, 1200×800 Blush Pink→Lavender 그라데이션)이고 같은 이름으로 교체한다 (4단계에서 폴더 색 기본 배경으로 바뀐다) | |
| "오늘" 기준: `CalendarDay(Date(), in: .autoupdatingCurrent)`(기기 현재 시간대의 날짜)를 App 이 클로저로 `HomeModel`·`DDayDetailModel` 에 주입. 앱 복귀(scenePhase active)·자정(`.NSCalendarDayChanged`)·시간대 변경(`.NSSystemTimeZoneDidChange`) 때 다시 구해 바뀌었을 때만 다시 정렬한다(상세는 카운트만 다시 계산. 둘 다 저장소는 다시 읽지 않음). App 은 같은 방식으로 구한 오늘을 편집 화면(`DDayEditorModel`)을 열 때 한 번 넘겨 추가 모드의 시작 날짜로 쓴다 (열린 동안 날짜가 바뀌어도 다시 구하지 않는다) | 테스트에서 날짜를 고정하고, 자정·여행 중에도 카운트가 맞게 |
| 디데이 상세: Home Feature 안 `DDayDetailModel`·`DDayDetailView`. 카드 탭 → NavigationStack push 이고, App(`AppFlow`)이 모델을 만들어 소유한다 (떠 있는 동안 카드 탭이 또 와도 다시 열지 않고, `navigationDestination(item:)` 바인딩의 set(nil) 이 닫힘). 보이는 것: 사진(3:2), 제목, 카운트, 날짜(음력이면 양력 날짜 줄도), 매년 반복 D-day 면 처음 날짜, 반복(D-day 방식일 때), 세는 방식. 편집 결과를 홈·상세 둘 다에 넘기고, 사진 id 가 바뀌면 압축본을 다시 읽고 늦게 온 옛 결과는 버린다(취소 대신 디데이 id·사진 id 키로 거른다). savedAsNew 가 지금 보는 디데이를 바꾸면 새 디데이로 전환하고, 지금 보는 디데이가 지워지면 상세 모델의 `isRemoved` 를 보고 App 이 닫는다. 상세 압축본 표시: Model 은 `fetchPhoto` 로 읽은 압축본 Data 만 상태로 두고, View 가 "썸네일 표시" 행과 같은 방식(`byPreparingForDisplay`, `.task(id: 사진 id)`, 캐시 없음)으로 디코딩하며 썸네일을 늘 아래에 깐다. 읽는 중·압축본 없음(nil)·실패·디코딩 실패면 썸네일이 보이고(안내 문구 없음), 앱 복귀 때 실패한 읽기만 한 번 다시 읽는다. 사진이 없으면 기본 배경 | Feature 끼리 의존하지 않고 기본 배경 에셋을 Home 에만 두며, 홈 모델이 화면 두 개 몫을 맡지 않는다. 5단계 알림에서 App 이 홈을 거치지 않고 상세를 열 수 있다. 압축본 디코딩도 썸네일과 같은 이유(시스템 표시 준비 API, View 일시 상태)이고, Home 이 Photo 에 의존하지 않는다 |
| 디데이 편집: 추가·수정을 한 화면(Feature `DDayEditor`)으로 하고, 추가는 홈의 [+], 수정은 상세 화면의 [편집] 에서 App 이 시트로 띄운다 (떠 있는 동안 다시 열지 않고, 늦게 끝난 옛 편집은 새로 연 시트를 닫지 않는다. 이 판단은 Feature 의 순수 값 `DDayEditorPresentation`). 홈·상세와 같은 저장소를 쓰고, 결과는 콜백으로 받아 홈과 상세에 다시 읽지 않고 반영한다 (`HomeModel`·`DDayDetailModel` 의 `dDaySaved(_:)`·`dDaySavedAsNew(_:replacing:)`·`dDayDeleted(id:)`. 불러오는 중에 온 결과는 불러온 목록에 적용하고, 불러오기 실패 중 저장되면 다시 불러온다). 양력은 `supportedSolarRange` 안에서만, 음력 선택지는 `KoreanLunarCalendar.solarDay(from:)` 가 nil 이 아닌 것만 고른다 (음력 2050-11-18까지). 연·월·윤달을 바꿔 고를 수 없게 된 값은 평달·그 달 마지막 선택 가능 일로 맞춘다. 사진은 편집 화면 맨 위 사진 섹션에서 추가·바꾸기·지우기하고, 고르면 3:2 자르기 화면(시트 안 내비게이션 push)으로 간다. 사진 처리 중에는 저장·삭제를 막고 불러오기·편집 취소는 할 수 있으며, 처리에 실패하면 안내 문구만 띄우고 기존 사진·입력을 그대로 둔다 | 홈이 저장소를 다시 읽지 않아도 바로 보인다. 변환할 수 없는 음력은 처음부터 고를 수 없게 막는다 |

## 3. 프로젝트 규칙
하네스 규칙(`docs/harness/`)에 더하는 이 앱의 규칙이다. 리뷰는 하네스 규칙과 같은 기준으로 본다 (CONVENTIONS §5 "리뷰 기준"). lint 로 막는 규칙은 "강제" 열에 `.swiftlint.yml` 의 규칙 이름을 적는다.

| ✅ 해야 할 것 | ❌ 하지 말아야 할 것 | 강제 |
|---|---|---|
| 저장 형식(`@Model` 필드·저장 문자열)을 바꿀 때는 새 `VersionedSchema` 와 `SchemaMigrationPlan` 단계를 추가한다. 단 출시(1.0.0) 전에는 V1 을 직접 고치고 V1 문서 주석에 '출시 전 변경'으로 적는다. 이때 추가 필드는 기본값(또는 optional)이 필수이고(없으면 옛 저장소가 134110 으로 열리지 않는다), 옛 저장소 열기 테스트(`DDayStoreLegacyOpenTests`)를 함께 고친다 | 출시된 스키마 버전(`DDaySchemaV1` 등)의 `@Model` 필드나 저장 문자열을 직접 고치기 | |
| 앱 화면(Feature `Sources`·App) 문구는 그 Feature 의 String Catalog 에 ko·en 을 모두 넣는다 (Example 데모 앱의 시나리오 이름 같은 개발용 문구는 제외). 숫자는 문자열(`String(n)`)로 넘겨 자릿수 구분 없이 표시한다 | 앱 화면에 문자열 하드코딩, `LunarDate.description`·`CalendarDay.description` 으로 화면 표시 | |
