# 고요행 사용자 앱 — 백엔드 요청사항

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

## 4. `GET /regions` SGIS 행정구역코드 필드 추가

- `docs/region_admin_codes.csv` 재전달 필요 (기존 전달분 저장소에 없음)
- 수신 후 `RegionExternalCode`에 `codeType: 'SGIS'`로 임포트
