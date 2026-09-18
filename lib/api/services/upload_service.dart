import '../api_client.dart';

/// `/uploads/*` (2026-09-15 배포) — Cloudinary 이미지 업로드. JWT 인증 필요.
class UploadService {
  UploadService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `POST /uploads/images` — 이미지를 Cloudinary에 업로드하고 발자국
  /// `imageUrls`에 담을 수 있는 URL을 반환한다. JPG/PNG/WEBP만 허용, 파일당
  /// 최대 10MB — 서버가 형식/용량을 다시 검증하므로 실패 시 [ApiException]이
  /// 던져진다.
  Future<String> uploadImage(
    List<int> bytes, {
    String filename = 'photo.jpg',
    String contentType = 'image/jpeg',
  }) async {
    final res = await _client.postMultipart(
      '/uploads/images',
      fieldName: 'file',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    return (res as Map)['imageUrl'] as String;
  }
}
