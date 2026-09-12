**# 고요행 사용자 앱 — 백엔드 요청사항 (미연동 기능)**

> 작성: 2026-09-13

> 목적: `docs/api_spec.md`(현재 구현/연동 완료 API)에 포함되지 않은, API 연동과 무관하게 UI만 존재하거나 화면조차 없는 기능에 대해 백엔드에 요청할 사항을 정리. 프론트만으로 해결 가능했던 항목(참새 닉네임 수정, SNS 공유 시트 열기, 참새 활동 요약 4개 필드)은 이미 조치 완료해 이 문서에서 제외함.

> 범위: 비밀번호 찾기 / 약관·개인정보 문서 연결 / SNS 공유 딥링크(링크 발급) / 알림 목록 화면 / 참새(캐릭터) 프로필·기록 / SNS 정보 수정 / 지도·랭킹 연계 화면의 남은 백엔드 공백

**---**

**## 1. 비밀번호 찾기**

**### 현재 상태**

`lib/screens/auth/login_screen.dart:139-146` — "비밀번호 찾기" 버튼은 존재하나 `onPressed`에서 스낵바("비밀번호 찾기는 준비 중이에요.")만 표시. 재설정 화면/모델/API 전무.

**### 요청 API**

```http

POST /auth/password/reset-request

```

Request:

```json

{ "email": "user@example.com" }

```

인증코드 발송 (이메일 또는 SMS 중 정책 확인 필요).

```http

POST /auth/password/verify-code

```

Request:

```json

{ "email": "user@example.com", "code": "123456" }

```

Success `200` — 단기 `resetToken` 반환:

```json

{ "resetToken": "..." }

```

```http

POST /auth/password/reset

```

Request:

```json

{ "resetToken": "...", "newPassword": "..." }

```

**### 확인 필요**

- 인증코드 유효시간, 재전송 쿨다운(예: 60초), 최대 시도 횟수
- 디자인 시스템의 "Verification Code"(40px) 컴포넌트를 다른 화면(회원가입/방문인증)에서 이미 쓰고 있다면 그대로 재사용

**---**

**## 2. 약관/개인정보 문서 연결**

**### 현재 상태**

`lib/screens/auth/signup_screen.dart` — 동의 체크박스(`_agreeTerms`/`_agreePrivacy`)는 존재하나, 라벨 탭 시 스낵바만 표시(line 579 TODO). 실제 문서 콘텐츠/URL 없음.

**### 요청 사항 (API보다 콘텐츠 제공 방식 결정이 우선)**

- (A) 정적 문서 URL 2개(약관/개인정보)만 제공 → 앱에서 `url_launcher`(이미 pubspec에 있음)로 브라우저/웹뷰 오픈, 또는
- (B) 아래 API로 인앱 렌더링:

```http

GET /legal/terms

GET /legal/privacy

```

Success `200` 예시:

```json

{ "version": "2026-09-01", "effectiveDate": "2026-09-01", "content": "..." }

```

**### 확인 필요**

- 회원가입 API가 현재 `agreeTerms`/`agreePrivacy` 동의 여부를 저장하고 있는지
- 법적 대응을 위해 **동의한 약관 버전**을 저장할 필요가 있는지 (필요 시 회원가입 요청에 `termsVersion`/`privacyVersion` 추가)

**---**

**## 3. SNS 공유 — 링크 발급**

**### 현재 상태**

`lib/screens/share/sns_share_sheet.dart` — SNS 선택 시 OS 공유 시트를 여는 부분은 `share_plus`로 프론트에서 이미 해결함(백엔드 요청 불필요). 다만 특정 앱으로 바로 딥링크(카카오톡 전용 피드 템플릿 등)까지는 아니며, 그건 아래와 별개로 앱별 SDK 도입이 선행돼야 함.

**"링크 복사"**는 여전히 하드코딩된 `https://goyohaeng.app/share` 복사만 함 — 실제 공개 URL이 없어서 이 부분만 백엔드가 필요함.

**### 요청 API (링크 복사용 공개 URL)**

```http

GET /rewards/{rewardId}/share-link

```

Success `200` 예시:

```json

{ "url": "https://goyohaeng.app/share/{rewardId}", "imageUrl": "https://cdn.../reward.png", "title": "...", "description": "..." }

```

- `url`은 OG 태그(이미지/제목/설명)가 붙은 공개 랜딩 페이지여야 링크 복사 시 카톡/문자 미리보기가 정상 표시됨
- `imageUrl`은 외부 앱 공유용이므로 로컬 asset이 아닌 **공개 CDN URL**이어야 함
- 카카오톡 공유는 보통 클라이언트 Kakao SDK(feed template)로 처리 — 백엔드는 템플릿용 `title/description/imageUrl/webUrl`만 내려주면 됨

**### 확인 필요**

- 카카오톡 전용 피드 템플릿까지 원하면 `kakao_flutter_sdk_share` 추가 도입 여부 결정 필요 — 백엔드 응답 포맷에 영향

**---**

**## 4. 알림 목록 화면**

**### 현재 상태**

벨 아이콘만 `lib/screens/mill/mill_home_screen.dart:185`, `lib/screens/map/map_screen.dart:272` 2곳에 존재(`_NotificationBell`), 탭해도 동작 없음. 화면 자체가 없음.

참고: 알림 *설정* 토글 3종(프로모션/주변/기록)은 이미 `PATCH /users/me/settings`로 연동 완료 — 이번 요청은 실제 알림 *목록*.

**### 요청 API**

```http

GET /notifications?cursor={cursor}&limit={limit}

```

Success `200` 예시:

```json

{
  "items": [
    { "id": "...", "type": "promotion", "title": "...", "body": "...", "imageUrl": null, "isRead": false, "createdAt": "...", "targetRoute": null }
  ],
  "nextCursor": "..."
}

```

```http

PATCH /notifications/{id}/read

PATCH /notifications/read-all

GET /notifications/unread-count

```

Success `200` 예시(unread-count):

```json

{ "count": 3 }

```

**### 확인 필요**

- `type` 값을 기존 설정 토글 카테고리(promotion/nearby/record)와 일치시킬 것
- 푸시 발송(FCM/APNs) 인프라가 이미 있는지 — 없다면 디바이스 토큰 등록(`POST /devices/register`)이 선행 작업으로 필요

**---**

**## 5. 참새(캐릭터) 프로필·기록**

**### 현재 상태**

`lib/screens/sparrow/sparrow_screen.dart`(695줄) 화면은 완성돼 있음. 프로필 카드(이름·레벨·경험치·함께한 날수)와 일기 미리보기는 여전히 `lib/data/mock_sparrow.dart`의 `SparrowProfile` 목업을 그대로 씀 (`sparrow_service.dart` 없음). 활동 요약 4개 필드(방문 지역/방문 인증/완성 음식/모은 재료)는 이미 `DashboardStore`로 연동돼 있어 아래 요청에서 제외함. 닉네임도 별도 필드 없이 계정 센터의 기존 `Me.realName`을 재사용하도록 프론트에서 이미 연결해 아래에서 제외함.

**### 요청 API**

```http

GET /sparrow/profile

```

Success `200` 예시:

```json

{
  "level": 3,
  "xp": 120,
  "xpForNextLevel": 200,
  "daysTogether": 42,
  "nextMillRegion": "...",
  "nextMillRemaining": 3
}

```

```http

GET /sparrow/diary/latest

```

Success `200` 예시:

```json

{ "date": "2026-09-13", "content": "..." }

```

**### 확인 필요**

- "기록" 요구사항상 다이어리 **이력**(목록)이 필요하면 `GET /sparrow/diary?cursor=&limit=` 추가 필요 — 현재 목업은 최신 1건만 존재
- `nextMillRegion/Remaining`이 기존 GAP Score API(`docs/api_spec.md` §7)에서 파생 가능한지 확인 — 가능하면 새 필드 없이 기존 API 조합으로 해결

**---**

**## 6. SNS 정보 수정 (프로필의 SNS 플랫폼·아이디)**

**### 현재 상태**

`lib/screens/auth/signup_screen.dart:184` — 회원가입 시 "사용 SNS 플랫폼 및 아이디" 입력 필드 자체가 없음(user_flow §1). `lib/screens/account/account_center_screen.dart:23` — 계정 센터에도 수정 UI 없음(user_flow §3). 주석에 명시: "백엔드도 해당 필드를 아직 제공하지 않는다" — `lib/api/models.dart`의 `Me` 모델에 관련 필드 자체가 없음(확인 완료, grep 결과 0건).

**### 요청 사항**

- `Me` 응답에 `snsPlatform`(enum: instagram/kakao/x/blog 등) + `snsHandle` 필드 추가
- 회원가입 요청 바디에 동일 필드 추가 (`POST /auth/signup`)
- 계정 센터 저장은 기존 `PATCH /users/me` 프로필 수정에 포함 가능한지, 별도 엔드포인트가 필요한지만 결정하면 됨 (신규 엔드포인트 불필요할 가능성 높음)

**---**

**## 7. 지도/랭킹 연계 화면 — 남은 백엔드 공백**

**### 현재 상태**

`region_ranking_screen`(`GapSpots.spotsInRegion`) / `place_info_screen`(`PlaceService().detail`, `GapService().placeGap`) / `visit_unavailable_screen`(`GapService().recommendations`) / `trend_summary_screen`(`PlaceService().trends`) — 이 화면들은 전부 실 API로 연동돼 있고, mock(`mock_region_ranking`/`mock_nearby_suggestions`/`mock_trend_summary`/`mock_map_regions`)은 API 실패·빈 응답일 때의 폴백으로만 남아있음. 아래 3개만 실제로 아직 채울 API가 없음:

**### 요청 사항**

1. **트렌드 요약의 "외부 게시글/검색어 트렌드/SNS 검색" 하위 섹션** (`trend_summary_screen.dart:27`) — 메인 키워드·AI 요약은 `GET /places/{id}/trends`로 이미 실데이터인데, `contents`(외부 게시글)·`searchInterest`(검색어 트렌드) 구조가 스펙에 빈 배열 placeholder만 있어서 이 하위 섹션만 여전히 mock. 실 콘텐츠 구조/데이터 소스 확정 필요.
2. **장소 정보의 "획득 가능 재료" / "매장 혜택" 표시** (`place_info_screen.dart`, `gap_spots.dart:193` `ingredient: null` 고정) — GAP 랭킹·지도 API가 이 필드를 안 줌. 방문 인증 전에는 어떤 재료가 나올지 알 수 없는 구조(관리자 승인 시점 랜덤 드롭, 스펙 §7.4–7.5)라 사전 노출용 필드가 필요하면 별도 설계 필요.
3. **`visit_reward_screen.dart:39` 지역 기반 추천 음식** — `FoodInfoScreen`이 목업 `MockFoodInfo`만 받는 구조라, 실 `Food`를 지역 기반으로 추천해 연결할 어댑터/API가 없음.

**### 확인 필요**

- 위 3개 모두 이미 연동된 API(`/places/{id}/trends`, GAP 랭킹/지도)의 **확장**인지, 완전히 새 엔드포인트가 필요한지 백엔드와 확인
- 셰프의 주방 → "기록용 플랫폼 공유"(`chef_kitchen_screen.dart:144`)는 신규 API가 아니라 **이미 연동된** `footprint_write_screen`(RecordService)으로 사전 채워 이동하는 내비게이션 연결만 빠진 것 — 백엔드 요청 불필요, 프론트 작업만 필요

**---**

**## 우선순위 제안**

**### 백엔드보다 콘텐츠/정책 결정이 우선**

- **2. 약관/개인정보** — 정적 URL 방식(A안)이면 API 자체가 필요 없음. 버전 관리·인앱 렌더링이 필요할 때만 B안(API) 검토.

**### 백엔드 신규 작업 (우선순위순)**

1. **5. 참새 프로필**(레벨/경험치/함께한 날수/일기) — 신규 필드 소수, 서비스 패턴은 기존과 동일
2. **4. 알림 목록** — 단, 푸시 인프라(FCM/APNs) 여부부터 확인 필요 (없으면 선행 작업 큼)
3. **1. 비밀번호 찾기** — 보안 검토(코드 만료/재전송/시도 제한 정책) 필요
4. **6. SNS 정보 수정** — 필드 추가만 하면 되는 단순 확장, 공수는 적음
5. **3. SNS 공유 — 링크 발급**("링크 복사"용 공개 URL + OG 프리뷰) — 카카오 전용 SDK까지 원하면 앱 키 발급 등 선행 필요
6. **7. 지도/랭킹 연계 화면의 남은 3개 공백**(트렌드 하위 섹션 / 장소 혜택·재료 표시 / 지역 기반 추천 음식) — 이미 연동된 API의 확장 성격이라 공수는 상대적으로 작을 가능성
