**# 고요행 사용자 앱 — 백엔드 요청사항 (미연동 기능)**

> 작성: 2026-09-13

> 목적: `docs/api_spec.md`(현재 구현/연동 완료 API)에 포함되지 않은, API 연동과 무관하게 UI만 존재하거나 화면조차 없는 5개 기능에 대해 백엔드에 요청할 사항을 정리

> 범위: 비밀번호 찾기 / 약관·개인정보 문서 연결 / SNS 공유 딥링크 / 알림 목록 화면 / 참새(캐릭터) 프로필·기록

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

**## 3. SNS 공유 딥링크**

**### 현재 상태**

`lib/screens/share/sns_share_sheet.dart` — UI(인스타그램/카카오톡/X/블로그 + 링크 복사)는 완성돼 있으나 전부 스낵바 처리. "링크 복사"는 하드코딩된 `https://goyohaeng.app/share` 복사만 함. `pubspec.yaml`에 공유/딥링크 패키지(`share_plus`, `app_links` 등) 없음.

`docs/user_flow.md` §7(공유) 기획: 선택한 SNS 앱의 글쓰기 화면으로 이동, 일러스트 자동 첨부.

**### 요청 API**

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

- 클라이언트에 `share_plus`(범용 공유 시트) 또는 `kakao_flutter_sdk_share`(카카오 전용) 도입 여부 — 백엔드 응답 포맷에 영향

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

`lib/screens/sparrow/sparrow_screen.dart`(695줄) 화면은 완성돼 있고 `lib/data/mock_sparrow.dart`의 `SparrowProfile` 목업만 사용 중 — `DashboardStore.instance.ensureLoaded()`는 호출하지만 결과를 안 쓰고 여전히 `mockSparrowProfile`을 그대로 그림(line 41, 51). `sparrow_service.dart` 없음.

**⚠️ 정정: 필드 중 절반은 이미 백엔드에 존재함.** `lib/api/models.dart:479-506`의 기존 `Dashboard` 모델(`/users/me/dashboard`, 이미 연동 완료)에 아래가 이미 있음:

| 활동 요약 필드 | 이미 있는 소스 |
|---|---|
| `verifiedStampCount` | `Dashboard.verifiedVisitCount` |
| `collectedIngredientCount` | `Dashboard.ingredientCount` |
| `completedFoodCount` | `Dashboard.madeFoodCount` |
| `visitedRegionCount` | `Dashboard.topRegions.length` (근사치) |

→ **이 4개는 새 API가 필요 없고, `sparrow_screen.dart`에서 `mockSparrowProfile` 대신 `DashboardStore.instance.dashboard`를 읽도록 프론트만 고치면 해결됨.**

**### 진짜로 신규 백엔드가 필요한 것만 남김**

```http

GET /sparrow/profile

```

Success `200` 예시:

```json

{
  "nickname": "...",
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
- `nickname`은 7번과 동일 필드 — 별도로 만들지 말고 7번 결론(실명 재사용 여부)에 맞춰 결정

**---**

**## 6. SNS 정보 수정 (프로필의 SNS 플랫폼·아이디)**

**### 현재 상태**

`lib/screens/auth/signup_screen.dart:184` — 회원가입 시 "사용 SNS 플랫폼 및 아이디" 입력 필드 자체가 없음(user_flow §1). `lib/screens/account/account_center_screen.dart:23` — 계정 센터에도 수정 UI 없음(user_flow §3). 주석에 명시: "백엔드도 해당 필드를 아직 제공하지 않는다" — `lib/api/models.dart`의 `Me` 모델에 관련 필드 자체가 없음(확인 완료, grep 결과 0건).

**### 요청 사항**

- `Me` 응답에 `snsPlatform`(enum: instagram/kakao/x/blog 등) + `snsHandle` 필드 추가
- 회원가입 요청 바디에 동일 필드 추가 (`POST /auth/signup`)
- 계정 센터 저장은 기존 `PATCH /users/me` 프로필 수정에 포함 가능한지, 별도 엔드포인트가 필요한지만 결정하면 됨 (신규 엔드포인트 불필요할 가능성 높음)

**---**

**## 7. 참새 닉네임 수정 — ⚠️ 프론트만으로 해결 가능, 백엔드 요청 불필요**

**### 현재 상태**

`lib/screens/sparrow/sparrow_screen.dart:77-78` — 닉네임 옆 연필 아이콘 탭 시 스낵바 **"닉네임은 계정 센터에서 수정할 수 있어요."** 표시. 즉 코드 자체가 이미 "별도 nickname 필드를 새로 만들지 않고 계정 센터의 기존 `realName`을 재사용한다"는 제품 결정을 반영하고 있음 — 그 `realName` 수정은 `account_center_screen.dart:144-152`에서 `PATCH /users/me`로 **이미 연동 완료** 상태.

**### 결론**

새 API/필드 불필요. `_ProfileCard.onEditName`을 스낵바 대신 `Navigator.push(AccountCenterScreen)`으로 바꾸기만 하면 됨 — 순수 프론트엔드 수정.

**### 확인 필요**

- "닉네임"(참새용 애칭)과 "실명"(계정 정보)을 정말 하나로 통일해도 되는지 기획 의도만 재확인 (다르게 가고 싶다면 그때 새 필드 요청 필요 — 그 경우 5번의 `nickname`도 같이 되살림)

**---**

**## 범위 밖 — 이미 별도 트래킹 중인 이슈**

아래는 이번 스캔에서 함께 발견됐지만 "API 연동과 무관한 보조 기능"이 아니라 **핵심 기능인데 백엔드 시드 데이터/엔드포인트 부족으로 미연동**인 이미 알려진 별도 사안이라 이 문서 범위에서 제외함 (세부는 `backend-api-integration` 메모리 참조):

- 지도/랭킹/장소상세/트렌드 전체(`region_ranking_screen`, `trend_summary_screen`, `mock_nearby_suggestions`, `mock_region_ranking`, `mock_map_regions`) — GAP Score·트렌드·즐겨찾기 API가 실 `placeId` 진입점을 아직 못 받음
- `visit_reward_screen.dart:39` 지역 기반 추천 음식 연동 — 위와 동일 계열(장소상세 트렌드 의존)
- 셰프의 주방 → "기록용 플랫폼 공유"(`chef_kitchen_screen.dart:144`) — 이건 신규 API가 아니라 **이미 연동된** `footprint_write_screen`(RecordService)으로 사전 채워 이동하는 내비게이션 연결 누락. 백엔드 요청 불필요, 프론트 작업만 필요

**---**

**## 결론: 백엔드가 실제로 필요한 것 vs 아닌 것**

**### 프론트만으로 해결 가능 — 백엔드 요청 불필요**

- **7. 참새 닉네임 수정** — 코드가 이미 계정 센터 `realName` 재사용을 의도. 스낵바를 `Navigator.push(AccountCenterScreen)`으로 바꾸면 끝.
- **5의 활동 요약 4개 필드**(방문 지역/방문 인증/완성 음식/모은 재료) — 이미 연동된 `/users/me/dashboard`에 다 있음. `sparrow_screen.dart`가 `mockSparrowProfile` 대신 `DashboardStore`를 읽게만 고치면 됨.

**### 백엔드보다 콘텐츠/정책 결정이 우선**

- **2. 약관/개인정보** — 정적 URL 방식(A안)이면 API 자체가 필요 없음. 버전 관리·인앱 렌더링이 필요할 때만 B안(API) 검토.

**### 백엔드 신규 작업이 실제로 필요한 것 (우선순위순)**

1. **5의 나머지(레벨/경험치/함께한 날수/일기) + 참새 diary** — 신규 필드 소수, 서비스 패턴은 기존과 동일
2. **4. 알림 목록** — 단, 푸시 인프라(FCM/APNs) 여부부터 확인 필요 (없으면 선행 작업 큼)
3. **1. 비밀번호 찾기** — 보안 검토(코드 만료/재전송/시도 제한 정책) 필요
4. **6. SNS 정보 수정** — 필드 추가만 하면 되는 단순 확장, 공수는 적음
5. **3. SNS 공유 딥링크** — 공유 시트 자체는 프론트(share_plus/Kakao SDK)로 가능하나, "링크 복사"용 공개 URL·OG 프리뷰는 백엔드/인프라 필요 — 외부 SDK 선택이 선행돼야 함
