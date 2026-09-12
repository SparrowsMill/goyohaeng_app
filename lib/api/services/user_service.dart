import '../api_client.dart';
import '../models.dart';

/// `/users/me*` (frontend-api-spec.md §3). 모두 JWT 인증 필요.
class UserService {
  UserService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<Me> getMe() async {
    final res = await _client.get('/users/me');
    return Me.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `PATCH /users/me` — 이름·생년월일·성별. `username`은 수정 불가(스펙 §3.2).
  Future<Me> updateMe({
    String? realName,
    String? birthDate,
    String? gender,
  }) async {
    final res = await _client.patch('/users/me', body: {
      'realName': ?realName,
      'birthDate': ?birthDate,
      'gender': ?gender,
    });
    return Me.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `PATCH /users/me/settings` — 알림 수신 3종.
  Future<Me> updateSettings({
    bool? promotionNotificationEnabled,
    bool? nearbyNotificationEnabled,
    bool? recordNotificationEnabled,
  }) async {
    final res = await _client.patch('/users/me/settings', body: {
      'promotionNotificationEnabled': ?promotionNotificationEnabled,
      'nearbyNotificationEnabled': ?nearbyNotificationEnabled,
      'recordNotificationEnabled': ?recordNotificationEnabled,
    });
    return Me.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `PATCH /users/me/password` — 새 비밀번호 최소 8자(스펙 §3.4).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.patch('/users/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// `DELETE /users/me` — soft delete (스펙 §3.5).
  Future<void> deleteMe() async {
    await _client.delete('/users/me');
  }

  /// `GET /users/me/dashboard` — 메인 통계 (스펙 §3.6).
  Future<Dashboard> getDashboard() async {
    final res = await _client.get('/users/me/dashboard');
    return Dashboard.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /users/me/favorites` — 내 즐겨찾기 목록 (스펙 §3.7, 페이지네이션).
  Future<Paged<FavoritePlace>> getFavorites({int page = 1, int limit = 20}) async {
    final res = await _client.get(
      '/users/me/favorites',
      query: {'page': page, 'limit': limit},
    );
    return Paged.fromJson(
      (res as Map).cast<String, dynamic>(),
      FavoritePlace.fromJson,
    );
  }

  /// `GET /users/me/ingredients` — 내 보유 재료 (스펙 §3.8).
  Future<UserIngredients> getIngredients() async {
    final res = await _client.get('/users/me/ingredients');
    return UserIngredients.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /users/me/foods` — 내가 만든 음식 목록 (스펙 §3.9, 페이지네이션).
  Future<Paged<UserFood>> getFoods({int page = 1, int limit = 20}) async {
    final res = await _client.get(
      '/users/me/foods',
      query: {'page': page, 'limit': limit},
    );
    return Paged.fromJson((res as Map).cast<String, dynamic>(), UserFood.fromJson);
  }
}
