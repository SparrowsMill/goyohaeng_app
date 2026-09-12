/// 백엔드 응답 DTO (frontend-api-spec.md). 서버가 스펙에 없는 필드를 더 내려줘도
/// 무시하고, 빠진 옵션 필드는 `null`로 둔다.
library;

int? _asInt(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
double? _asDouble(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
bool _asBool(dynamic v) => v == true || v == 'true' || v == 1;
DateTime? _asDate(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

/// 로그인 응답의 `user`, 그리고 회원가입 응답에서 공통으로 쓰는 최소 사용자 정보.
class AuthUser {
  const AuthUser({required this.id, required this.username, required this.realName});

  final int id;
  final String username;
  final String realName;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: _asInt(json['id'] ?? json['userId']) ?? 0,
        username: json['username'] as String? ?? '',
        realName: json['realName'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'username': username, 'realName': realName};
}

/// `POST /auth/login` 응답.
class LoginResult {
  const LoginResult({required this.accessToken, required this.user});

  final String accessToken;
  final AuthUser user;

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        accessToken: json['accessToken'] as String? ?? '',
        user: AuthUser.fromJson(
          (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

/// `POST /auth/signup` 응답.
class SignupResult {
  const SignupResult({
    required this.userId,
    required this.username,
    required this.realName,
    required this.message,
  });

  final int userId;
  final String username;
  final String realName;
  final String message;

  factory SignupResult.fromJson(Map<String, dynamic> json) => SignupResult(
        userId: _asInt(json['userId']) ?? 0,
        username: json['username'] as String? ?? '',
        realName: json['realName'] as String? ?? '',
        message: json['message'] as String? ?? '회원가입이 완료되었습니다.',
      );
}

/// `GET /users/me` 응답.
class Me {
  const Me({
    required this.id,
    required this.username,
    required this.realName,
    this.email,
    this.phone,
    this.birthDate,
    this.gender,
    required this.promotionNotificationEnabled,
    required this.nearbyNotificationEnabled,
    required this.recordNotificationEnabled,
  });

  final int id;
  final String username;
  final String realName;
  final String? email;
  final String? phone;

  /// `YYYY-MM-DD` 문자열 그대로 (스펙 §3.1).
  final String? birthDate;

  /// `MALE` | `FEMALE`.
  final String? gender;

  final bool promotionNotificationEnabled;
  final bool nearbyNotificationEnabled;
  final bool recordNotificationEnabled;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: _asInt(json['id']) ?? 0,
        username: json['username'] as String? ?? '',
        realName: json['realName'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        birthDate: json['birthDate'] as String?,
        gender: json['gender'] as String?,
        promotionNotificationEnabled:
            _asBool(json['promotionNotificationEnabled']),
        nearbyNotificationEnabled: _asBool(json['nearbyNotificationEnabled']),
        recordNotificationEnabled: _asBool(json['recordNotificationEnabled']),
      );

  DateTime? get birthDateTime => _asDate(birthDate);
}

/// `GET /regions` 항목.
class Region {
  const Region({
    required this.id,
    required this.parentId,
    required this.regionType,
    required this.name,
  });

  final int id;
  final int? parentId;

  /// `PROVINCE` | `DISTRICT` …
  final String regionType;
  final String name;

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: _asInt(json['id']) ?? 0,
        parentId: _asInt(json['parentId']),
        regionType: json['regionType'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// `GET /regions/{id}/spot-counts` 응답 (본인 + children).
class RegionSpotCounts {
  const RegionSpotCounts({
    required this.regionId,
    required this.regionName,
    required this.spotCount,
    required this.children,
  });

  final int regionId;
  final String regionName;
  final int spotCount;
  final List<RegionSpotCounts> children;

  factory RegionSpotCounts.fromJson(Map<String, dynamic> json) =>
      RegionSpotCounts(
        regionId: _asInt(json['regionId']) ?? 0,
        regionName: json['regionName'] as String? ?? '',
        spotCount: _asInt(json['spotCount']) ?? 0,
        children: ((json['children'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => RegionSpotCounts.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

/// `GET /categories` 항목.
class Category {
  const Category({
    required this.id,
    required this.parentId,
    required this.code,
    required this.name,
    required this.level,
    required this.isActive,
  });

  final int id;
  final int? parentId;
  final String code;
  final String name;
  final int level;
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: _asInt(json['id']) ?? 0,
        parentId: _asInt(json['parentId']),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        level: _asInt(json['level']) ?? 1,
        isActive: _asBool(json['isActive']),
      );
}

/// `images[]` 항목 (스펙 §6.2). `thumbnailUrl`이 목록/썸네일용, `originalUrl`이 원본.
class PlaceImage {
  const PlaceImage({
    required this.id,
    this.originalUrl,
    this.thumbnailUrl,
    this.displayOrder,
  });

  final int id;
  final String? originalUrl;
  final String? thumbnailUrl;
  final int? displayOrder;

  /// 화면에서 바로 쓸 URL — 썸네일 우선, 없으면 원본.
  String? get url => thumbnailUrl ?? originalUrl;

  factory PlaceImage.fromJson(Map<String, dynamic> json) => PlaceImage(
        id: _asInt(json['id']) ?? 0,
        originalUrl: json['originalUrl'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        displayOrder: _asInt(json['displayOrder']),
      );
}

/// `availableIngredients[]` 항목 (스펙 §6.2).
class AvailableIngredient {
  const AvailableIngredient({
    required this.id,
    required this.name,
    this.imageUrl,
    this.rarity,
    required this.quantity,
    this.rewardRule,
  });

  final int id;
  final String name;
  final String? imageUrl;
  final String? rarity;
  final int quantity;

  /// 현재 실지급되는 값은 `EVERY_VISIT`만 (스펙 §7.3).
  final String? rewardRule;

  factory AvailableIngredient.fromJson(Map<String, dynamic> json) =>
      AvailableIngredient(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        rarity: json['rarity'] as String?,
        quantity: _asInt(json['quantity']) ?? 1,
        rewardRule: json['rewardRule'] as String?,
      );
}

/// `verification` 블록 (스펙 §6.2).
class PlaceVerificationConfig {
  const PlaceVerificationConfig({
    required this.enabled,
    this.controlMode,
    this.hoursMode,
    this.codeValidMinutes,
  });

  final bool enabled;
  final String? controlMode;
  final String? hoursMode;
  final int? codeValidMinutes;

  factory PlaceVerificationConfig.fromJson(Map<String, dynamic> json) =>
      PlaceVerificationConfig(
        enabled: _asBool(json['enabled']),
        controlMode: json['controlMode'] as String?,
        hoursMode: json['hoursMode'] as String?,
        codeValidMinutes: _asInt(json['codeValidMinutes']),
      );
}

/// `GET /places` 목록 항목 및 `GET /places/{id}` 상세 (상세 전용 필드는 옵션).
class Place {
  const Place({
    required this.id,
    required this.name,
    this.categoryId,
    this.districtRegionId,
    this.adminDongRegionId,
    this.legalDongRegionId,
    this.roadAddress,
    this.lotAddress,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.phone,
    this.homepage,
    this.ownerIntro,
    this.status,
    this.images = const [],
    this.operatingHours = const [],
    this.isOpenNow,
    this.benefits = const [],
    this.availableIngredients = const [],
    this.verification,
    this.isFavorite,
  });

  final int id;
  final String name;
  final int? categoryId;
  final int? districtRegionId;
  final int? adminDongRegionId;
  final int? legalDongRegionId;
  final String? roadAddress;
  final String? lotAddress;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? homepage;
  final String? ownerIntro;
  final String? status;

  // --- 상세 조회 전용 ---
  /// 장소 사진 — `{id, originalUrl, thumbnailUrl, displayOrder}` 객체 배열.
  final List<PlaceImage> images;
  final List<Map<String, dynamic>> operatingHours;
  final bool? isOpenNow;
  final List<Map<String, dynamic>> benefits;
  final List<AvailableIngredient> availableIngredients;
  final PlaceVerificationConfig? verification;

  /// 로그인 사용자의 즐겨찾기 여부 (스펙 §6.2 — 상세 조회 시에만 내려온다).
  final bool? isFavorite;

  String? get address => roadAddress ?? lotAddress;
  bool get hasLocation => latitude != null && longitude != null;

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        categoryId: _asInt(json['categoryId']),
        districtRegionId: _asInt(json['districtRegionId']),
        adminDongRegionId: _asInt(json['adminDongRegionId']),
        legalDongRegionId: _asInt(json['legalDongRegionId']),
        roadAddress: json['roadAddress'] as String?,
        lotAddress: json['lotAddress'] as String?,
        postalCode: json['postalCode'] as String?,
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
        phone: json['phone'] as String?,
        homepage: json['homepage'] as String?,
        ownerIntro: json['ownerIntro'] as String?,
        status: json['status'] as String?,
        images: ((json['images'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaceImage.fromJson(e.cast<String, dynamic>()))
            .toList(),
        operatingHours: ((json['operatingHours'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
        isOpenNow: json.containsKey('isOpenNow') ? _asBool(json['isOpenNow']) : null,
        benefits: ((json['benefits'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
        availableIngredients:
            ((json['availableIngredients'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) =>
                    AvailableIngredient.fromJson(e.cast<String, dynamic>()))
                .toList(),
        verification: (json['verification'] as Map?) == null
            ? null
            : PlaceVerificationConfig.fromJson(
                (json['verification'] as Map).cast<String, dynamic>()),
        isFavorite:
            json.containsKey('isFavorite') ? _asBool(json['isFavorite']) : null,
      );
}

/// `GET /places` 페이지네이션 응답 (스펙 §6.1 — 목록은 `items`에서 읽는다).
class PlaceListPage {
  const PlaceListPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<Place> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory PlaceListPage.fromJson(Map<String, dynamic> json) => PlaceListPage(
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Place.fromJson(e.cast<String, dynamic>()))
            .toList(),
        page: _asInt(json['page']) ?? 1,
        limit: _asInt(json['limit']) ?? 20,
        total: _asInt(json['total']) ?? 0,
        totalPages: _asInt(json['totalPages']) ?? 1,
      );
}

/// `GET /places/{placeId}/visit-status` 응답 (스펙 §6.3).
class VisitStatus {
  const VisitStatus({required this.placeId, required this.visited});

  final int placeId;
  final bool visited;

  factory VisitStatus.fromJson(Map<String, dynamic> json) => VisitStatus(
        placeId: _asInt(json['placeId']) ?? 0,
        visited: _asBool(json['visited']),
      );
}

/// 방문 인증 세션 (스펙 §7). 생성·조회·검증 응답이 모두 이 형태다.
class VisitVerification {
  const VisitVerification({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.arrivalOptionMinutes,
    this.expectedArrivalAt,
    required this.verificationCode,
    this.issuedAt,
    this.expiresAt,
    required this.status,
    this.verifiedAt,
    this.failReason,
    this.createdAt,
  });

  final int id;
  final int userId;
  final int placeId;
  final int arrivalOptionMinutes;
  final DateTime? expectedArrivalAt;
  final String verificationCode;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  /// `ISSUED` | `VERIFIED` | `EXPIRED` …
  final String status;
  final DateTime? verifiedAt;
  final String? failReason;
  final DateTime? createdAt;

  bool get isVerified => status == 'VERIFIED';
  bool get isExpired => status == 'EXPIRED';
  bool get isPending => status == 'ISSUED';

  factory VisitVerification.fromJson(Map<String, dynamic> json) =>
      VisitVerification(
        id: _asInt(json['id']) ?? 0,
        userId: _asInt(json['userId']) ?? 0,
        placeId: _asInt(json['placeId']) ?? 0,
        arrivalOptionMinutes: _asInt(json['arrivalOptionMinutes']) ?? 30,
        expectedArrivalAt: _asDate(json['expectedArrivalAt']),
        verificationCode: json['verificationCode'] as String? ?? '',
        issuedAt: _asDate(json['issuedAt']),
        expiresAt: _asDate(json['expiresAt']),
        status: json['status'] as String? ?? 'ISSUED',
        verifiedAt: _asDate(json['verifiedAt']),
        failReason: json['failReason'] as String?,
        createdAt: _asDate(json['createdAt']),
      );
}

// ===========================================================================
// v1 (2026-09-10) 확장 — 대시보드 / 즐겨찾기 / 재료 / 음식 / 트렌드
// ===========================================================================

/// `GET /users/me/dashboard` 응답 (스펙 §3.6) — 방앗간 홈 스탯바 + 방문 TOP.
class Dashboard {
  const Dashboard({
    required this.monthlyVisitCount,
    required this.ingredientCount,
    required this.verifiedVisitCount,
    required this.madeFoodCount,
    required this.topRegions,
  });

  final int monthlyVisitCount;
  final int ingredientCount;
  final int verifiedVisitCount;
  final int madeFoodCount;
  final List<DashboardRegion> topRegions;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        monthlyVisitCount: _asInt(json['monthlyVisitCount']) ?? 0,
        ingredientCount: _asInt(json['ingredientCount']) ?? 0,
        verifiedVisitCount: _asInt(json['verifiedVisitCount']) ?? 0,
        madeFoodCount: _asInt(json['madeFoodCount']) ?? 0,
        topRegions: ((json['topRegions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => DashboardRegion.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

class DashboardRegion {
  const DashboardRegion({
    required this.regionId,
    required this.regionName,
    required this.visitCount,
  });

  final int regionId;
  final String regionName;
  final int visitCount;

  factory DashboardRegion.fromJson(Map<String, dynamic> json) => DashboardRegion(
        regionId: _asInt(json['regionId']) ?? 0,
        regionName: json['regionName'] as String? ?? '',
        visitCount: _asInt(json['visitCount']) ?? 0,
      );
}

/// `GET /users/me/favorites` 항목 (스펙 §3.7) — Place + 즐겨찾기 메타.
class FavoritePlace {
  const FavoritePlace({
    required this.id,
    required this.name,
    this.categoryId,
    this.districtRegionId,
    this.roadAddress,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.isFavorite,
    this.favoritedAt,
  });

  final int id;
  final String name;
  final int? categoryId;
  final int? districtRegionId;
  final String? roadAddress;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final bool isFavorite;
  final DateTime? favoritedAt;

  factory FavoritePlace.fromJson(Map<String, dynamic> json) => FavoritePlace(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        categoryId: _asInt(json['categoryId']),
        districtRegionId: _asInt(json['districtRegionId']),
        roadAddress: json['roadAddress'] as String?,
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
        imageUrl: json['imageUrl'] as String?,
        isFavorite: json.containsKey('isFavorite')
            ? _asBool(json['isFavorite'])
            : true,
        favoritedAt: _asDate(json['favoritedAt']),
      );
}

/// 페이지네이션 목록 응답의 공통 래퍼 (`items` + page/limit/total/totalPages).
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) item,
  ) =>
      Paged(
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => item(e.cast<String, dynamic>()))
            .toList(),
        page: _asInt(json['page']) ?? 1,
        limit: _asInt(json['limit']) ?? 20,
        total: _asInt(json['total']) ?? 0,
        totalPages: _asInt(json['totalPages']) ?? 1,
      );
}

/// `POST/DELETE /places/{id}/favorite` 응답 (스펙 §6.6–6.7).
class FavoriteToggleResult {
  const FavoriteToggleResult({required this.placeId, required this.isFavorite});

  final int placeId;
  final bool isFavorite;

  factory FavoriteToggleResult.fromJson(Map<String, dynamic> json) =>
      FavoriteToggleResult(
        placeId: _asInt(json['placeId']) ?? 0,
        isFavorite: _asBool(json['isFavorite']),
      );
}

/// `GET /users/me/ingredients` 항목 (스펙 §3.8).
class UserIngredient {
  const UserIngredient({
    required this.id,
    required this.name,
    this.description,
    this.ingredientType,
    required this.quantity,
    this.imageUrl,
    this.illustrationUrl,
    this.rarity,
    this.regionId,
    this.firstAcquiredAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;

  /// `BASIC` | `REGIONAL` …
  final String? ingredientType;
  final int quantity;
  final String? imageUrl;
  final String? illustrationUrl;
  final String? rarity;
  final int? regionId;
  final DateTime? firstAcquiredAt;
  final DateTime? updatedAt;

  bool get isRegional => ingredientType == 'REGIONAL' || regionId != null;

  factory UserIngredient.fromJson(Map<String, dynamic> json) => UserIngredient(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        ingredientType: json['ingredientType'] as String?,
        quantity: _asInt(json['quantity']) ?? 0,
        imageUrl: json['imageUrl'] as String?,
        illustrationUrl: json['illustrationUrl'] as String?,
        rarity: json['rarity'] as String?,
        regionId: _asInt(json['regionId']),
        firstAcquiredAt: _asDate(json['firstAcquiredAt']),
        updatedAt: _asDate(json['updatedAt']),
      );
}

/// `GET /users/me/ingredients` 응답 전체.
class UserIngredients {
  const UserIngredients({
    required this.items,
    required this.totalTypes,
    required this.totalQuantity,
  });

  final List<UserIngredient> items;
  final int totalTypes;
  final int totalQuantity;

  factory UserIngredients.fromJson(Map<String, dynamic> json) => UserIngredients(
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => UserIngredient.fromJson(e.cast<String, dynamic>()))
            .toList(),
        totalTypes: _asInt(json['totalTypes']) ?? 0,
        totalQuantity: _asInt(json['totalQuantity']) ?? 0,
      );
}

/// `GET /users/me/foods` 항목 (스펙 §3.9) — 내가 만든 음식.
class UserFood {
  const UserFood({
    required this.id,
    required this.foodId,
    required this.name,
    this.description,
    this.imageUrl,
    this.illustrationUrl,
    this.madeAt,
    this.specialIngredient,
    this.specialSourcePlace,
  });

  final int id;
  final int foodId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? illustrationUrl;
  final DateTime? madeAt;
  final String? specialIngredient;
  final String? specialSourcePlace;

  factory UserFood.fromJson(Map<String, dynamic> json) => UserFood(
        id: _asInt(json['id']) ?? 0,
        foodId: _asInt(json['foodId']) ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        illustrationUrl: json['illustrationUrl'] as String?,
        madeAt: _asDate(json['madeAt']),
        specialIngredient: json['specialIngredient'] as String?,
        specialSourcePlace: json['specialSourcePlace'] as String?,
      );
}

/// `GET /foods` / `GET /foods/{id}` 항목 (스펙 §8).
class Food {
  const Food({
    required this.id,
    required this.name,
    this.description,
    this.regionId,
    this.regionName,
    this.imageUrl,
    this.illustrationUrl,
    required this.canMake,
    required this.ingredients,
  });

  final int id;
  final String name;
  final String? description;
  final int? regionId;
  final String? regionName;
  final String? imageUrl;
  final String? illustrationUrl;
  final bool canMake;
  final List<FoodIngredient> ingredients;

  factory Food.fromJson(Map<String, dynamic> json) => Food(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        regionId: _asInt(json['regionId']),
        regionName: json['regionName'] as String?,
        imageUrl: json['imageUrl'] as String?,
        illustrationUrl: json['illustrationUrl'] as String?,
        canMake: _asBool(json['canMake']),
        ingredients: ((json['ingredients'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FoodIngredient.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

/// `foods[].ingredients[]` — 레시피 1줄 (필요량 vs 보유량).
class FoodIngredient {
  const FoodIngredient({
    required this.id,
    required this.name,
    this.ingredientType,
    required this.requiredQuantity,
    required this.ownedQuantity,
    required this.enough,
    this.imageUrl,
    this.illustrationUrl,
    this.rarity,
  });

  final int id;
  final String name;
  final String? ingredientType;
  final int requiredQuantity;
  final int ownedQuantity;
  final bool enough;
  final String? imageUrl;
  final String? illustrationUrl;
  final String? rarity;

  int get shortage =>
      (requiredQuantity - ownedQuantity) > 0 ? requiredQuantity - ownedQuantity : 0;

  factory FoodIngredient.fromJson(Map<String, dynamic> json) => FoodIngredient(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        ingredientType: json['ingredientType'] as String?,
        requiredQuantity: _asInt(json['requiredQuantity']) ?? 0,
        ownedQuantity: _asInt(json['ownedQuantity']) ?? 0,
        enough: _asBool(json['enough']),
        imageUrl: json['imageUrl'] as String?,
        illustrationUrl: json['illustrationUrl'] as String?,
        rarity: json['rarity'] as String?,
      );
}

/// `POST /foods/{id}/make` 성공 응답 (스펙 §8.3).
class MakeFoodResult {
  const MakeFoodResult({
    required this.success,
    this.userFood,
    this.usedIngredients = const [],
  });

  final bool success;
  final UserFood? userFood;
  final List<({int ingredientId, String name, int quantity})> usedIngredients;

  factory MakeFoodResult.fromJson(Map<String, dynamic> json) => MakeFoodResult(
        success: _asBool(json['success']),
        userFood: (json['userFood'] as Map?) == null
            ? null
            : UserFood.fromJson((json['userFood'] as Map).cast<String, dynamic>()),
        usedIngredients: ((json['usedIngredients'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => (
                  ingredientId: _asInt(e['ingredientId']) ?? 0,
                  name: e['name'] as String? ?? '',
                  quantity: _asInt(e['quantity']) ?? 0,
                ))
            .toList(),
      );
}

/// `GET /places/{id}/trends` 응답 (스펙 §6.4). 데이터 없으면 대부분 null/빈 배열.
class PlaceTrends {
  const PlaceTrends({
    required this.placeId,
    this.placeName,
    this.summaryText,
    this.keywords = const [],
    this.periodStart,
    this.periodEnd,
    this.generatedAt,
    this.contents = const [],
    this.searchTerm,
    this.searchInterest = const [],
  });

  final int placeId;
  final String? placeName;
  final String? summaryText;
  final List<String> keywords;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? generatedAt;

  /// 외부 글 목록 (`PlaceExternalContent`) — 구조 미확정이라 raw map으로 둔다.
  final List<Map<String, dynamic>> contents;
  final String? searchTerm;
  final List<Map<String, dynamic>> searchInterest;

  bool get hasData => summaryText != null || keywords.isNotEmpty;

  factory PlaceTrends.fromJson(Map<String, dynamic> json) => PlaceTrends(
        placeId: _asInt(json['placeId']) ?? 0,
        placeName: json['placeName'] as String?,
        summaryText: json['summaryText'] as String?,
        keywords: ((json['keywords'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        periodStart: _asDate(json['periodStart']),
        periodEnd: _asDate(json['periodEnd']),
        generatedAt: _asDate(json['generatedAt']),
        contents: ((json['contents'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
        searchTerm: json['searchTerm'] as String?,
        searchInterest: ((json['searchInterest'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
      );
}

// ===========================================================================
// GAP Score (2026-09-11) — DB에 저장된 최신 GapScoreRun 결과를 그대로 읽는다.
// 프론트에서 GAP Score를 직접 계산하지 않는다.
// ===========================================================================

/// 랭킹/지도 응답의 `run` 블록 — 이 응답이 어느 GAP 계산 회차 기준인지.
class GapScoreRun {
  const GapScoreRun({
    required this.id,
    this.formulaVersion,
    this.dataStage,
    this.calculatedAt,
  });

  final int id;

  /// 예: `GAP_V1_PROXY`.
  final String? formulaVersion;

  /// 예: `COLD_START`.
  final String? dataStage;
  final DateTime? calculatedAt;

  factory GapScoreRun.fromJson(Map<String, dynamic> json) => GapScoreRun(
        id: _asInt(json['id']) ?? 0,
        formulaVersion: json['formulaVersion'] as String?,
        dataStage: json['dataStage'] as String?,
        calculatedAt: _asDate(json['calculatedAt']),
      );
}

/// `GET /places/{id}/gap` — 한 장소의 최신 GAP Score.
class PlaceGapScore {
  const PlaceGapScore({
    required this.placeId,
    this.placeName,
    required this.gapScore,
    this.onlineScore,
    this.offlineScore,
    this.explanation,
  });

  final int placeId;
  final String? placeName;

  /// 0~100 스케일의 GAP Score (예: `78.0307`). 화면의 "갭지수 N"은 [gapIndex].
  final double gapScore;

  /// 0~1 스케일의 온라인 관심도 / 오프라인 방문도 원지표.
  final double? onlineScore;
  final double? offlineScore;

  /// 서버가 생성한 한 줄 설명 (아직 `null`로 내려올 수 있음).
  final String? explanation;

  /// 화면 표시용 정수 갭지수.
  int get gapIndex => gapScore.round();

  factory PlaceGapScore.fromJson(Map<String, dynamic> json) => PlaceGapScore(
        placeId: _asInt(json['placeId']) ?? 0,
        placeName: json['placeName'] as String?,
        gapScore: _asDouble(json['gapScore']) ?? 0,
        onlineScore: _asDouble(json['onlineScore']),
        offlineScore: _asDouble(json['offlineScore']),
        explanation: json['explanation'] as String?,
      );
}

/// GAP 랭킹 / 추천 / 지도 응답이 공유하는 장소 1건. `rank`는 랭킹 응답에만
/// 있고, `latitude`/`longitude`는 지도 응답에만 있다.
class GapPlace {
  const GapPlace({
    required this.placeId,
    this.placeName,
    this.categoryId,
    this.regionId,
    this.roadAddress,
    this.imageUrl,
    this.rank,
    this.latitude,
    this.longitude,
    required this.gapScore,
    this.onlineScore,
    this.offlineScore,
    this.explanation,
  });

  final int placeId;
  final String? placeName;
  final int? categoryId;
  final int? regionId;
  final String? roadAddress;
  final String? imageUrl;

  /// 랭킹 응답에서의 순위 (1부터). 추천/지도 응답에는 없다.
  final int? rank;

  /// 지도 응답에만 포함 — 좌표가 없는 장소는 지도 응답에서 제외된다.
  final double? latitude;
  final double? longitude;

  final double gapScore;
  final double? onlineScore;
  final double? offlineScore;
  final String? explanation;

  int get gapIndex => gapScore.round();
  bool get hasLocation => latitude != null && longitude != null;

  factory GapPlace.fromJson(Map<String, dynamic> json) => GapPlace(
        placeId: _asInt(json['placeId']) ?? 0,
        placeName: json['placeName'] as String?,
        categoryId: _asInt(json['categoryId']),
        regionId: _asInt(json['regionId']),
        roadAddress: json['roadAddress'] as String?,
        imageUrl: json['imageUrl'] as String?,
        rank: _asInt(json['rank']),
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
        gapScore: _asDouble(json['gapScore']) ?? 0,
        onlineScore: _asDouble(json['onlineScore']),
        offlineScore: _asDouble(json['offlineScore']),
        explanation: json['explanation'] as String?,
      );
}

/// `GET /places/gap/rankings` — 최신 run 기준 GAP Score 내림차순 페이지.
class GapRankingPage {
  const GapRankingPage({
    this.run,
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final GapScoreRun? run;
  final List<GapPlace> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory GapRankingPage.fromJson(Map<String, dynamic> json) => GapRankingPage(
        run: (json['run'] as Map?) == null
            ? null
            : GapScoreRun.fromJson((json['run'] as Map).cast<String, dynamic>()),
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => GapPlace.fromJson(e.cast<String, dynamic>()))
            .toList(),
        page: _asInt(json['page']) ?? 1,
        limit: _asInt(json['limit']) ?? 20,
        total: _asInt(json['total']) ?? 0,
        totalPages: _asInt(json['totalPages']) ?? 1,
      );
}

/// `GET /places/gap/map` — 좌표를 가진 장소만. 지도 마커로 바로 쓴다.
class GapMapData {
  const GapMapData({this.run, required this.items, required this.total});

  final GapScoreRun? run;
  final List<GapPlace> items;
  final int total;

  factory GapMapData.fromJson(Map<String, dynamic> json) => GapMapData(
        run: (json['run'] as Map?) == null
            ? null
            : GapScoreRun.fromJson((json['run'] as Map).cast<String, dynamic>()),
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => GapPlace.fromJson(e.cast<String, dynamic>()))
            .toList(),
        total: _asInt(json['total']) ?? 0,
      );
}

/// `GET /regions/gap-scores` 항목 — 지역별 최신 GAP Score 평균.
class RegionGapScore {
  const RegionGapScore({
    required this.regionId,
    this.regionName,
    required this.averageGapScore,
    required this.placeCount,
  });

  final int regionId;
  final String? regionName;
  final double averageGapScore;
  final int placeCount;

  int get gapIndex => averageGapScore.round();

  factory RegionGapScore.fromJson(Map<String, dynamic> json) => RegionGapScore(
        regionId: _asInt(json['regionId']) ?? 0,
        regionName: json['regionName'] as String?,
        averageGapScore: _asDouble(json['averageGapScore']) ?? 0,
        placeCount: _asInt(json['placeCount']) ?? 0,
      );
}

/// `POST /places/{id}/trends/first-view` 응답 (스펙 §6.5).
class TrendFirstViewResult {
  const TrendFirstViewResult({
    required this.firstView,
    required this.rewarded,
    this.ingredientId,
    this.ingredientName,
    this.ingredientQuantity,
  });

  final bool firstView;
  final bool rewarded;
  final int? ingredientId;
  final String? ingredientName;
  final int? ingredientQuantity;

  factory TrendFirstViewResult.fromJson(Map<String, dynamic> json) {
    final ing = (json['ingredient'] as Map?)?.cast<String, dynamic>();
    return TrendFirstViewResult(
      firstView: _asBool(json['firstView']),
      rewarded: _asBool(json['rewarded']),
      ingredientId: ing == null ? null : _asInt(ing['id']),
      ingredientName: ing?['name'] as String?,
      ingredientQuantity: ing == null ? null : _asInt(ing['quantity']),
    );
  }
}
