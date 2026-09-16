import 'package:flutter/material.dart';

/// `MaterialApp.navigatorKey`. `MaterialApp.builder`가 감싸는 위젯 트리는 앱의
/// `Navigator`보다 바깥(조상)에 있어 `Navigator.of(context)`로 접근할 수
/// 없다 — `VisitTimerOverlay`처럼 그 레벨에서 화면을 push해야 하는 전역
/// 오버레이는 이 키를 대신 쓴다.
final rootNavigatorKey = GlobalKey<NavigatorState>();
