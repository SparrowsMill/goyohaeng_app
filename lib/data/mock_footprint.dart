/// `<기록 플랫폼>` (user_flow §8) placeholder 데이터 — 날짜별 여행 기록 피드.
/// 각 기록은 날짜 · 장소 · 제목 · 짧은 글 · 사진 여러 장으로 이뤄진다.
///
/// * TODO(backend): 기록 플랫폼 조회/작성/수정 API 연동 — 날짜·장소·제목(50자)·
///   본문(200자)·갤러리 사진(최대 5장). "기록용 플랫폼에 공유"로 진입 시
///   날짜/장소/획득 일러스트가 자동 첨부된다 (user_flow §8).
/// * TODO(asset): 기록 사진 — travel 보상 장면(`assets/illustrations/rewards/
///   travel_{name}.png`, §9) 참조. 아직 미납품이라 없으면 아이콘 placeholder.
library;

/// `travel_{name}` 여행 보상 장면의 에셋 경로.
String travelSceneAsset(String name) =>
    'assets/illustrations/rewards/travel_$name.png';

/// 기록 한 건.
class FootprintEntry {
  const FootprintEntry({
    required this.date,
    required this.text,
    this.title,
    this.place,
    this.photoAssets = const [],
  });

  final DateTime date;

  /// 제목 (50자 이내, 선택).
  final String? title;

  /// 짧은 글 (200자 이내).
  final String text;

  /// 기록한 장소 (선택).
  final String? place;

  /// 첨부 사진 — 전체 에셋 경로.
  final List<String> photoAssets;

  /// 같은 날짜인지 (연·월·일만 비교).
  bool isOn(DateTime day) =>
      date.year == day.year && date.month == day.month && date.day == day.day;
}

/// `<기록 플랫폼 글쓰기>` 가 작성/수정 후 돌려주는 값 — 호출한 화면이
/// 목록에 반영한다 (백엔드 연동 전 placeholder).
class FootprintDraft {
  const FootprintDraft({
    required this.date,
    required this.text,
    this.title,
    this.place,
    this.photoAssets = const [],
  });

  final DateTime date;
  final String? title;
  final String text;
  final String? place;
  final List<String> photoAssets;

  FootprintEntry toEntry() => FootprintEntry(
        date: date,
        title: title,
        text: text,
        place: place,
        photoAssets: photoAssets,
      );
}

/// 최근순으로 정렬된 기록 목록.
final List<FootprintEntry> mockFootprintEntries = [
  FootprintEntry(
    date: DateTime(2026, 9, 9),
    place: '전주 한옥마을',
    photoAssets: [
      travelSceneAsset('hanok'),
      travelSceneAsset('alley'),
      travelSceneAsset('teahouse'),
    ],
    text: '기와지붕 사이로 저녁 빛이 스며들 무렵.\n'
        '골목마다 다른 이야기가 걸려 있는 것 같았다.\n'
        '느리게 걸을수록 더 많이 보였다.',
  ),
  FootprintEntry(
    date: DateTime(2026, 9, 3),
    place: '강릉 안목해변',
    photoAssets: [travelSceneAsset('beach'), travelSceneAsset('harbor')],
    text: '파도 소리에 맞춰 커피를 식혔다.\n'
        '바다는 매번 처음 보는 얼굴을 하고 있다.',
  ),
  FootprintEntry(
    date: DateTime(2026, 8, 28),
    place: '보성 녹차밭',
    photoAssets: [
      travelSceneAsset('greentea'),
      travelSceneAsset('hill'),
      travelSceneAsset('mist'),
      travelSceneAsset('path'),
    ],
    text: '층층이 이어진 초록이 언덕을 덮고 있었다.\n'
        '안개가 걷히기를 기다리는 시간마저 좋았다.',
  ),
  FootprintEntry(
    date: DateTime(2026, 8, 24),
    place: '경주 황리단길',
    photoAssets: [
      travelSceneAsset('hwangnidan'),
      travelSceneAsset('lantern'),
      travelSceneAsset('wall'),
    ],
    text: '오래된 담장 옆에 새 가게들이 들어서 있었다.\n'
        '옛것과 새것이 나란히 있는 풍경이 정겨웠다.',
  ),
  FootprintEntry(
    date: DateTime(2026, 8, 14),
    place: '남해 독일마을',
    photoAssets: [
      travelSceneAsset('riviera'),
      travelSceneAsset('village'),
      travelSceneAsset('garden'),
      travelSceneAsset('terrace'),
      travelSceneAsset('sunset'),
    ],
    text: '햇살이 바다 위로 부서지던 오후.\n'
        '골목을 걷다 마주한 작은 풍경이 마음을 멈추게 했어.\n'
        '이 순간을 오래오래 기억하고 싶다.',
  ),
  FootprintEntry(
    date: DateTime(2026, 8, 11),
    place: '담양 죽녹원',
    photoAssets: [
      travelSceneAsset('bamboo'),
      travelSceneAsset('forest'),
      travelSceneAsset('cafe'),
    ],
    text: '대나무 사이로 바람이 지나갈 때마다\n'
        '초록빛 소리가 났다.',
  ),
  FootprintEntry(
    date: DateTime(2026, 8, 7),
    place: '안동 하회마을',
    photoAssets: [travelSceneAsset('hahoe'), travelSceneAsset('river')],
    text: '강이 마을을 크게 감싸 안고 흐른다.\n'
        '오래 지켜온 것들의 단단함을 느꼈다.',
  ),
  FootprintEntry(
    date: DateTime(2026, 8, 3),
    place: '서울 북촌',
    photoAssets: [travelSceneAsset('bukchon'), travelSceneAsset('rooftop')],
    text: '언덕을 오르니 지붕들이 물결처럼 이어졌다.',
  ),
];

/// 기록이 있는 날짜(연·월·일) 집합 — 달력에 발자국 표시를 찍기 위한 것.
Set<DateTime> footprintDays(Iterable<FootprintEntry> entries) => {
      for (final e in entries) DateTime(e.date.year, e.date.month, e.date.day),
    };
