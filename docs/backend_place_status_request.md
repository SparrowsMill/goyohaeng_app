# 장소 카드 상태 연동 — 백엔드 전달 요청

> **2번(영업 상태) 항목은 2026-09-16 `operatingStatus` 필드 배포로 RESOLVED.**
> 상세 내용은 [backend_requirements_pending.md](backend_requirements_pending.md)
> 11번 항목과 [api_spec.md](api_spec.md) §6.2/§7.2~§7.4 참고. 이 문서는 최초
> 요청 당시 기록으로 남겨둔다.

확인일: 2026-09-14

확인 자료: [배포 Swagger](https://goyohaengappbackend-production.up.railway.app/api-docs), [OpenAPI JSON](https://goyohaengappbackend-production.up.railway.app/api-docs-json) (`Goyohaeng API`, version `1.0`). 아래 경로는 공통 접두사 `/api/v1`을 생략했습니다.

## 요청 배경

사용자 앱의 장소 카드에 방문 인증 가능 여부와 현재 영업 상태를 표시하려 합니다. 배포 API를 직접 확인했을 때 지도 1,714곳 중 `verificationAvailable: true`는 남대문 종합상가(`placeId: 4155`) 1곳이었고, 지도 응답에는 `isOpenNow`가 없었습니다. 이는 당시 실응답 관찰이며 Swagger에 이 필드들이 정의되어 있다는 뜻은 아닙니다.

실제 응답 계약을 프론트가 확인할 수 있도록 Swagger를 보완하고, 목록에 영업 상태를 추가해 주세요. 기존 방문 인증 운영 대상의 설정 데이터도 함께 점검 부탁드립니다.

## 1. Swagger에서 확인한 현재 API

| API | 현재 Swagger에서 확인 가능한 내용 | 부족한 내용 |
| --- | --- | --- |
| `GET /places/gap/rankings` | `regionId`, `categoryId`, `page`, `limit` 쿼리, 200 응답 설명 | 성공 응답의 JSON 스키마·예시, 쿼리 범위·기본값 |
| `GET /places/gap/map` | `regionId`, `categoryId` 쿼리, 200 응답 설명 | 장소별 필드 스키마·예시 |
| `GET /places/{id}/recommendations` | `id`, `limit`(예시 5), 200/404 응답 설명 | 성공 응답 스키마·예시 |
| `GET /places/{id}` | Bearer 인증, 200/401/404 응답 설명 | 상세 영업·인증 상태 필드와 null 규칙 |
| `GET/PATCH /business/visit-verifications/intake-setting` | Bearer 인증, 인증 접수 설정 조회·ON/OFF 변경 | PATCH DTO 속성 및 성공 응답 스키마 |
| `GET/PUT /business/visit-verifications/verification-hours` | Bearer 인증, 인증 가능시간 조회·설정 | PUT DTO 속성 및 성공 응답 스키마 |
| `GET/PUT /business/place/operating-hours` | Bearer 인증, 운영시간·휴게시간 조회·설정 | PUT DTO 속성 및 성공 응답 스키마 |
| `GET/PUT /business/place/special-hours`, `DELETE /business/place/special-hours/{date}` | 특정 날짜 일정 관련 경로 존재 | 요청·응답 계약의 구체화 필요 |
| `POST /business/place/temporary-closures` | 임시 휴무 등록 경로 존재 | 요청 DTO 속성 명세 필요 |
| `POST /visit-verifications` | `placeId`와 `arrivalOptionMinutes` 필수, 도착 옵션 10/30/60, Bearer 인증, 201/400/401/404 설명 | 성공 응답 스키마와 사유별 오류 코드 |
| `POST /analytics/events` | Bearer 인증, 요청 DTO 참조, 401 설명 | 요청 DTO 속성, 성공 응답·상태 코드 |
| `GET /business/analytics/page-funnel` | Bearer 인증, 200 설명 | 결과 필드·집계 정의 |

특히 OpenAPI의 `UpdateBusinessVerificationSettingDto`, `UpdateBusinessVerificationHoursDto`, `UpdateBusinessOperatingHoursDto`, `UpdateBusinessSpecialHourDto`, `CreateBusinessTemporaryClosureDto`, `CreateAnalyticsEventDto`는 현재 `properties: {}`입니다. API가 빈 본문을 받는다는 뜻으로 해석할 수 없으며, Swagger만으로는 실제 요청 본문을 구성할 수 없습니다.

## 2. 우선 요청: 목록에 영업 상태 추가

적용 대상:

- `GET /places/gap/rankings`의 `items[]`
- `GET /places/gap/map`의 `items[]`
- `GET /places/{id}/recommendations`의 `items[]`

세 목록에 다음 계약을 통일해 주세요. 기존 응답 구조와 필드는 유지해 주세요.

| 필드 | 제안 타입 | 의미 |
| --- | --- | --- |
| `verificationAvailable` | `boolean` | 인증 설정이 존재하고 활성화되어 있으면 true. 설정 없음/비활성화는 false |
| `isOpenNow` | `boolean \| null` | 현재 영업 중 true, 알려진 일정상 영업하지 않음 false, 정보 부족 null |

`verificationAvailable`은 지도·랭킹 실응답에 이미 있으므로 유지하고, 추천 응답에도 같은 의미로 제공해 주세요. `isOpenNow`는 새로 요청하는 목록 필드입니다.

제안 예시(설명을 위해 기존 다른 필드는 생략했으며 실제 장소 상태가 아님):

```json
{
  "items": [
    { "placeId": 10001, "verificationAvailable": true, "isOpenNow": true },
    { "placeId": 10002, "verificationAvailable": true, "isOpenNow": false },
    { "placeId": 10003, "verificationAvailable": false, "isOpenNow": null }
  ]
}
```

계산 및 데이터 규칙:

- 기준 시간대는 `Asia/Seoul`. 같은 요청 안의 장소는 같은 기준 시각으로 계산해 주세요.
- 상세 `GET /places/{id}`와 목록에서 동일한 계산 함수를 사용해 주세요. 상세의 `isOpenNow`도 정보 부족을 null로 표현하도록 계약을 맞춰 주세요.
- 운영시간이 없거나 불완전한 경우 false로 간주하지 말고 null을 반환해 주세요. 명시적 휴무·영업 종료·브레이크타임은 false입니다.
- 특정 날짜 예외 일정, 임시 휴무, 정규 시간의 우선순위와 충돌 정책을 문서화해 주세요. 제안 우선순위는 임시 휴무 → 날짜별 예외 일정 → 주간 일정입니다.
- 야간 영업, 전날 개점 후 다음 날 폐점하는 경우, 자정, 브레이크타임, 24시간 영업의 표현과 경계 규칙을 정의해 주세요. 24시간 영업을 단순히 시간 누락으로 판단하지 않아야 합니다.
- 점수 데이터의 GAP run 시점과 영업 상태 계산 시점을 분리해 주세요. 영업 상태를 과거 GAP 결과에 고정하지 말아 주세요.
- 장소별 상세 API 호출이나 개별 DB 조회를 반복하지 말고 필요한 일정 데이터를 관계 조회/일괄 조회해 주세요.
- 응답 캐시가 있다면 운영시간 및 인증 설정 변경 후 반영 지연의 상한을 명시해 주세요.

이 boolean 계약만으로 휴무와 영업 종료를 구별하지는 않습니다. 상세 사유 표시는 아래 선택 확장에서 다룹니다.

## 3. 기존 가맹점 설정 API 명세 보완 및 데이터 점검

새 설정 API 신설 대신, 현재 Swagger에 있는 설정 API를 사용할 수 있게 명세를 완성해 주세요.

- 접수 ON/OFF: `PATCH /business/visit-verifications/intake-setting`의 실제 필드명·타입·필수 여부·성공 응답을 공개해 주세요. 설정이 없는 장소에서 최초 호출 시 생성하는지, 별도 사전 등록이 필요한지도 설명해 주세요.
- 인증 가능시간: `PUT /business/visit-verifications/verification-hours`에 모드(`SAME_AS_OPERATING` / `CUSTOM`)의 실제 전달 위치, 시간 배열 구조, 요일 값, 시간 형식, 휴무·휴게시간 지원 여부를 명시해 주세요. 모드 값은 앱의 기존 API 문서 기준이며 현재 빈 Swagger DTO로는 확인할 수 없습니다.
- 운영시간: `PUT /business/place/operating-hours`의 주간 일정 구조, 필수 요일 범위, 누락 요일·빈 배열 의미, 24시간·야간 영업의 표현을 공개해 주세요.
- 날짜별 예외 일정과 임시 휴무: 날짜 형식, 기간 포함 범위, 중복 일정 처리, 삭제·해제 방법을 명시해 주세요.
- PUT이 전체 교체인지 부분 변경인지, 검증 실패 시 전체 롤백인지 명시해 주세요.
- 각 설정 API의 사용 권한, 가맹점 승인 필요 여부, 토큰에서 대상 장소를 결정하는 방식과 401/403 응답을 명시해 주세요. Swagger의 Bearer 표기만으로 세부 권한은 확인할 수 없습니다.
- 실제 인증 운영 대상 목록과 DB 설정을 대조하고, 누락된 대상만 설정해 주세요. 모든 장소를 일괄 활성화하는 요청은 아닙니다.
- 운영시간 미등록 장소 수와 데이터 보완 범위를 공유해 주세요. 데이터가 없으면 새 필드를 추가해도 `isOpenNow: null`인 상태는 유지됩니다.

## 4. 선택 확장: 인증 활성화와 현재 신청 가능 여부 분리

현재 카드는 기능이 활성화되면 “방문 인증 가능”을 표시합니다. 하지만 `POST /visit-verifications`의 Swagger는 시간 외 요청 등도 400으로 설명하므로, 활성화되어 있어도 지금 신청은 거절될 수 있습니다.

당장 필수인 것은 2번의 두 필드이며, 현재 신청 가능 사유까지 UI에 보여줄 계획이라면 상세 응답에 다음 필드를 별도로 검토해 주세요. 기존 `verificationAvailable`의 의미를 바꾸지는 말아 주세요.

```json
{
  "verificationAvailable": true,
  "verificationAcceptingNow": false,
  "verificationUnavailableReason": "OUTSIDE_VERIFICATION_HOURS"
}
```

위는 제안 필드입니다. `verificationAcceptingNow: boolean | null`은 장소의 접수 ON/OFF와 인증 시간 정책만 판정하고, 사용자별 중복 인증·자격 조건까지 신청 성공을 보장하는 값으로 쓰지 않습니다. 사유 enum 예시는 `DISABLED`, `NOT_CONFIGURED`, `OUTSIDE_VERIFICATION_HOURS`, `HOURS_UNKNOWN`이며 실제 정책에 맞게 확정해야 합니다. 현재 영업 여부로 단순 대체하지 않아야 합니다(`CUSTOM` 인증 시간 고려).

신청 시에는 서버가 최종 검증하며, 400 응답에 프론트가 분기할 수 있는 안정적인 `code`와 메시지를 제공해 주세요. 현재 Swagger에 묶여 있는 인증 불가·시간 외·이미 인증 완료 등 실제 조건을 구별하고, 기존 응답과 호환되게 문서화해 주세요.

## 5. 선택 확장: 방문 인증 가능 필터를 서버에서 처리

현재 Swagger의 지도·랭킹 쿼리에는 `verificationAvailable` 필터가 없습니다. 프론트는 받아온 장소만 필터링하므로 페이지네이션 목록을 일부만 읽으면 가능한 장소를 놓칠 수 있습니다.

필요 시 지도·랭킹에 `verificationAvailable=true|false` 쿼리를 추가해 주세요. 생략하면 전체, true면 설정 활성 장소만, false면 비활성/설정 없는 장소입니다. 랭킹에서는 필터를 페이지네이션 전에 적용하고 total 등 페이지 메타데이터도 필터 결과 기준으로 계산해 주세요. 문자열 `"false"`를 단순 truthy로 처리하지 않도록 검증해 주세요.

## 6. Swagger 계약 및 분석 API 보완

- 장소별 공통 상태 DTO와 각 목록 wrapper, 상세 응답에 실제 `@ApiOkResponse({ type: ... })` 등 응답 스키마를 연결해 주세요.
- 요청 DTO에 실제 속성을 노출하고 타입·필수 여부·nullable·enum·예시·검증 범위를 정의해 주세요. 중첩 일정 배열도 항목 DTO까지 노출해야 합니다.
- 쿼리의 example과 default는 다르므로, `page`·`limit`의 기본값·최댓값을 명시해 주세요.
- `POST /analytics/events`의 `CreateAnalyticsEventDto`에 실제 `placeId`, `eventType` 및 허용 이벤트 enum을 공개해 주세요. 앱은 현재 `PLACE_DETAIL_VIEW`, `VISIT_AUTH_PAGE_ENTER`를 전송합니다. 성공 상태 코드와 응답, 잘못된 장소/이벤트 오류도 명시해 주세요.
- `GET /business/analytics/page-funnel`의 실제 반환 필드, 집계 기간·시간대, 이벤트 수인지 고유 사용자 수인지, 전환율 분모와 0건 처리, 중복 집계 정책을 공개해 주세요. 현재 Swagger에는 쿼리 파라미터가 없으므로 기간 필터가 존재한다고 가정하지 않고, 현행 집계 범위를 먼저 명시해 주세요.
- 페이지 퍼널은 가맹점 조회 API이며 사용자 앱에서 호출하는 대상은 아닙니다. 사용자 앱의 이벤트 전송과 별개로 검증해 주세요.

## 7. 완료 확인 자료

다음 사례의 테스트 장소 ID와 기대 응답을 전달해 주세요.

| 사례 | `verificationAvailable` | `isOpenNow` |
| --- | --- | --- |
| 인증 활성, 영업시간 내 | true | true |
| 인증 활성, 영업 종료 | true | false |
| 인증 비활성, 영업 중 | false | true |
| 인증 설정 없음, 운영시간 없음 | false | null |
| 명시적 휴무·브레이크타임 | 설정 기준 | false |
| 불완전한 시간 정보 | 설정 기준 | null |

추가 검증: 날짜별 예외·임시 휴무·야간 영업·자정 경계, 설정 변경 후 목록/상세 일치, 권한 없는 변경 차단, 대량 지도 조회의 쿼리 수 및 응답 시간. 테스트 데이터는 운영 장소를 임의로 활성화하지 않고 준비해 주세요.

프론트는 배포 후 `GapPlace.isOpenNow` 파싱과 카드 매핑, 명시적 null 보존, 목록 캐시 갱신을 반영합니다. 백엔드 필드 추가만으로 현재 앱 코드가 자동 연동되지는 않습니다.

우선순위: **목록 `isOpenNow` 및 공통 상태 계약 → 기존 설정 API 명세와 데이터 점검 → Swagger 응답/분석 명세 보완**. 현재 접수 가능 사유와 서버 필터는 선택 확장입니다.
