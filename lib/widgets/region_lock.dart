import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 서울만 실제 GAP `regionId` 필터를 쓸 수 있어(백엔드 `Region` 테이블이 아직
/// 서울만 있음, `docs/backend_requirements_pending.md` 6번) 다른 시도는 지도/
/// 랭킹 화면에서 잠가둔다. 새 지역이 열리면 이 집합에 그 `Region` 코드를
/// 추가한다.
const kUnlockedSidoIds = {'11'};

bool isSidoLocked(String sidoId) => !kUnlockedSidoIds.contains(sidoId);

const _comingSoonMessage = '준비중이에요';

/// 잠긴 지역을 눌렀을 때 공통으로 띄우는 안내.
void showRegionComingSoonToast(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(_comingSoonMessage)));
}

/// Lazily-decoded [regionLockAsset] for the canvas map — null until
/// [ensureRegionLockImage] finishes (같은 패턴: `my_location_button.dart`의
/// `myLocationImage`).
final ValueNotifier<ui.Image?> regionLockImage = ValueNotifier<ui.Image?>(null);
Future<void>? _regionLockImageLoad;

const regionLockAsset = 'assets/illustrations/icon/lock.png';

void ensureRegionLockImage() {
  _regionLockImageLoad ??= rootBundle.load(regionLockAsset).then((data) async {
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    regionLockImage.value = (await codec.getNextFrame()).image;
  }).catchError((_) {});
}
