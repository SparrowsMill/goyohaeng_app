/// VWorld (국토정보플랫폼) 오픈API 인증키 — `<지도>`에서 구/군을 열었을 때
/// 까는 실제 타일 지도용.
///
/// 발급: https://www.vworld.kr → 오픈API → 인증키 발급. "서비스유형"은
/// APP(모바일)로, "활용 API"에 WMTS/TMS API를 포함해서 신청. APP 키는
/// Referer(도메인) 검증을 하지 않는다 (확인됨 2026-09-07).
///
/// 빈 값이면 타일 없이 지역 외곽선 + 스팟 핀만 (`RegionDetailMap` 폴백).
/// 다른 키로 빌드하려면 `--dart-define=VWORLD_API_KEY=...`.
const String vworldApiKey = String.fromEnvironment(
  'VWORLD_API_KEY',
  defaultValue: '2756E41D-EB72-4620-A373-46F3EA819E7D',
);

/// VWorld WMTS 레이어: `Base` / `midnight` / `white` / `Hybrid` (`.png`),
/// `Satellite` (`.jpeg`). `white` = 최소한의 옅은 지도로 수채화 톤과 가장
/// 덜 부딪힌다.
const String vworldTileLayer = 'white';

/// The XYZ (`{z}/{y}/{x}`) tile URL template `flutter_map` needs. Empty when
/// no key is configured.
String get vworldTileUrl => vworldApiKey.isEmpty
    ? ''
    : 'https://api.vworld.kr/req/wmts/1.0.0/$vworldApiKey/$vworldTileLayer/{z}/{y}/{x}.png';
