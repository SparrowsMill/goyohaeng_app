import '../api_client.dart';
import '../models.dart';

/// `/auth/*` (frontend-api-spec.md §2). 인증 불필요.
class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// 아이디 사용 가능 여부. 서버 응답 형태가 확정되지 않아
  /// (`available` / `isAvailable` / `duplicated` 등) 가능한 키를 모두 살펴본다.
  Future<bool> isUsernameAvailable(String username) async {
    final res = await _client.get(
      '/auth/check-username',
      query: {'username': username},
    );
    if (res is Map) {
      for (final key in ['available', 'isAvailable', 'usable']) {
        if (res[key] is bool) return res[key] as bool;
      }
      for (final key in ['duplicated', 'exists', 'taken']) {
        if (res[key] is bool) return !(res[key] as bool);
      }
    }
    if (res is bool) return res;
    return true;
  }

  /// `POST /auth/signup`. [gender]는 `MALE` | `FEMALE`, [birthDate]는 `YYYY-MM-DD`.
  Future<SignupResult> signup({
    required String username,
    required String password,
    required String realName,
    required String email,
    required String phone,
    required String birthDate,
    required String gender,
  }) async {
    final res = await _client.post('/auth/signup', body: {
      'username': username,
      'password': password,
      'realName': realName,
      'email': email,
      'phone': phone,
      'birthDate': birthDate,
      'gender': gender,
    });
    return SignupResult.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `POST /auth/login`.
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final res = await _client.post('/auth/login', body: {
      'username': username,
      'password': password,
    });
    return LoginResult.fromJson((res as Map).cast<String, dynamic>());
  }
}
