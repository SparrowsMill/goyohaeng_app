# 카테고리 택소노미 정합화 요청

프론트(고요행 앱) ↔ 백엔드 `categories` 테이블 ↔ `users.ranking_category_filter`
세 곳의 카테고리 분류가 서로 어긋나 있어 정리를 요청합니다.

## 1. 현재 상태

**앱(프론트) UI의 필터 3분류** — `SpotCategory` enum (`lib/data/mock_region_ranking.dart`):

```
restaurant('식당'), cafe('카페'), activity('액티비티')
```

**백엔드 `GET /categories`** — 2레벨, 총 15행 트리 (Swagger 확인 + 백엔드
저장소 대조 확인, 2026-09-12):

```
level 1 (7개): FOOD(음식) / STAY(숙박) / ATTRACTION(관광지) / CULTURE(문화) /
               FESTIVAL(축제·행사) / LEISURE(레저·오락) / SHOPPING(쇼핑)

level 2 (8개, 전부 FOOD 하위 — 다른 6개 level-1은 하위 카테고리 없음):
  code            비고
  KOREAN          한식
  CHINESE         중식
  JAPANESE        일식
  WESTERN         양식
  FOREIGN         기타 외국음식
  QUICK_SERVICE   간편식/패스트푸드류
  BAR             주점/바
  CAFE            카페·비알코올
```

> 한글 라벨은 `code` 값 기반 추정입니다. 실제 `name` 컬럼 값과 다를 수
> 있으니 최종 표시 문구는 DB `name` 값으로 다시 대조 확인 필요.

**`users.ranking_category_filter` 컬럼의 CHECK 제약**:

```
ALL / FOOD / CAFE / ACTIVITY
```

## 2. 문제

1. **앱의 3분류가 실제 `categories` 택소노미와 1:1 대응하지 않음.**
   앱의 "액티비티"는 실제로는 ATTRACTION·CULTURE·FESTIVAL·LEISURE·SHOPPING
   5개 대분류를 뭉뚱그린 것이고, STAY(숙박)는 앱 어디에도 없음.

2. **백엔드 자체 스키마도 서로 어긋나 있음.**
   `users.ranking_category_filter`의 CHECK 값(`ALL/FOOD/CAFE/ACTIVITY`)이
   `categories` 테이블의 실제 코드(`FOOD/STAY/ATTRACTION/CULTURE/FESTIVAL/
   LEISURE/SHOPPING` + 하위 `CAFE`)와 다릅니다. `ACTIVITY`는 `categories`에
   존재하지 않는 코드이고, `CAFE`는 level 1이 아니라 FOOD의 하위 항목입니다.
   즉 이 컬럼은 지금 어떤 실제 카테고리 조합도 정확히 표현하지 못합니다.

3. 이 불일치 때문에 프론트는 현재 `GET /places`, `/places/gap/rankings`,
   `/places/gap/map`의 `categoryId` 서버 필터를 카테고리 선택 UI에 못 쓰고,
   지역별 랭킹 화면 등에서 `GET /categories`의 level-1 실 카테고리만 별도로
   불러와 임시로 필터 칩을 구성하는 중입니다.

## 3. `users.ranking_category_filter` 컬럼 — 백엔드 확정 답변 (2026-09-12)

> 현재 실제 API에서 사용되지 않는 레거시 컬럼이라 `categoryId` 용도로
> 재활용하지 않고 제거하는 방향으로 정리하겠습니다. 랭킹/장소 카테고리
> 필터는 사용자 테이블 값이 아니라 `/categories`에서 내려주는 실제
> `categoryId`를 기준으로 사용합니다. 다만 컬럼 자체 삭제는 DB 스키마
> 변경이 필요해서 DB 담당 작업 시 반영할 예정이고, 프론트에서는 지금부터
> 해당 컬럼을 사용하지 않으면 됩니다.

**결정됨: 완전 제거.** 프론트는 애초에 이 컬럼을 쓴 적이 없어 추가 조치
불필요 — `ACTIVITY` 값 마이그레이션 논의도 이걸로 종결.

## 4. 상위→하위 카테고리 포함(cascade) — 백엔드 확정 답변 (2026-09-12)

> 백엔드 구현 및 로컬 테스트까지 완료했습니다. 현재 아래 두 API 모두
> 동일하게 적용되어 있습니다: `GET /places?categoryId={id}`,
> `GET /places/gap/rankings?categoryId={id}`. 예를 들어 `categoryId=1`
> (FOOD)을 보내면 FOOD 자체뿐 아니라 KOREAN, CHINESE, JAPANESE, WESTERN,
> FOREIGN, QUICK_SERVICE, BAR, CAFE 등 FOOD의 하위 카테고리도 함께
> 조회됩니다. 반대로 `categoryId=15`(CAFE)처럼 하위 카테고리를 직접
> 보내면 해당 카테고리만 조회됩니다.

**1차 확인 시 구현·로컬 테스트 완료라고 확인받은 건 `/places`와
`/places/gap/rankings` 두 개뿐**이었고, `/places/gap/map`은 언급이
없었습니다.

## 5. 배포 후 직접 재검증 (2026-09-12, 로컬 서버 `localhost:3000` 기준)

배포됐다는 연락을 받고 `categoryId=1`(FOOD)로 세 엔드포인트를 직접
호출해서 실제 응답을 대조했습니다:

| 엔드포인트 | 배포 전 | 배포 후 재검증 | 상태 |
|---|---|---|---|
| `/places` | 875건, `categoryId=1`만 | **140,932건**, `1/8/9/11/15` 섞여 나옴 | ✅ 정상 |
| `/places/gap/rankings` | 807건, `categoryId=1`만 | **926건** (807 + 하위 7종 합 119 — 예측값과 정확히 일치), `1/8/9/11/12/13/15` 섞여 나옴 | ✅ 정상 |
| `/places/gap/map` | 807건, `categoryId=1`만 | **807건, 여전히 `categoryId=1`만** | ❌ 미적용 |

**`/places`, `/places/gap/rankings`는 확인 완료 — cascade 정상 동작.**

**`/places/gap/map`은 여전히 exact-match만 됩니다.** 그런데 하필
`<지역별 랭킹>` 화면(`region_ranking_screen.dart`)의 스팟 목록은 상단의
좌표 기반 미니 지도 때문에 **이 엔드포인트가 꼭 필요합니다**
(`/places`·`/places/gap/rankings`는 좌표를 안 줘서 대체 불가). 애초에
백엔드가 이 엔드포인트의 cascade를 확답한 적은 없어서 "약속을 어긴" 건
아니지만, 실제 전환 대상이 하필 이 엔드포인트라 추가 작업이 필요합니다.

## 6. `/places/gap/map` 후속 반영 + 프론트 전환 완료 (2026-09-12)

백엔드가 `/places/gap/map`에도 동일한 cascade 패치를 적용했다고 전달,
배포 확인 전 로컬 서버(`localhost:3000`)에 직접 재검증:

| 케이스 | 결과 |
|---|---|
| `categoryId=1`(FOOD) | 926건, `1/8/9/10/11/12/13/15` 전부 섞여 나옴 — §5의 예측값(926)과 정확히 일치 |
| `categoryId=15`(CAFE, leaf) | 11건, `15`만 — 상위로 안 넓어짐 확인 |

**3개 엔드포인트(`/places`, `/places/gap/rankings`, `/places/gap/map`)
모두 cascade 정상 동작 확인 완료.**

**프론트 전환 완료.** `lib/data/gap_spots.dart`가 이제 `categoryId`별로
캐시(`_places[categoryId]`)해서 `/places/gap/map?categoryId=`를 서버에
직접 넘기고, `region_ranking_screen.dart`의 카테고리 필터는 이름 문자열
비교 대신 실제 `categoryId`를 저장·전달하도록 바뀌었다. 필터 변경 시
서버에 다시 조회하고, 선택된 스팟이 결과에서 빠지면 선택 해제된다. 지역
(시군구) 필터는 여전히 클라이언트 폴리곤 판정 — `GET /regions` 행정코드
문제(§7)는 별개로 남아 있다.

이 문서의 카테고리 택소노미 관련 항목은 여기서 종결.

## 7. 참고 — 관련 지역 코드 정합화 요청

같은 맥락에서 `GET /regions`에 지역 코드가 없어 지도/랭킹 지역 필터가 막혀
있는 문제는 별도로 `docs/region_admin_codes.csv`에 현재 MVP 범위인 서울
(시도 코드 `11`) + 자치구 25개(시군구 5자리 코드) 매핑표를 정리해
전달합니다.

**코드 체계 명시**: 이 코드는 **통계청(KOSTAT) SGIS 행정구역코드**입니다
(`sgis.kostat.go.kr`의 공식 등록 파일로 25개 자치구 전부 대조 확인함,
행정동 경계 기준). 행정안전부가 관리하는 법정동코드/행정동코드(10자리,
예: 종로구 `11110`)와는 번호 체계 자체가 다른 별개의 정부 공식 코드이니,
매핑 시 헷갈리지 않도록 SGIS 행정구역코드 기준으로 조회/대조해 주세요.

`regions` 응답에 이 코드 필드 하나만 추가되면 `?regionId=` 필터와 지도
지역 색칠/랭킹 필터가 함께 풀립니다. 앱의 GeoJSON 자체는 전국 단위라
서비스 지역이 넓어지면 나머지 시도/시군구 코드도 같은 방식으로 바로 뽑아
전달할 수 있습니다.
