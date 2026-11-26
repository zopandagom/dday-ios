# 디데이

10~20대 여성을 위한 예쁜 디데이 앱이다. 디데이를 생일·가족·연인 같은 폴더로 묶어 보고, 디데이마다 사진을 붙이고, 30일 전·7일 전·2일 전·당일 중 고른 날짜에 로컬 알림을 받는다. 한국어·영어를 지원한다.

**핵심 약속: 완전 무료·광고 없음. 서버·로그인 없이 모든 데이터(디데이·사진)는 기기 안에만 저장한다.**

## 핵심 기능 (MVP)
- 디데이 추가·수정·삭제·목록 (다가오는 → 세는 중 → 지난 순 정렬, 상세는 docs/DEVELOPMENT_PLAN.md)
- 양력·음력(윤달 포함, 한국천문연구원 기준) 날짜, 매년 반복, 세는 방식(D-day / D+ / 시작일=1일)
- 디데이마다 이미지 (내 사진 또는 기본 배경, 카드 비율 자르기)
- 폴더: 기본 폴더(생일·가족·연인·기타) + 직접 만든 폴더
- 로컬 알림: 기본 7일 전·2일 전·당일 오전 9시, 디데이마다 끄기·알림 날짜(30일 전·7일 전·2일 전·당일) 켜기·끄기·시간 설정, D+·1일째 디데이는 100일 단위(100·200·300…일)·N주년 기념일 알림
- 한국어·영어, 다크 모드, 첫 실행 안내

## 기술 스택
- SwiftUI (규칙 기반 단방향 MV), Swift 6 strict concurrency, iOS 18.0+ (iPhone)
- Tuist 모듈러 아키텍처 (Feature / Client Interface·Impl·Testing / Shared)
- SwiftData (디데이·폴더·이미지 저장), UserNotifications (로컬 알림), PhotosUI (사진 선택), BackgroundTasks (알림 재예약 보조), String Catalog (ko/en)

## 시작하기
```bash
make bootstrap   # mise 로 tuist·swiftlint·swiftformat·xcbeautify 설치, git 훅(pre-commit: main 커밋 차단·lint, pre-merge-commit: main 머지 커밋 차단, pre-push: main push 차단) 연결
make generate    # DDay.xcworkspace 생성 후 Xcode 로 열기
make test        # 전체 모듈 빌드 + 테스트 + git 훅 테스트
make test-hooks  # git 훅 동작 테스트만 (임시 레포에서 main 커밋·머지 커밋·push 차단과 기능 브랜치 통과 확인)
make lint        # 포맷·아키텍처 규칙 검사 (make format 으로 자동 수정)
```

## 문서
- [제품 결정: 약속·기술 결정·프로젝트 규칙](docs/PRODUCT.md)
- [아키텍처](docs/harness/ARCHITECTURE.md)
- [개발 규칙: 해야 할 것 / 하지 말아야 할 것](docs/harness/CONVENTIONS.md)
- [개발 계획과 로드맵](docs/DEVELOPMENT_PLAN.md)
- [작업 진행 방식과 완료 기준](docs/harness/WORKFLOW.md)
- [Claude Code 작업 안내](CLAUDE.md)

이 프로젝트는 [ios-harness](https://github.com/zopandagom/ios-harness) 템플릿으로 만들었다 (`.harness-version`). 하네스 변경은 플러그인을 업데이트한 뒤 `/ios-harness:update-harness` 로 가져온다.
