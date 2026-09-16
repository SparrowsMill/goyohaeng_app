# 고요행 사용자 앱 — 백엔드 요청사항

## 11. 장소 카드 영업 상태 — RESOLVED (2026-09-16, 7번 항목 대체)

7번에서 요청한 `isOpenNow: boolean | null` 계약 대신, 훨씬 세분화된
`operatingStatus: 'OPEN' | 'BEFORE_OPEN' | 'BREAK_TIME' | 'CLOSED' | 'DAY_OFF' | 'UNKNOWN'`
필드가 다음 4개 응답에 모두 배포됨 — 상세뿐 아니라 목록에도 처음부터 적용돼
있어 7번이 요구했던 "목록엔 없음" 문제 자체가 해소됨:

- `GET /places/{id}` (상세)
- `GET /places/gap/rankings`의 `items[]`
- `GET /places/gap/map`의 `items[]`
- `GET /places/{id}/recommendations`의 `items[]`

`isOpenNow`는 하위 호환용으로 남아 있으나 의미가 바뀜 — `operatingStatus ==
'OPEN'`일 때만 `true`이고 `UNKNOWN`을 포함한 나머지는 전부 `false`다(7번이
요청했던 "정보 부족 = null" 3단 계약이 아니다). 계산 기준(Asia/Seoul, 특별
일정 우선순위, 자정·브레이크타임 처리 등)은 7번 요청 내용과 동일하게
백엔드가 처리하며, 프론트는 더 이상 클라이언트에서 직접 시간을 계산하지
않는다. 상세 응답 예시는 §6.2, 목록은 §7.2~§7.4 참고
([api_spec.md](api_spec.md)).

프론트 연동 완료:

- `Place.operatingStatus`/`GapPlace.operatingStatus` 파싱 추가(`lib/api/models.dart`).
- `BusinessStatus`에 `beforeOpen`/`breakTime` 추가, `holiday` 라벨을 "휴무"→
  "휴무일"로 변경(`lib/data/mock_region_ranking.dart`). 새 `businessStatusFromApi()`가
  `operatingStatus`를 우선 쓰고 없을 때만 옛 `isOpenNow` 2단으로 폴백.
- `gapPlaceToSpot`(`lib/data/gap_spots.dart`)과 `<장소 정보>` 상세 카드
  (`lib/screens/place/place_info_screen.dart`)가 모두 `businessStatusFromApi`를
  거치도록 변경 — 상세 카드의 자체 주간 운영시간 계산 로직(`_computeOpenStatus`
  등)은 서버가 이제 같은 일을 더 정확히 하므로 제거.
- `ChipTone.warning` 추가(`lib/widgets/ranking_card.dart`) — 영업 전/브레이크
  타임은 warning 색조, 영업 종료/휴무일은 negative, 영업 중은 positive.

## 10. 발자국 사진 업로드 API — RESOLVED (2026-09-15)

발자국 기록에 사진을 첨부하려면 기록 저장 API의 `imageUrls`(문자열 URL 배열)에
넣을 URL이 필요한데, 실제 사진 파일을 업로드해서 URL을 발급받는 API가 없어
요청했던 항목. `POST /uploads/images`(Cloudinary 업로드, `multipart/form-data`,
`file` 필드, JWT 필요, JPG/PNG/WEBP만 허용·최대 10MB, 성공 시
`{ "imageUrl": "https://res.cloudinary.com/..." }`)로 배포됨 — 제안했던 스펙과
경로·필드명·응답 구조가 그대로 일치한다. 프론트 연동 완료:

- `UploadService.uploadImage()`(`lib/api/services/upload_service.dart`) 신설,
  `ApiClient.postMultipart()`(`lib/api/api_client.dart`) 추가.
- `footprint_write_screen.dart`의 사진 저장 차단 가드 제거 — 사용자가 갤러리에서
  고른 사진을 저장 시점에 업로드하고, 반환된 URL을 기록 생성/수정의
  `imageUrls`에 담아 함께 저장한다. 수정 시에는 기존 사진(`record.images[].
  imageUrl`)을 유지한 채 새로 고른 사진만 추가로 합친다(PATCH의 `imageUrls`는
  전체 교체라 기존 값과 새 값을 함께 보내야 한다) — 기존 사진 개별 삭제 UI는
  아직 없음.
- 초기 진입 시 채워지는 번들 에셋(보상 일러스트 등, `initialPhotoAssets`)은
  여전히 미리보기 전용이며 업로드하지 않는다(기존 설계 유지).

## 9. 트렌드 요약 — 블로그 발췌문 · SNS 검색 연동 (2026-09-15)

`trend_summary_screen.dart`(§6)의 "이런 글에서 이야기하고 있어요"에 각 게시글
발췌문을 보여주고, "다른 곳에서도 찾아보기"에 Instagram/YouTube/TikTok 검색을
연동하려던 요청.

- **SNS 검색(Instagram/YouTube/TikTok) — RESOLVED (프론트 단독 구현, 2026-09-15).**
  Swagger 전체(모든 path + schema)를 검색해도 `instagram`/`youtube`/`tiktok`/
  `social`/`sns` 문자열이 전혀 없다 — 데이터가 없어서가 아니라 이 기능 자체가
  서버 데이터 없이 되는 기능이라 그렇다. 기존 "네이버 블로그에서 더 찾아보기"
  (`_openNaverBlogSearch`, 서버 호출 없이 검색 URL을 만들어 `url_launcher`로
  여는 방식)와 같은 패턴을 `_openSnsSearch`로 추가해 YouTube/TikTok/Instagram
  버튼을 실제 외부 검색으로 연결했다(Instagram은 키워드 검색 URL이 없어
  해시태그 페이지로 대체 — 결과가 제한되거나 로그인 유도가 뜰 수 있는 한계는
  있음). 백엔드 작업 불필요.
- **블로그 발췌문 — 백엔드 작업 필요, 진행 중.** DB엔 `PlaceExternalContent.
  description` 컬럼이 이미 있지만 `getTrendSummary()`의 select/응답 매핑에서
  빠져 있고, 더 근본적으로 `PlaceExternalContent`·`PlaceTrendSnapshot`을 채우는
  수집 파이프라인 자체가 저장소 어디에도 없다(작성 코드 없음). 배경, 코드
  근거, Prisma select/응답 매핑 변경안, 예시 응답, 수집 파이프라인 제안까지
  정리한 전달용 요청서는 [트렌드 외부 게시글 발췌문 연동 요청](backend_trend_content_request.md)을 참고한다.

## 8. 발자국 장소 선택 저장 및 방문 인증 장소 목록

- 프론트는 방문 인증 장소 선택/수동 입력 두 입력란, 상호 비활성화, 선택 안 함, 팝업 검색·드롭다운·선택 완료 UI를 구현했다.
- `GET /users/me/visited-places` 신설 제안: 로그인 사용자의 VERIFIED 방문 장소를 중복 없이 페이지네이션하고 `placeId`, `placeName`, `recordCount`(현재 공개 기록 수)를 반환. 이름 검색도 지원하면 좋다. 현재는 전체 장소의 `visit-status`를 확인해야 해서 많은 요청이 필요하다. **아직 미해결.**
- **`manualPlaceName` 필드 및 PATCH 장소 변경 — RESOLVED (2026-09-15).** 요청한 대로
  `POST/PATCH /records`에 `placeId`/`manualPlaceName`(최대 100자, 상호 배타,
  PATCH 생략=유지·명시적 null=해제, 장소 변경 시 기존 `visitVerificationId`
  연결 해제)이 배포됐고, `GET /records`·`GET /records/{id}` 응답에도
  `manualPlaceName`이 추가됐다. 프론트 연동 완료:
  - `RecordDetail.manualPlaceName` 파싱 추가(`lib/api/models.dart`).
  - `RecordService.create()`에 `manualPlaceName` 파라미터 추가, `update()`는
    `placeId`/`manualPlaceName`에 `recordFieldUnset` 표시자를 기본값으로 둬
    "생략=유지 / 명시적 null=해제"를 구현(`lib/api/services/record_service.dart`).
  - `footprint_write_screen.dart`의 저장 차단 가드(수동 장소명, 수정 시 장소
    변경) 제거 — 실제로 저장·수정된다. 수정 시 장소 선택/수동 입력이 처음과
    달라졌을 때만 두 필드를 함께 서버에 보낸다(상호 배타 검증을 만족시키기
    위해 항상 같이 보냄).
  - `my_footprint_screen.dart` 피드 카드가 `place` 없을 때 `manualPlaceName`을
    표시하고, 수정 화면 진입 시 기존 `manualPlaceName`을 프리필한다.

## 7. 장소 카드 영업 상태 및 방문 인증 데이터 연동 — 요청 (2026-09-14, 영업 상태 부분은 11번으로 RESOLVED)

Swagger 확인 후 구체화한 전달용 요청서는 [장소 카드 상태 연동 상세 요청](backend_place_status_request.md)을 참고한다. 기존 API 존재 여부, Swagger 명세 누락, 필수 추가 필드와 선택 확장을 구분했다.

### 현상과 확인 결과

- 배포 서버 `GET /places/gap/map` 조회 당시 1,714개 중 `verificationAvailable: true`는 남대문 종합상가(`placeId: 4155`) 1개, 나머지 1,713개는 `false`였다. 별도 조회한 랭킹 상위 50개도 모두 `false`였다. 수치는 조회 시점 기준이다.
- 지도·랭킹 응답에는 `isOpenNow`가 없다. 프론트는 상세 조회 캐시가 없으면 카드에 “영업 여부 알 수 없음”을 표시한다.
- 방문 인증 설정과 영업 상태는 별개다. 영업 중이라는 이유로 방문 인증을 가능하게 하거나, 영업 종료라는 이유로 `verificationAvailable`을 변경하면 안 된다.

### A. 목록 응답에 `isOpenNow` 추가 (필수)

다음 응답의 장소별 `items[]`에 `isOpenNow: boolean | null`을 추가한다.

- `GET /places/gap/rankings`
- `GET /places/gap/map`
- `GET /places/{id}/recommendations`

추천 응답에도 기존 지도·랭킹과 같은 `verificationAvailable: boolean`을 추가해 카드가 상세 조회 캐시에 의존하지 않도록 한다. 기존 필드는 유지한다.

응답 예시(기존 장소 필드는 생략):

```json
{
  "items": [
    { "placeId": 4155, "verificationAvailable": true, "isOpenNow": true },
    { "placeId": 10001, "verificationAvailable": false, "isOpenNow": false },
    { "placeId": 10002, "verificationAvailable": false, "isOpenNow": null }
  ]
}
```

예시 ID·상태는 계약 설명용이며 실제 영업 상태를 뜻하지 않는다.

| 필드/값 | 의미 | 프론트 표시 |
| --- | --- | --- |
| `isOpenNow: true` | 조회 시점에 영업 중임을 판단할 수 있음 | 영업 중 |
| `isOpenNow: false` | 등록된 시간 기준 영업 종료·휴무·브레이크타임 | 영업 종료 |
| `isOpenNow: null` | 운영시간 미등록·불완전 등으로 판단 불가 | 영업 여부 알 수 없음 |
| `verificationAvailable: true` | 인증 설정이 존재하고 `enabled = true` | 방문 인증 가능 |
| `verificationAvailable: false` | 인증 설정이 없거나 비활성화 | 방문 인증 불가 |

구현 요청:

- `places.service.ts`의 상세 조회 영업시간 계산을 공통 함수로 분리해 목록·상세에 동일하게 적용한다. 기준 시간대는 `Asia/Seoul`, 한 요청에서는 같은 기준 시각을 사용한다.
- 현재 `calculateIsOpenNow`는 당일 시간 정보가 없어도 `false`를 반환한다. 이를 그대로 복사하지 말고, **정보 부족은 `null`, 명시된 휴무는 `false`**로 구분한다. 개점·폐점 시간 누락 등 불완전 데이터도 동일하게 처리한다.
- 특정 날짜 예외 일정이 주간 일정에 우선하도록 하고, 브레이크타임·자정을 넘는 영업·전날 시작한 야간 영업을 처리한다. 개점 시각 포함/폐점 시각 제외 등 경계 규칙도 명시한다.
- `GET /places/{id}`의 `isOpenNow`도 같은 nullable 계약으로 맞추고 API 명세 및 응답 타입을 갱신한다. 기존 소비자의 nullable 대응 여부를 확인한다.
- Prisma 조회에서 필요한 운영시간·특정 날짜 일정·인증 설정을 함께 또는 일괄 조회한다. 장소마다 상세 API/DB 쿼리를 반복하는 N+1 방식은 피한다.
- GAP 점수 산출 시점과 현재 영업 상태를 분리한다. 최신 GAP 결과를 재사용하더라도 영업 상태는 요청 시점 기준으로 계산하고, 목록 응답 캐시가 있다면 상태 갱신 정책을 명시한다.
- boolean만으로 휴무와 영업 종료를 구별할 수는 없으므로 이번 계약에서 별도 “휴무” 표시는 요구하지 않는다.

### B. 방문 인증 설정 데이터 점검 (필수, 필드 신설 아님)

- 지도·랭킹의 `verificationAvailable` 구현은 이미 있으므로 기존 의미를 유지한다(`verificationSetting?.enabled ?? false`).
- 실제 인증 운영 대상 장소 목록과 DB 설정을 대조해, 누락된 대상에만 인증 설정 및 가능시간(`SAME_AS_OPERATING` / `CUSTOM`)을 등록한다. 모든 장소를 일괄 활성화하는 요청은 아니다.
- 관리자 ON/OFF 변경이 지도·랭킹·추천·상세에 일관되게 반영되는지 확인한다.
- `verificationAvailable`은 인증 기능 활성화 여부이며 “지금 신청 가능”을 보장하지 않는다. 신청 API의 가능시간·기타 자격 검증은 유지한다.
- 연동 검증용 장소 ID를 제공한다: 활성/영업 중, 활성/영업 종료, 비활성, 설정 없음, 운영시간 미등록. 운영 데이터 변경 없이 검증할 수 있는 테스트 환경을 우선한다.

### C. 완료 기준과 프론트 후속 작업

- 같은 장소를 같은 기준 시각으로 조회하면 지도·랭킹·추천·상세의 `isOpenNow`가 일치한다.
- 운영시간 미등록은 `null`, 명시적 휴무 및 브레이크타임은 `false`, 정상 영업시간 내에는 `true`를 반환한다. 예외 일정·자정 경계·야간 영업 테스트를 포함한다.
- 영업 여부와 인증 활성화 여부의 모든 조합이 독립적으로 반환되고, 인증 설정이 없는 장소는 `verificationAvailable: false`다.
- 실제 운영시간 데이터가 비어 있으면 필드 추가만으로는 영업 상태를 표시할 수 없다. 운영 대상의 시간 데이터 보완 범위와 미등록 건수를 함께 공유한다.
- 배포 후 API 명세, 테스트 장소 ID와 예상 상태, 응답 예시를 전달한다.
- 프론트 후속: `GapPlace.isOpenNow` 추가 → `gapPlaceToSpot` 매핑 → 카드 반영. 상세 `Place.isOpenNow` 파싱도 수정해 명시적 `null`을 `false`로 바꾸지 않는다. 목록이 내려준 `null`을 과거 캐시로 덮어쓰지 않고, 화면 재진입/새로고침 시 목록 캐시를 갱신하도록 한다.

위 내용은 **요청 계약**이며, 아직 배포된 API의 동작을 뜻하지 않는다.

## 1. 약관/개인정보 문서

- `GET /legal/terms`, `GET /legal/privacy` 신설 (또는 정적 문서 URL 2개 제공)
- 응답: `{ version, effectiveDate, content }`
- 버전 이력 관리가 필요한지(DB 테이블) vs 정적 파일 + CDN 링크로 충분한지 결정 필요

## 2. 참새 프로필 카드

- `GET /sparrow/profile` 신설
- 응답: `{ level, xp, xpForNextLevel, daysTogether }`
- 레벨/XP/daysTogether 개념 자체가 DB에 없는 신규 기능 — 레벨업 규칙, XP 획득 조건부터 기획 확정 선행 필요
- (참고: 같은 화면의 활동 요약 2x2 그리드는 `GET /users/me/dashboard`로 이미 연동됨 — 이 항목과 무관)

## 3. 지역 기반 추천 음식

- `visit_reward_screen`에서 지역 기반으로 실 `Food`를 추천할 API 신설 (예: `GET /foods?regionId=`)
- `Food.regionId`, `RegionFoodRegionMapping` 데이터는 이미 있어 노출 엔드포인트만 추가하면 됨

## 4. `GET /regions` SGIS 행정구역코드 필드 추가 — RESOLVED (2026-09-14)

- `GET /regions` 응답에 `sgisCode`(시군구 adm_cd, 5자리 문자열, null 가능) 필드 추가됨
- 원래 요청한 `RegionExternalCode` + `codeType: 'SGIS'` 임포트 방식이 아니라 `Region` 행 자체에 필드를 추가하는 방식으로 처리됨 — 프론트는 `Region.sgisCode`로 반영함(`lib/api/models.dart`)
- 단, `Region` 테이블 자체는 여전히 서울(PROVINCE 1 + DISTRICT 25) + FOOD_REGION 6개뿐이라 그 외 지역은 `sgisCode: null` — 전국 단위 `regionId` 필터가 열린 건 아님. 이어지는 실제 필요는 아래 6번 항목.

## 6. `Region` 테이블 전국 확장 (시도/시군구 전체)

- 현재 `Region`엔 서울(시도 1 + 자치구 25) + `FOOD_REGION` 6개만 있어, GAP 랭킹/지도의 `regionId` 필터가 서울 자치구 단위까지만 동작함(`lib/data/gap_spots.dart`, `lib/api/services/gap_service.dart`)
- 서울 외 지역은 프론트가 `GET /places/gap/map`(전국, 좌표 포함) + 앱 내 GeoJSON 폴리곤으로 클라이언트단 필터링해 우회 중 — 서버 filter가 아니라서 좌표 없는 장소는 누락됨
- `Region`에 전국 시도/시군구 행이 추가되고 각 행에 `sgisCode`(4번 항목 참고)까지 채워지면, 이름 매칭 대신 `sgisCode` 매칭으로 전환해 서울 자치구와 동일한 방식(정확한 `regionId` 필터)을 전국으로 확장 가능

## 5. 장소 이미지 에셋 URL 미채움

- `Place.imageUrl`이 다음 3개 응답에서 계속 `null`로 나감:
  - `GET /users/me/favorites` (`api_spec.md:311`)
  - `GET /places/gap/rankings` (`api_spec.md:732`)
  - `GET /places/{id}/recommendations` (`api_spec.md:837`)
- 실제 장소 1,714곳(랭킹 `total` 기준) 각각의 사진이라 앱에 정적 에셋으로 대체 불가 — 실제 이미지 파일을 S3/CDN에 업로드하고 해당 URL을 DB에 채워 넣는 데이터 입력이 필요
- (참고: `Food`/`UserFood`, `Ingredient`의 `imageUrl`/`illustrationUrl`도 계속 `null`이었지만(`api_spec.md:375`), 콘텐츠 마스터(I01~I27, D01~D39) 기준 음식 39종·재료 27종 전부의 이름과 정확히 일치하는 로컬 워터컬러 에셋이 `assets/illustrations/rewards/dish|ingredient/`에 이미 있어 프론트에서 이름 매칭으로 우선 표시하도록 처리함(`lib/widgets/reward_image.dart`) — **음식/재료는 DB에 imageUrl을 채워달라는 요청 자체가 필요 없음.** 앞으로 새 음식/재료가 추가될 때만 그림을 새로 받으면 됨)
- (참고: 발자국 기록 사진 `RecordImage.imageUrl`은 사용자 업로드 값이라 정상 동작 중, 본 항목과 무관)
