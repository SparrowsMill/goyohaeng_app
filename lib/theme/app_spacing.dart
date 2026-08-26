/// Spacing scale and layout constants — CLAUDE.md §3.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
  static const massive = 48.0;

  /// Target mobile frame width. This app does not support tablet/desktop.
  static const screenWidth = 390.0;

  static const pagePaddingStandard = xl; // 20px
  static const pagePaddingCompact = lg; // 16px
  static const sectionGapStandard = xxl; // 24px
  static const sectionGapMajor = xxxl; // 32px
  static const relatedElementGapSmall = sm; // 8px
  static const relatedElementGapLarge = md; // 12px
  static const cardGroupGap = lg; // 16px
}
