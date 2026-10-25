/// Shared UI animation timings. Values are in milliseconds: 500 ms = 0.5 s.
abstract final class AnimationTimings {
  static const addressBarSlideIn = Duration(milliseconds: 500);
  static const addressBarSlideOut = Duration(milliseconds: 500);
  static const modalPopIn = Duration(milliseconds: 150);
  static const modalPopOut = Duration(milliseconds: 150);
  static const sheetSlideIn = Duration(milliseconds: 280);
  static const sheetSlideOut = Duration(milliseconds: 200);
  static const notificationSlideIn = Duration(milliseconds: 240);
  static const notificationSlideOut = Duration(milliseconds: 180);
  static const notificationSwipe = Duration(milliseconds: 180);
  static const tabOverview = Duration(milliseconds: 300);
  static const tabSwipe = Duration(milliseconds: 220);
  static const downloadQualityPopup = Duration(milliseconds: 180);
}
