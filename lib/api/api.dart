/// 백엔드 연동 진입점 — `import '../../api/api.dart';` 하나로 모두 사용.
///
/// 스펙: `docs/api_spec.md` FINAL (2026-09-12) — Auth / Users(+dashboard·
/// favorites·ingredients·foods) / Regions / Categories / Places(+trends·
/// favorite) / GAP Score(places gap·rankings·map·recommendations, regions
/// gap-scores) / Visit Verifications(신청·조회·취소 — self-verify 없음) /
/// Ingredients(상세+GAP 획득 정보) / Foods(+제작) / Food Histories /
/// Records(발자국 CRUD)까지 전 영역이 구현되어 있다.
library;

export 'api_client.dart';
export 'api_config.dart';
export 'api_exception.dart';
export 'auth_store.dart';
export 'dashboard_store.dart';
export 'models.dart';
export 'services/auth_service.dart';
export 'services/category_service.dart';
export 'services/food_history_service.dart';
export 'services/food_service.dart';
export 'services/gap_service.dart';
export 'services/ingredient_service.dart';
export 'services/place_service.dart';
export 'services/record_service.dart';
export 'services/region_service.dart';
export 'services/user_service.dart';
export 'services/visit_verification_service.dart';
