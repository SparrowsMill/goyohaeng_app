**# 고요행 사용자 앱 API 명세서 — FINAL**

> 최종 수정: 2026-09-13  

> 대상: Flutter 사용자 앱 ↔ NestJS 백엔드 연동  

> 범위: 현재 구현 및 회귀 테스트가 완료된 사용자 앱 API  

> 제외: `/external-api/*` 데이터 적재용 API, 관리자/사업자 전용 기능

**---**

**## 1. 기본 정보**

**### Base URL**

```text

http://{SERVER_HOST}:3000/api/v1

```

로컬 개발 환경:

```text

http://localhost:3000/api/v1

```

Swagger:

```text

http://localhost:3000/api-docs

```

**### 인증 방식**

인증이 필요한 API는 로그인 후 발급받은 JWT Access Token을 사용한다.

```http

Authorization: Bearer {accessToken}

```

Swagger의 `Authorize` 입력창에는 `Bearer`를 붙이지 않고 `accessToken` 값만 입력한다.

**### 공통 주의사항**

- 날짜/시간 응답은 ISO 8601 문자열을 기본으로 처리한다.

- 발자국의 `date`는 `YYYY-MM-DD` 형식이며 한국 시간(KST) 기준으로 처리한다.

- `regionId`, `categoryId`, `placeId`, `verificationId`, `ingredientId`, `foodId`, `userFoodId`, `recordId`는 프론트에서 임의의 고정값으로 하드코딩하지 않는다.

- `/external-api/*`는 서버/DB 데이터 적재용 내부 API이므로 사용자 앱에서 직접 호출하지 않는다.

- 현재 MVP 데이터 범위는 서울 중심이다.

- `Place.ownerIntro`는 더 이상 사용하지 않는다. 장소 소개 필드는 `overview`를 사용한다.

- GAP 기반 방문 보상은 기존 `place_ingredient_rewards`의 고정 보상 방식과 다르다. 일반 방문 인증 보상 UI는 GAP 기반 랜덤 보상을 기준으로 구현한다.

- 방문 인증 6자리 코드는 사용자가 서버에 다시 제출하는 인증 비밀번호가 아니다. 사용자가 매장 관리자에게 보여주는 식별 코드이며, 최종 승인/반려는 관리자 웹에서 처리한다.

- 사용자 앱에서는 `/business/*` 관리자 API를 직접 호출하지 않는다.

**---**

**## 2. Auth**

**### 2.1 아이디 중복 확인**

```http

GET /auth/check-username?username={username}

```

| 이름 | 타입 | 필수 | 설명 |

|---|---|:---:|---|

| `username` | string | O | 중복 확인할 아이디 |

**### 2.2 회원가입**

```http

POST /auth/signup

```

Request Body:

```json

{

  "username": "yerin123",

  "password": "password123!",

  "realName": "조예린",

  "email": "yerin@example.com",

  "phone": "010-1234-5678",

  "birthDate": "2002-05-20",

  "gender": "FEMALE"

}

```

`gender`: `MALE` 또는 `FEMALE`

Success `201` 예시:

```json

{

  "userId": 1,

  "username": "yerin123",

  "realName": "조예린",

  "message": "회원가입이 완료되었습니다."

}

```

**### 2.3 로그인**

```http

POST /auth/login

```

Request Body:

```json

{

  "username": "yerin123",

  "password": "password123!"

}

```

Success `200`:

```json

{

  "accessToken": "JWT_TOKEN",

  "user": {

    "id": 1,

    "username": "yerin123",

    "realName": "조예린"

  }

}

```

**---**

**## 3. Users**

> 아래 API는 JWT 인증이 필요하다.

**### 3.1 내 정보 조회**

```http

GET /users/me

```

**### 3.2 내 정보 수정**

```http

PATCH /users/me

```

**### 3.3 알림 설정 수정**

```http

PATCH /users/me/settings

```

**### 3.4 비밀번호 변경**

```http

PATCH /users/me/password

```

**### 3.5 회원탈퇴**

```http

DELETE /users/me

```

> 실제 앱 테스트 마지막 단계에서 사용하는 것을 권장한다.

**### 3.6 참새 프로필 조회**

```http

GET /users/me/sparrow

```

> JWT 인증 필요

Success `200` 예시:

```json

{

  "level": 3,

  "xp": 45,

  "xpForNextLevel": 100,

  "daysTogether": 12

}

```

- `xpForNextLevel`은 고정값 `100`이다 (`XP_PER_LEVEL`).

- `daysTogether`는 가입일(`User.createdAt`, 한국시간 기준)로부터 "함께한 지 N일째"이며, 가입 당일을 1일째로 계산한다.

- ACTIVE 상태가 아닌 사용자는 `404`가 반환된다.

**### 3.7 메인 대시보드 조회**

```http

GET /users/me/dashboard

```

Success `200` 예시:

```json

{

  "monthlyVisitCount": 8,

  "ingredientCount": 6,

  "verifiedVisitCount": 8,

  "madeFoodCount": 2,

  "topRegions": [

    {

      "regionId": 2,

      "regionName": "종로구",

      "visitCount": 6

    }

  ]

}

```

주의:

- `madeFoodCount`는 제작한 `UserFood` 행 수를 기준으로 한다.

- 같은 음식 레시피를 여러 번 제작하면 각각 별개의 제작 기록으로 집계된다.

**### 3.8 내 즐겨찾기 목록 조회**

```http

GET /users/me/favorites?page=1&limit=20

```

Success `200` 예시:

```json

{

  "items": [

    {

      "id": 6859,

      "name": "두르가",

      "categoryId": 12,

      "districtRegionId": 2,

      "roadAddress": "서울특별시 ...",

      "latitude": 37.57,

      "longitude": 126.98,

      "imageUrl": null,

      "isFavorite": true,

      "favoritedAt": "2026-09-10T00:00:00.000Z"

    }

  ],

  "page": 1,

  "limit": 20,

  "total": 1,

  "totalPages": 1

}

```

**### 3.9 내 보유 재료 목록 조회**

```http

GET /users/me/ingredients

```

**### 3.10 내가 만든 음식 목록 조회**

```http

GET /users/me/foods?page=1&limit=20

```

핵심 변경:

- 예전의 `specialIngredient`, `specialSourcePlace` 단일 필드는 사용하지 않는다.

- 현재는 `specialIngredients` 배열을 사용한다.

- 동일한 음식을 여러 번 제작해도 각각 별개의 `UserFood`로 조회된다.

예시:

```json

{

  "items": [

    {

      "id": 9,

      "foodId": 25,

      "name": "충청 한우불고기",

      "description": "음식 설명",

      "imageUrl": null,

      "illustrationUrl": null,

      "madeAt": "2026-09-11T00:00:00.000Z",

      "specialIngredients": [

        {

          "ingredientId": 19,

          "name": "한우",

          "quantity": 1,

          "rarity": "RARE",

          "sourcePlace": null

        }

      ]

    }

  ],

  "page": 1,

  "limit": 20,

  "total": 1,

  "totalPages": 1

}

```

`sourcePlace`는 현재 재료별 획득 출처를 FIFO/개별 재고 단위로 추적하지 않으므로 `null`일 수 있다.

**---**

**## 4. Regions**

**### 4.1 지역 목록 조회**

```http
GET /regions
```

Success `200` 예시:

```json
[
  {
    "id": 2,
    "parentId": 1,
    "regionType": "DISTRICT",
    "name": "종로구",
    "sgisCode": "11010"
  }
]
```

`sgisCode`: 통계청 SGIS 행정구역코드(시군구 adm_cd, 5자리 문자열). 프론트 GeoJSON 지도와 지역 매핑에 사용한다.

주의:

- 현재는 서울 25개 구(`DISTRICT`) 행만 매핑되어 있다. 그 외 지역(`PROVINCE` 등, 서울 외 확장 지역)은 `sgisCode: null`로 내려갈 수 있으므로 프론트는 null을 항상 처리해야 한다.
- `sgisCode`는 문자열이다. 앞자리 `0`이 있을 수 있으므로 숫자로 변환하지 않는다.

**### 4.2 지역별 스팟 수 조회**

```http
GET /regions/{regionId}/spot-counts
```

**### 4.3 지역별 GAP Score 조회**

```http
GET /regions/gap-scores
```

- 현재 구현되어 있는 공개 조회 API다.
- 지역 단위 GAP 데이터를 사용하는 화면에서 호출한다.
- 응답 필드 실측(2026-09-14, `RegionsService.getGapScores`): `{ run, items, total }`
  — `items[]`는 `{ regionId, parentId, regionType, regionName, sgisCode,
  gapScore, placeCount }`. 평균 GAP Score 필드명은 `averageGapScore`가 아니라
  **`gapScore`**다 — 프론트가 한동안 `averageGapScore`로 잘못 읽어 시군구별
  갭지수가 전부 0으로 표시되던 버그가 있었다(2026-09-14 수정).

**---**

**## 5. Categories**

**### 5.1 장소 카테고리 목록 조회**

```http

GET /categories

```

**---**

**## 6. Places**

**### 6.1 장소 목록 조회**

```http

GET /places

```

Query:

| 이름 | 타입 | 필수 | 기본값 | 설명 |

|---|---|:---:|---:|---|

| `regionId` | number | X | - | 지역 ID |

| `categoryId` | number | X | - | 카테고리 ID |

| `page` | number | X | `1` | 페이지 번호 |

| `limit` | number | X | `20` | 페이지당 개수, 최대 100 |

응답은 페이지네이션 객체이며 장소 목록은 `response.items`에서 읽는다.

장소 소개 필드는 `overview`를 사용한다. `ownerIntro`는 사용하지 않는다.

**### 6.2 장소 상세 조회**

> JWT 인증 필요

```http

GET /places/{id}

```

주요 응답 필드:

```json

{

  "id": 6859,

  "name": "장소명",

  "overview": "장소 소개",

  "images": [],

  "operatingHours": [],

  "isOpenNow": false,

  "operatingStatus": "BEFORE_OPEN",

  "benefits": [],

  "availableIngredients": [],

  "verification": null,

  "isFavorite": true

}

```

주의:

- `isFavorite`: 현재 로그인 사용자가 해당 장소를 즐겨찾기했는지 여부

- `overview`: 장소 소개

- `availableIngredients`는 기존 고정 장소 보상 데이터와 관련될 수 있다.

- `operatingStatus`(2026-09-16 백엔드 추가): `OPEN`/`BEFORE_OPEN`/`BREAK_TIME`/`CLOSED`/`DAY_OFF`/`UNKNOWN` 중 하나. `isOpenNow`는 하위 호환용으로 유지되며 `operatingStatus == 'OPEN'`일 때만 `true` — 화면 표시 문구는 `isOpenNow`가 아니라 `operatingStatus`를 기준으로 정한다. 랭킹(§7.2)·지도(§7.3)·추천(§7.4) 응답의 `items[]`에도 동일하게 내려온다.

- ****일반 방문 인증 보상 안내에는 `availableIngredients`를 사용하지 말고 GAP 기반 보상 정책을 사용한다.****

**### 6.3 장소 방문 여부 조회**

> JWT 인증 필요

```http

GET /places/{placeId}/visit-status

```

예시:

```json

{

  "placeId": 6859,

  "visited": true

}

```

**### 6.4 장소 트렌드 요약 조회**

```http

GET /places/{id}/trends

```

Success `200` 예시:

```json

{

  "placeId": 6859,

  "placeName": "두르가",

  "summaryText": null,

  "keywords": [],

  "periodStart": null,

  "periodEnd": null,

  "generatedAt": null,

  "contents": [],

  "searchTerm": null,

  "searchInterest": []

}

```

DB에 트렌드 데이터가 없는 경우 `null` 또는 빈 배열이 반환될 수 있다.

**### 6.5 트렌드 최초 조회 보상 지급**

> JWT 인증 필요

```http

POST /places/{id}/trends/first-view

```

첫 지급:

```json

{

  "firstView": true,

  "rewarded": true,

  "ingredient": {

    "id": 3,

    "name": "쌀",

    "quantity": 1

  }

}

```

이미 지급된 경우:

```json

{

  "firstView": false,

  "rewarded": false,

  "ingredient": null

}

```

정책:

- 활성 `BASIC` 재료 중 랜덤 1종

- 수량 `+1`

- 사용자별·장소별 최초 1회

- `transactionType = TREND_FIRST_VIEW`

**### 6.6 장소 즐겨찾기 추가**

> JWT 인증 필요

```http

POST /places/{id}/favorite

```

**### 6.7 장소 즐겨찾기 해제**

> JWT 인증 필요

```http

DELETE /places/{id}/favorite

```

**---**

**## 7. GAP Score**

**### 7.1 장소별 최신 GAP Score 조회**

```http
GET /places/{id}/gap
```

해당 장소의 최신 GAP Score를 조회한다. 최신 GAP 데이터가 없는 장소가 있을 수 있으므로 프론트는 null 가능성을 고려한다.

**### 7.2 GAP 랭킹 조회**

```http
GET /places/gap/rankings
```

Query:

| 이름 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `regionId` | number | X | 지역 필터 |
| `categoryId` | number | X | 카테고리 필터 |
| `page` | number | X | 페이지 번호 |
| `limit` | number | X | 페이지 크기 |

예시:

```http
GET /places/gap/rankings?page=1&limit=20
```

응답 구조:

```json
{
  "run": {
    "id": 1,
    "formulaVersion": "GAP_V1_PROXY",
    "dataStage": "COLD_START",
    "calculatedAt": "2026-09-10T07:43:53.136Z"
  },
  "items": [
    {
      "rank": 1,
      "placeId": 5990,
      "placeName": "롯데몰 은평점",
      "categoryId": 7,
      "regionId": 13,
      "roadAddress": "서울특별시 ...",
      "imageUrl": null,
      "verificationAvailable": true,
      "isOpenNow": false,
      "operatingStatus": "BEFORE_OPEN",
      "gapScore": 78.0307,
      "onlineScore": 0.826401,
      "offlineScore": 0.2125,
      "explanation": null
    }
  ],
  "page": 1,
  "limit": 20,
  "total": 1714,
  "totalPages": 86
}
```

`verificationAvailable`: 이 장소에 방문 인증 설정이 있고 `enabled = true`이면
`true` (2026-09-14 추가).

`isOpenNow`/`operatingStatus`: §6.2와 같은 계약(2026-09-16 추가). 화면 표시는
`operatingStatus`를 기준으로 정한다.

**### 7.3 GAP 지도 데이터 조회**

```http
GET /places/gap/map
```

Query:

| 이름 | 타입 | 필수 | 설명 |
|---|---|:---:|---|
| `regionId` | number | X | 지역 필터 |
| `categoryId` | number | X | 카테고리 필터 |

예시:

```http
GET /places/gap/map?regionId=3
```

응답 구조:

```json
{
  "run": {
    "id": 1,
    "formulaVersion": "GAP_V1_PROXY",
    "dataStage": "COLD_START",
    "calculatedAt": "2026-09-10T07:43:53.136Z"
  },
  "items": [
    {
      "placeId": 4378,
      "placeName": "남대문시장",
      "categoryId": 7,
      "regionId": 3,
      "latitude": 37.5592467,
      "longitude": 126.9776796,
      "roadAddress": "서울특별시 ...",
      "verificationAvailable": true,
      "isOpenNow": true,
      "operatingStatus": "OPEN",
      "gapScore": 54.9038,
      "onlineScore": 0.974351,
      "offlineScore": 0.875
    }
  ]
}
```

`verificationAvailable`: §7.2와 같음. `isOpenNow`/`operatingStatus`: §7.2와 같음.

**### 7.4 GAP 기반 연관 관광지 추천**

```http
GET /places/{id}/recommendations?limit=5
```

Query:

| 이름 | 타입 | 필수 | 기본값 | 설명 |
|---|---|:---:|---:|---|
| `limit` | number | X | `5` | 추천 개수, 서버에서 최대 20으로 제한 |

추천 기준:

- 기준 장소와 같은 지역(`districtRegionId`) + 같은 카테고리
- 기준 장소 자체는 제외
- 기준 장소와 같은 GAP 계산 회차 안에서 비교
- GAP Score 차이가 작은 장소부터 추천
- GAP 정보 또는 지역/카테고리 정보가 부족하면 `available: false`, `items: []`가 반환될 수 있다.

주요 응답 구조:

```json
{
  "basePlace": {
    "id": 4155,
    "name": "남대문 종합상가",
    "categoryId": 7,
    "regionId": 3,
    "gapScore": 54.9
  },
  "run": {
    "id": 1,
    "formulaVersion": "GAP_V1_PROXY",
    "dataStage": "COLD_START",
    "calculatedAt": "2026-09-10T07:43:53.136Z"
  },
  "available": true,
  "items": [
    {
      "placeId": 4378,
      "placeName": "남대문시장",
      "categoryId": 7,
      "regionId": 3,
      "roadAddress": "서울특별시 ...",
      "imageUrl": null,
      "isOpenNow": false,
      "operatingStatus": "DAY_OFF",
      "gapScore": 54.7,
      "gapDifference": 0.2,
      "onlineScore": 0.9,
      "offlineScore": 0.8
    }
  ]
}
```

`isOpenNow`/`operatingStatus`: §7.2와 같음.

**---**

**## 8. Visit Verifications**

> 아래 사용자 앱 API는 JWT 인증이 필요하다.

**### 8.1 방문 인증 세션 생성**

```http
POST /visit-verifications
```

Request Body:

```json
{
  "placeId": 4155,
  "arrivalOptionMinutes": 30
}
```

`arrivalOptionMinutes`: `10`, `30`, `60`

생성 성공 시 예시:

```json
{
  "id": 26,
  "userId": 2,
  "placeId": 4155,
  "arrivalOptionMinutes": 30,
  "expectedArrivalAt": "2026-09-12T03:00:00.000Z",
  "verificationCode": "482193",
  "issuedAt": "2026-09-12T02:30:00.000Z",
  "expiresAt": "2026-09-12T03:30:00.000Z",
  "status": "ISSUED",
  "verifiedAt": null,
  "failReason": null,
  "createdAt": "2026-09-12T02:30:00.000Z"
}
```

생성 시 서버가 검사하는 항목:

- 장소가 ACTIVE 상태인지 확인
- 해당 장소의 방문 인증 기능이 ON인지 확인
- 관리자가 설정한 인증 가능 시간 안에 `expectedArrivalAt`이 들어오는지 확인
  - `SAME_AS_OPERATING`: 매장 운영시간/특별 운영일/휴무 기준
  - `CUSTOM`: 별도 방문 인증 가능시간 기준
- 같은 사용자 + 같은 장소에 아직 유효한 `ISSUED` 세션이 있으면 중복 신청을 막음
- 같은 장소의 현재 유효 세션끼리는 6자리 코드가 겹치지 않도록 생성

중요:

- `verificationCode`는 **사용자가 직접 서버에 제출해 인증하는 코드가 아니다.**
- 앱 화면에 6자리 코드를 표시하고, 매장 관리자가 관리자 웹에서 해당 코드를 찾아 승인/반려한다.
- 인증 만료 시각은 `expectedArrivalAt + codeValidMinutes` 기준이다.

**### 8.2 방문 인증 세션/상태 조회**

```http
GET /visit-verifications/{verificationId}
```

- 본인의 인증 세션만 조회 가능하다.
- `ISSUED` 상태에서 `expiresAt`을 지난 세션은 조회 과정에서 `EXPIRED`로 반영될 수 있다.
- 앱은 승인 대기 화면에서 이 API를 다시 호출해 상태를 갱신하면 된다.

상태 의미:

| status | 앱 표시 의미 |
|---|---|
| `ISSUED` | 방문 예정 / 관리자 승인 대기 |
| `VERIFIED` | 인증 완료 |
| `EXPIRED` | 인증 시간 만료 |
| `FAILED` | 관리자 반려 |
| `CANCELLED` | 사용자가 신청 취소 |

`VERIFIED` 상태 응답 예시 (2026-09-13 반영, `reward` 필드 추가):

```json
{
  "id": 27,
  "userId": 2,
  "placeId": 4155,
  "arrivalOptionMinutes": 30,
  "expectedArrivalAt": "2026-09-12T15:36:38.335Z",
  "verificationCode": "248908",
  "issuedAt": "2026-09-12T15:06:38.335Z",
  "expiresAt": "2026-09-12T16:06:38.335Z",
  "status": "VERIFIED",
  "verifiedAt": "2026-09-12T15:07:35.964Z",
  "failReason": null,
  "createdAt": "2026-09-12T15:06:38.724Z",
  "reward": {
    "ingredientId": 9,
    "name": "김치",
    "quantity": 2,
    "rarity": "COMMON"
  }
}
```

`reward` 타입: `{ ingredientId: number; name: string; quantity: number; rarity: string | null } | null`. `status`가 `VERIFIED`가 아니면 `reward`는 항상 `null`이다. 승인 즉시 지급된 재료를 이 필드로 바로 확인할 수 있으므로, "방문 인증 보상 획득" 화면은 `GET /places/{id}/trends/first-view`처럼 이 필드를 그대로 사용하면 되고 별도 폴링/추론이 필요 없다.

**### 8.3 방문 인증 신청 취소**

```http
POST /visit-verifications/{verificationId}/cancel
```

Request Body 없음.

- 본인의 `ISSUED` 상태 인증만 취소할 수 있다.
- 성공 시 `status = CANCELLED`.
- 이미 `VERIFIED`, `FAILED`, `CANCELLED` 등으로 처리된 인증은 취소할 수 없다.
- 이미 만료된 인증은 `EXPIRED`로 처리되고 취소되지 않는다.

**### 8.4 관리자 승인/반려와 앱 처리 방식**

사용자 앱에는 더 이상 아래 self-verify API가 없다.

```text
POST /visit-verifications/{verificationId}/verify   ← 제거됨 / 호출 금지
```

최종 처리 흐름:

```text
사용자 앱 POST /visit-verifications
→ 서버가 ISSUED 세션 + 6자리 코드 발급
→ 사용자가 매장에 코드 제시
→ 매장 관리자가 관리자 웹에서 승인 또는 반려
→ 앱이 GET /visit-verifications/{verificationId}로 최신 상태 확인
```

관리자 승인 시 서버 내부에서:

- `ISSUED → VERIFIED`
- `verifiedAt` 기록
- GAP percentile 기반 랜덤 드롭 실행
- 선택된 재료 1종을 `+2`
- `UserIngredient` 수량 반영
- `IngredientTransaction.transactionType = VISIT_REWARD`
- `quantityChange = +2`
- `visitVerificationId`를 거래 이력에 연결
- 동일 방문 인증에 대한 보상 중복 지급 방지

관리자 반려 시:

- `ISSUED → FAILED`
- `failReason`이 저장될 수 있음
- 방문 재료 보상 없음

**### 8.5 GAP 보상 정책**

| 정책 | GAP percentile |
|---|---|
| `NO_GAP` | 최신 GAP 없음 또는 percentile `null` |
| `GAP_LOW` | `[0, 0.5)` |
| `GAP_MID` | `[0.5, 0.8)` |
| `GAP_HIGH` | `[0.8, 0.95)` |
| `GAP_TOP` | `[0.95, 1]` |

현재 DB 기본 확률:

| 정책 | COMMON | UNCOMMON | RARE | LEGENDARY |
|---|---:|---:|---:|---:|
| `NO_GAP` | 0.80 | 0.18 | 0.02 | 0.00 |
| `GAP_LOW` | 0.70 | 0.25 | 0.05 | 0.00 |
| `GAP_MID` | 0.55 | 0.30 | 0.14 | 0.01 |
| `GAP_HIGH` | 0.35 | 0.40 | 0.22 | 0.03 |
| `GAP_TOP` | 0.20 | 0.35 | 0.35 | 0.10 |

중요:

- 확률은 코드 하드코딩이 아니라 DB의 `ingredient_drop_policies`를 기준으로 동작한다.
- 프론트에서 확률을 직접 계산하거나 보상 결과를 예측하지 않는다.
- COMMON / UNCOMMON / RARE는 활성 `BASIC` 재료 중 해당 rarity에서 랜덤 선택된다.
- LEGENDARY는 장소 지역을 FOOD_REGION으로 매핑해 해당 지역의 활성 `REGIONAL + LEGENDARY` 재료에서 선택된다.
- 일반 방문 인증 보상은 기존 `EVERY_VISIT` / `place_ingredient_rewards` 고정 보상 방식이 아니다.

**---**

**## 9. Ingredients**

> JWT 인증 필요

**### 9.1 재료 상세 조회**

```http

GET /ingredients/{ingredientId}

```

핵심 응답 정보:

- 재료 기본 정보

- 현재 사용자 보유 수량

- `obtained`

- 해당 재료를 사용하는 음식 목록 `usedFoods`

- GAP 방문 보상 획득 방식 `acquisition`

- GAP 정책별 드롭 확률

- LEGENDARY 재료인 경우 지역 정보

응답 구조 예시:

```json

{

  "id": 19,

  "name": "한우",

  "ingredientType": "BASIC",

  "quantity": 1,

  "obtained": true,

  "rarity": "RARE",

  "regionId": null,

  "usedFoods": [],

  "acquisitionPlaces": [],

  "acquisition": {

    "type": "VISIT_REWARD",

    "method": "GAP_BASED_RANDOM_DROP",

    "description": "방문 인증 시 GAP 구간별 확률에 따라 획득할 수 있습니다.",

    "region": null,

    "dropProbabilities": [

      { "policyCode": "NO_GAP", "probability": 0.02 },

      { "policyCode": "GAP_LOW", "probability": 0.05 },

      { "policyCode": "GAP_MID", "probability": 0.14 },

      { "policyCode": "GAP_HIGH", "probability": 0.22 },

      { "policyCode": "GAP_TOP", "probability": 0.35 }

    ]

  }

}

```

LEGENDARY 재료는 `acquisition.region`에 FOOD_REGION 정보가 포함될 수 있다.

`acquisitionPlaces`는 기존 프론트 호환을 위해 남아 있지만 일반 방문 보상 획득처를 의미하지 않는다. 현재 정상적인 획득 방식 표시는 `acquisition`을 사용한다.

**---**

**## 10. Foods**

> 아래 API는 JWT 인증이 필요하다.

**### 10.1 음식 목록 조회**

```http

GET /foods

```

사용자의 현재 보유 재료와 레시피 필요 수량을 비교해 `canMake`를 계산한다.

**### 10.2 음식 상세 조회**

```http

GET /foods/{id}

```

음식 기본 정보, 레시피, 사용자 현재 보유량, `canMake`를 반환한다.

**### 10.3 음식 만들기**

```http

POST /foods/{id}/make

```

Request Body 없음.

처리 내용:

1\. 활성 음식 및 레시피 조회

2\. 재료 보유량 검사

3\. `UserFood` 생성

4\. `UserIngredient.quantity` 차감

5\. 재료별 `IngredientTransaction` 생성 (`transactionType = FOOD_USE`)

6\. 사용한 재료 중 RARE / LEGENDARY는 `UserFoodSpecialIngredient`로 기록

7\. 전부 하나의 DB 트랜잭션으로 처리

성공 `200` 예시:

```json
{
  "success": true,
  "userFood": {
    "id": 1,
    "foodId": 1,
    "name": "비빔밥",
    "madeAt": "2026-09-10T00:00:00.000Z",
    "illustrationUrl": null
  },
  "usedIngredients": [
    {
      "ingredientId": 1,
      "name": "쌀",
      "quantity": 2,
      "rarity": "COMMON"
    }
  ]
}
```

재료 부족 시 `400`과 `missingIngredients`가 반환된다:

```json
{
  "statusCode": 400,
  "message": "보유한 재료가 부족합니다.",
  "missingIngredients": [
    {
      "ingredientId": 2,
      "name": "대파",
      "requiredQuantity": 1,
      "ownedQuantity": 0,
      "shortage": 1
    }
  ]
}
```

음식/레시피가 없으면 각각 `404`(`음식을 찾을 수 없습니다.`), `400`(`등록된 레시피가 없습니다.`)이 반환된다.

**---**

**## 11. Food Histories**

> JWT 인증 필요

**### 11.1 제작 음식 상세 히스토리 조회**

```http

GET /food-histories/{historyId}

```

`historyId`는 `UserFood.id`다.

핵심 응답:

- 제작한 음식 정보

- `specialIngredients`

- `normalIngredients`

예시 구조:

```json

{

  "food": {

    "id": 25,

    "name": "충청 한우불고기"

  },

  "specialIngredients": [

    {

      "ingredientId": 19,

      "name": "한우",

      "quantity": 1,

      "rarity": "RARE",

      "obtainedPlace": null

    }

  ],

  "normalIngredients": [

    {

      "ingredientId": 5,

      "name": "대파",

      "quantity": 1,

      "rarity": "COMMON"

    }

  ]

}

```

`obtainedPlace`는 현재 `null`일 수 있다.

**---**

**## 12. Records / 발자국**

> 아래 API는 JWT 인증이 필요하다.

**### 12.1 발자국 작성**

```http

POST /records

```

Request Body 예시:

```json

{

  "placeId": 5990,

  "userFoodId": 9,

  "visitVerificationId": 12,

  "date": "2026-09-11",

  "title": "오늘의 여행 기록",

  "body": "사람이 많지 않아서 여유롭게 둘러볼 수 있었다.",

  "imageUrls": [

    "https://example.com/test-record-1.jpg"

  ]

}

```

검증 규칙:

- `placeId`가 있으면 실제 ACTIVE 장소여야 한다.

- `manualPlaceName`(string | null, 2026-09-15 추가): 직접 입력한 장소명. 앞뒤
  공백 제거 후 최대 100자. `placeId`와 동시에 값을 가질 수 없다. 둘 다 없으면
  장소 없이 저장된다. 장소 마스터에 새 장소를 생성하거나 방문 인증으로
  인정하는 용도가 아니다.

- `userFoodId`가 있으면 현재 로그인 사용자가 만든 음식이어야 한다.

- `visitVerificationId`가 있으면 현재 로그인 사용자의 `VERIFIED` 인증이어야 한다.

- `visitVerificationId`만 보내고 `placeId`를 생략하면 인증의 장소가 자동 연결된다.

- `placeId`와 `visitVerificationId`를 둘 다 보내면 두 장소가 일치해야 한다.

- `date`는 `YYYY-MM-DD`, KST 기준이다.

수동 장소명으로 작성하는 요청 예시:

```json

{

  "date": "2026-09-14",

  "manualPlaceName": "집 근처 작은 공원",

  "title": "저녁 산책",

  "body": "조용히 산책하며 하루를 마무리했어요."

}

```

Success 구조:

```json

{

  "recordId": 1,

  "message": "발자국이 기록되었습니다.",

  "record": {

    "id": 1,

    "date": "2026-09-11",

    "place": {

      "id": 5990,

      "name": "장소명"

    },

    "manualPlaceName": null,

    "food": {

      "userFoodId": 9,

      "foodId": 25,

      "name": "충청 한우불고기"

    },

    "title": "오늘의 여행 기록",

    "body": "사람이 많지 않아서 여유롭게 둘러볼 수 있었다.",

    "images": [

      {

        "id": 1,

        "imageUrl": "https://example.com/test-record-1.jpg",

        "displayOrder": 1

      }

    ],

    "createdAt": "2026-09-11T00:00:00.000Z"

  }

}

```

**### 12.2 내 발자국 전체 조회**

```http

GET /records?page=1&limit=20

```

응답은 `records`, `page`, `limit`, `total`, `totalPages`를 반환한다. 목록에는 `PUBLISHED` 상태 기록만 노출된다. 각 기록의 `place`는 그대로 유지되고, `manualPlaceName`(2026-09-15 추가)이 나란히 반환된다. 수동 장소명 기록 예시(다른 필드는 생략):

```json

{

  "id": 123,

  "place": null,

  "manualPlaceName": "집 근처 작은 공원"

}

```

**### 12.3 발자국 달력 조회**

```http

GET /records/calendar?year=2026&month=9

```

응답 예시:

```json

{

  "year": 2026,

  "month": 9,

  "recordDays": [

    {

      "date": "2026-09-11",

      "recordCount": 2

    }

  ]

}

```

**### 12.4 발자국 상세 조회**

```http

GET /records/{recordId}

```

목록과 동일하게 `place`/`manualPlaceName`을 나란히 반환한다.

**### 12.5 발자국 수정**

```http

PATCH /records/{recordId}

```

수정 가능한 필드는 Swagger의 `UpdateRecordDto`를 기준으로 전달한다.

`placeId`/`manualPlaceName`(2026-09-15 추가) 처리 규칙:

- 필드를 생략하면 기존 값을 유지하고, 명시적 `null`을 보내면 해당 값을 해제한다.
- `placeId`와 `manualPlaceName`은 동시에 값을 가질 수 없다. 변경 후에도 이 조건을 다시 검증한다.
- 두 필드의 변경은 한 번에 반영한다.
- 기존 `visitVerificationId`가 연결된 기록의 장소를 변경·해제하면 그 인증 연결도 해제된다(방문 인증 기록 자체는 유지됨).

요청 예시(장소 연결을 모두 해제):

```json

{

  "placeId": null,

  "manualPlaceName": null

}

```

**### 12.6 발자국 삭제**

```http

DELETE /records/{recordId}

```

삭제는 실제 DB 행을 물리 삭제하는 방식이 아니라 사용자 목록/상세에서 제외하는 soft delete 방식으로 처리한다.

**### 12.7 발자국 사진 업로드 (2026-09-15 추가)**

> JWT 인증 필요

```http

POST /uploads/images
Content-Type: multipart/form-data

```

`file` 필드에 이미지 하나를 첨부한다(한 번에 1개). JPG/PNG/WEBP만 허용, 파일당 최대 10MB. 실제 저장은 Cloudinary(`goyohaeng/records` 폴더)로 이루어진다.

성공 응답:

```json

{

  "imageUrl": "https://res.cloudinary.com/example/image/upload/v1234567890/goyohaeng/records/example.jpg"

}

```

- 파일이 없거나 지원하지 않는 형식이면 `400`.
- 인증이 없으면 `401`.
- 반환된 `imageUrl`을 `POST/PATCH /records`의 `imageUrls` 배열에 담아 기록에 연결한다. 이 API는 사진을 업로드만 하며, 기록에 반영하려면 별도로 기록 저장/수정 요청을 보내야 한다.

**---**

**## 13. Analytics**

> JWT 인증 필요

**### 13.1 사용자 행동 이벤트 기록**

```http

POST /analytics/events

```

Request body:

```json

{

  "placeId": 6859,

  "eventType": "PLACE_DETAIL_VIEW"

}

```

`eventType`은 다음 중 하나다:

- `PLACE_DETAIL_VIEW` — 장소 상세 페이지 진입

- `VISIT_AUTH_PAGE_ENTER` — 방문 인증 페이지 진입

Success `201` 예시:

```json

{

  "id": 1,

  "placeId": 6859,

  "eventType": "PLACE_DETAIL_VIEW",

  "occurredAt": "2026-09-13T00:00:00.000Z"

}

```

`placeId`는 ACTIVE 상태의 실제 장소여야 하며, 존재하지 않으면 `404`가 반환된다.

**---**

**## 14. 프론트 연동 핵심 주의사항**

1. `/places`는 페이지네이션 응답이므로 장소 목록은 `response.items`에서 읽는다.
2. 장소 소개 필드는 `ownerIntro`가 아니라 `overview`다.
3. `GET /places/{id}`는 JWT 인증이 필요하며 `isFavorite`을 반환한다.
4. 즐겨찾기 추가/해제는 `POST /places/{id}/favorite`, `DELETE /places/{id}/favorite`을 사용한다.
5. 장소 방문 여부는 `GET /places/{placeId}/visit-status`에서 확인한다.
6. `GET /places/{id}/recommendations`는 현재 구현되어 있으며, 같은 지역 + 같은 카테고리에서 GAP Score가 비슷한 장소를 추천한다.
7. `GET /regions/gap-scores`도 현재 구현되어 있다.
8. 트렌드 최초 조회 보상은 BASIC 랜덤 1개이며 사용자별·장소별 최초 1회다.
9. 방문 인증 앱 흐름은 **신청 → 6자리 코드 표시 → 관리자 승인/반려 → 상태 조회**다. 사용자가 코드를 서버에 제출해 직접 인증하지 않는다.
10. `/visit-verifications/{id}/verify`는 제거되었으므로 호출하지 않는다.
11. 사용자는 `POST /visit-verifications/{id}/cancel`로 대기 중 인증을 취소할 수 있다.
12. 방문 인증 신청은 장소 ON/OFF 및 `SAME_AS_OPERATING` / `CUSTOM` 인증 가능시간의 영향을 받는다.
13. 방문 인증 보상은 GAP percentile → DB drop policy → rarity → 랜덤 재료 방식이며 최종 수량은 2개다.
14. 방문 인증 보상 확률은 프론트에서 하드코딩하지 않는다. 재료 상세의 `acquisition.dropProbabilities`를 사용한다.
15. `availableIngredients`와 `acquisitionPlaces`는 일반 GAP 방문 보상을 표현하는 데이터로 사용하지 않는다.
16. 음식 목록/상세의 `canMake`, `ownedQuantity`, `enough`는 로그인 사용자의 현재 보유량 기준이다.
17. 음식 제작 시 동일 음식도 여러 번 제작할 수 있고 각 제작은 별개의 `UserFood`다.
18. 음식 제작에서 사용된 RARE / LEGENDARY 재료는 `specialIngredients` 배열로 확인한다.
19. `specialIngredients[].sourcePlace` 또는 음식 히스토리의 `obtainedPlace`는 현재 `null`일 수 있다.
20. Records의 `userFoodId`는 `foodId`가 아니라 **제작 기록인 `UserFood.id`**다.
21. Records의 `visitVerificationId`는 본인의 `VERIFIED` 방문 인증만 사용할 수 있다.
22. GAP 데이터가 없는 장소가 존재할 수 있으며 방문 보상은 이 경우 `NO_GAP` 정책으로 처리된다.
23. 트렌드 데이터가 없는 장소는 `summaryText`, `searchTerm` 등이 `null`, 목록 필드는 빈 배열일 수 있다.
24. `/external-api/*`와 `/business/*`는 사용자 Flutter 앱에서 직접 호출하지 않는다.
25. `GET /regions` 응답에 `sgisCode`(SGIS 행정구역코드, 문자열)가 추가됐다. 현재 서울 25개 구만 값이 있고 나머지는 `null`일 수 있다.

**---**

**## 15. 현재 구현 API 요약**

| Method | Endpoint | 인증 | 설명 |
|---|---|:---:|---|
| GET | `/auth/check-username` | X | 아이디 중복 확인 |
| POST | `/auth/signup` | X | 회원가입 |
| POST | `/auth/login` | X | 로그인 |
| GET | `/users/me` | O | 내 정보 조회 |
| PATCH | `/users/me` | O | 내 정보 수정 |
| PATCH | `/users/me/settings` | O | 알림 설정 수정 |
| PATCH | `/users/me/password` | O | 비밀번호 변경 |
| DELETE | `/users/me` | O | 회원탈퇴 |
| GET | `/users/me/sparrow` | O | 참새 레벨/경험치/함께한 일수 조회 |
| GET | `/users/me/dashboard` | O | 메인 대시보드 통계 |
| GET | `/users/me/favorites` | O | 내 즐겨찾기 목록 |
| GET | `/users/me/ingredients` | O | 내 보유 재료 목록 |
| GET | `/users/me/foods` | O | 내가 만든 음식 목록 |
| GET | `/regions` | X | 지역 목록 조회 |
| GET | `/regions/gap-scores` | X | 지역별 GAP Score 조회 |
| GET | `/regions/{regionId}/spot-counts` | X | 지역별 스팟 수 조회 |
| GET | `/categories` | X | 장소 카테고리 목록 |
| GET | `/places` | X | 장소 목록 / 필터 / 페이지네이션 |
| GET | `/places/{id}` | O | 장소 상세 + 즐겨찾기 여부 |
| GET | `/places/{placeId}/visit-status` | O | 장소 방문 여부 |
| GET | `/places/{id}/trends` | X | 장소 트렌드 요약 |
| POST | `/places/{id}/trends/first-view` | O | 트렌드 최초 조회 보상 |
| POST | `/places/{id}/favorite` | O | 즐겨찾기 추가 |
| DELETE | `/places/{id}/favorite` | O | 즐겨찾기 해제 |
| GET | `/places/{id}/gap` | X | 장소 최신 GAP Score |
| GET | `/places/gap/rankings` | X | GAP 장소 랭킹 |
| GET | `/places/gap/map` | X | GAP 지도 데이터 |
| GET | `/places/{id}/recommendations` | X | GAP 기반 연관 관광지 추천 |
| POST | `/visit-verifications` | O | 방문 인증 세션 생성 + 6자리 코드 발급 |
| GET | `/visit-verifications/{verificationId}` | O | 방문 인증 상태 조회 |
| POST | `/visit-verifications/{verificationId}/cancel` | O | 대기 중 방문 인증 신청 취소 |
| GET | `/ingredients/{ingredientId}` | O | 재료 상세 + GAP 획득 정보 |
| GET | `/foods` | O | 음식 목록 + 제작 가능 여부 |
| GET | `/foods/{id}` | O | 음식 상세 + 보유 재료 비교 |
| POST | `/foods/{id}/make` | O | 음식 제작 + 재료 차감 |
| GET | `/food-histories/{historyId}` | O | 제작 음식 재료 히스토리 |
| POST | `/records` | O | 발자국 작성 |
| GET | `/records` | O | 내 발자국 목록 |
| GET | `/records/calendar` | O | 발자국 달력 |
| GET | `/records/{recordId}` | O | 발자국 상세 |
| PATCH | `/records/{recordId}` | O | 발자국 수정 |
| DELETE | `/records/{recordId}` | O | 발자국 soft delete |
| POST | `/analytics/events` | O | 사용자 행동 이벤트 기록 |

> 삭제된 API: `POST /visit-verifications/{verificationId}/verify` — 사용자 self-verify 방식 폐기.

**---**

**## 16. 프론트에서 호출하지 않을 기능 / 현재 제약**

**### 외부 데이터 적재**

```text
/external-api/*
```

사용자 Flutter 앱에서 호출하지 않는다.

**### 관리자/사업자 웹 API**

```text
/business/*
```

사용자 앱에서 직접 호출하지 않는다. 방문 인증 최종 승인/반려도 관리자 웹에서 처리한다.

**### 재료 출처 추적**

현재 한 사용자가 보유한 동일 재료 각각의 획득 장소를 FIFO 단위로 추적하지 않는다. 따라서 음식 특별 재료의 `sourcePlace` / `obtainedPlace`는 `null`일 수 있다.

**---**

**## 17. 2026-09-12 최종 변경점**

기존 2026-09-11 명세에서 다음을 수정했다.

- 방문 인증 방식 변경
  - 사용자 self-verify API `POST /visit-verifications/{id}/verify` 제거
  - 6자리 코드는 관리자에게 보여주는 방문 세션 식별 코드로 변경
  - 최종 승인/반려는 관리자 웹에서 처리
  - 앱은 `GET /visit-verifications/{id}`로 `ISSUED / VERIFIED / EXPIRED / FAILED / CANCELLED` 상태 확인
- 사용자 방문 인증 취소 API 추가
  - `POST /visit-verifications/{id}/cancel`
- 방문 인증 신청 시 서버 검증 강화
  - 방문 인증 ON/OFF
  - 운영시간 또는 CUSTOM 인증 가능시간 검사
  - 같은 사용자/장소의 유효한 중복 `ISSUED` 세션 방지
  - 같은 장소의 유효 세션 간 6자리 코드 중복 방지
- 관리자 승인 시 기존 GAP 기반 보상 로직을 그대로 실행
  - 선택된 재료 1종 `+2`
  - `VISIT_REWARD` 거래 이력과 `visitVerificationId` 연결
- 실제 구현되어 있었지만 이전 최종 문서에서 미구현으로 잘못 표기된 API 수정
  - `GET /places/{id}/recommendations`
  - `GET /regions/gap-scores`
- 장소 소개 필드는 계속 `overview` 사용
- 관리자 웹 전용 `/business/*` API는 사용자 앱 명세 범위에서 제외

**---**

**## 18. 2026-09-13 변경점**

- `GET /regions` 응답에 `sgisCode` 필드 추가 (SGIS 행정구역코드, 문자열)
  - 현재 서울 25개 구(`DISTRICT`)만 매핑 완료, 그 외 지역은 `null`
  - 커밋: `2b471cd feat: 지역 SGIS 코드 응답 추가`

**---**

**## 19. 백엔드 완료 상태**

```text
Auth / Users                               완료
Regions / Categories                       완료
Places                                     완료
Favorites                                  완료
Trend + 최초 조회 보상                     완료
GAP 장소 상세 / 지역 / 랭킹 / 지도          완료
GAP 기반 연관 관광지 추천                   완료
Visit Verification 신청 / 조회 / 취소       완료
관리자 승인형 방문 인증 흐름                 완료
GAP percentile 기반 방문 인증 재료 보상     완료
Ingredients 상세 + GAP 획득 정보             완료
Foods / Food Histories                     완료
특별 재료 기록                              완료
Records / 발자국 CRUD                       완료
주요 사용자 API 회귀 테스트                 완료
외부 데이터 적재 API                        앱 직접 호출 대상 아님
관리자/사업자 API                           앱 직접 호출 대상 아님
```
