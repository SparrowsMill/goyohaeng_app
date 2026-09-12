/// 백엔드 연동 진입점 — `import '../../api/api.dart';` 하나로 모두 사용.
///
/// 스펙: `frontend-api-spec.md` v1 (2026-09-10) — Auth / Users(+dashboard·
/// favorites·ingredients·foods) / Regions / Categories / Places(+trends·
/// favorite) / Visit Verifications / Foods / GAP Score(places gap·rankings·
/// map, regions gap-scores). 기록/발자국은 아직 백엔드 미구현이라 그 부분만
/// 목업(`lib/data/`)을 쓴다.
library;

export 'api_client.dart';
export 'api_config.dart';
export 'api_exception.dart';
export 'auth_store.dart';
export 'dashboard_store.dart';
export 'models.dart';
export 'services/auth_service.dart';
export 'services/category_service.dart';
export 'services/food_service.dart';
export 'services/gap_service.dart';
export 'services/place_service.dart';
export 'services/region_service.dart';
export 'services/user_service.dart';
export 'services/visit_verification_service.dart';
