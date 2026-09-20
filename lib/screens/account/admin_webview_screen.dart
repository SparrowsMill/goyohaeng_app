import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/admin_config.dart';
import '../../theme/app_colors.dart';

/// 가맹점 관리자 웹(백오피스)을 그대로 띄우는 화면.
///
/// 앱은 별도 관리자 UI·API 연동을 갖지 않는다 — 로그인부터 데이터 조회까지
/// 전부 웹뷰 안의 웹사이트가 처리한다(계정센터의 "관리자 모드로 전환"에서
/// 진입). 세션은 웹뷰 자체 저장소(localStorage)에 남으므로 앱을 재실행해도
/// 재로그인 없이 이어진다.
class AdminWebViewScreen extends StatefulWidget {
  const AdminWebViewScreen({super.key});

  @override
  State<AdminWebViewScreen> createState() => _AdminWebViewScreenState();
}

class _AdminWebViewScreenState extends State<AdminWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  /// 로그인 화면을 벗어난 적이 있는지 — 로그인 성공 후 어딘가로 이동했다가
  /// 다시 로그인 경로로 돌아오면(사이트 자체의 로그아웃 처리) "로그아웃했다"로
  /// 본다. 처음 켤 때 로그인 화면부터 시작하는 것과 구분하기 위해 필요하다.
  bool _hasLeftLogin = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          // 로그아웃은 React Router의 클라이언트 사이드 navigate()라
          // onPageStarted/onPageFinished(실제 페이지 로드)가 아니라
          // onUrlChange(URL이 바뀌는 모든 경우)에서만 잡힌다.
          onUrlChange: (change) {
            final path = Uri.tryParse(change.url ?? '')?.path;
            if (path == null) return;
            if (path != AdminConfig.loginPath) {
              _hasLeftLogin = true;
              return;
            }
            if (_hasLeftLogin && mounted) {
              // 로그인 화면을 쓰다가(=로그인 상태였다가) 다시 로그인 경로로
              // 돌아옴 — 로그아웃한 것이므로 관리자 모드 자체를 나간다.
              Navigator.of(context).pop();
            }
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = '페이지를 불러오지 못했어요.\n(${error.description})';
            });
          },
        ),
      );
    _loadFresh();
  }

  /// 관리자 웹은 자주 바뀌는데, 웹뷰가 이전 배포의 `index.html`/번들을 캐시해
  /// 들고 있으면 서버엔 새 버전이 있어도 화면엔 예전 그대로 보인다 — 캐시부터
  /// 비우고 매번 새로 받아온다.
  Future<void> _loadFresh() async {
    await _controller.clearCache();
    await _controller.loadRequest(
      Uri.parse('${AdminConfig.baseUrl}${AdminConfig.loginPath}'),
    );
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    await _loadFresh();
  }

  /// 웹뷰 안에 뒤로 갈 히스토리가 있으면 그걸 먼저 소비하고, 없을 때만 화면을
  /// 실제로 닫는다.
  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.appBackground,
        // 자체 상단 바(제목/뒤로가기)는 두지 않는다 — 관리자 웹 자신이
        // 사이드바·뒤로가기 등 내비게이션을 갖추고 있어서 앱이 덧대는 건
        // 중복이다. 화면을 나가는 길은 시스템 뒤로가기(위 PopScope)와
        // 로그아웃(로그인 경로로 돌아오면 자동으로 나감, onUrlChange) 뿐.
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              if (_error != null)
                Container(
                  color: AppColors.appBackground,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.cloud_off_rounded,
                        size: 40,
                        color: AppColors.iconInactive,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _reload,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
