/// VWorld (국토정보플랫폼) 오픈API 인증키 — `<지도>`에서 구/군을 열었을 때
/// 까는 실제 타일 지도용.
///
/// 발급: https://www.vworld.kr → 오픈API → 인증키 발급. "서비스 URL"에
/// 배포 도메인(개발은 `localhost`)을 등록해야 타일이 내려옵니다.
///
/// 빈 값이면 타일 없이 지역 외곽선 + 스팟 핀만 (`RegionDetailMap` 폴백).
/// 빌드 시 `--dart-define=VWORLD_API_KEY=발급키`로 주입.
const String vworldApiKey = String.fromEnvironment('VWORLD_API_KEY');

/// VWorld WMTS 스타일: Base / gray / midnight / Satellite / Hybrid.
/// 수채화 톤에는 `gray`가 가장 덜 튄다.
const String vworldTileStyle = 'gray';

/// The XYZ tile URL template `flutter_map` needs. Empty when no key.
String get vworldTileUrl => vworldApiKey.isEmpty
    ? ''
    : 'https://api.vworld.kr/req/wmts/1.0.0/$vworldApiKey/$vworldTileStyle/{z}/{y}/{x}.png';
