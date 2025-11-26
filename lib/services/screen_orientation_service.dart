import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// خدمة التحكم في تدوير الشاشة
class ScreenOrientationService {
  static const MethodChannel _channel = MethodChannel('screen_orientation');

  /// قفل الشاشة في الوضع العمودي
  static Future<void> lockToPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// قفل الشاشة في الوضع الأفقي
  static Future<void> lockToLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// السماح بجميع الأوضاع (عمودي وأفقي)
  static Future<void> allowAllOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// قفل الشاشة في الوضع العمودي فقط (بدون قلب)
  static Future<void> lockToPortraitUpOnly() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  /// قفل الشاشة في الوضع الأفقي الأيسر فقط
  static Future<void> lockToLandscapeLeftOnly() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
  }

  /// قفل الشاشة في الوضع الأفقي الأيمن فقط
  static Future<void> lockToLandscapeRightOnly() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// إخفاء شريط الحالة
  static Future<void> hideStatusBar() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
  }

  /// إظهار شريط الحالة
  static Future<void> showStatusBar() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  /// إخفاء شريط الحالة مع الاحتفاظ بشريط التنقل
  static Future<void> hideStatusBarOnly() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
  }

  /// إخفاء شريط التنقل مع الاحتفاظ بشريط الحالة
  static Future<void> hideNavigationBarOnly() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  /// إخفاء كامل للواجهة (شريط الحالة + شريط التنقل)
  static Future<void> hideSystemUI() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// إظهار كامل للواجهة
  static Future<void> showSystemUI() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  /// تعيين نمط شريط الحالة (فاتح/غامق)
  static void setStatusBarStyle({required bool isDark, Color? statusBarColor}) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor ?? Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  /// الحصول على الاتجاه الحالي للشاشة
  static Future<DeviceOrientation?> getCurrentOrientation() async {
    try {
      final String orientation = await _channel.invokeMethod('getOrientation');
      switch (orientation) {
        case 'portraitUp':
          return DeviceOrientation.portraitUp;
        case 'portraitDown':
          return DeviceOrientation.portraitDown;
        case 'landscapeLeft':
          return DeviceOrientation.landscapeLeft;
        case 'landscapeRight':
          return DeviceOrientation.landscapeRight;
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// تعيين اتجاه الشاشة بناءً على اسم الشاشة
  static Future<void> setOrientationForScreen(String screenName) async {
    switch (screenName.toLowerCase()) {
      case 'login':
      case 'dashboard':
      case 'fabrics':
      case 'orders':
      case 'settings':
        await lockToPortrait();
        break;
      case 'fabric_editor':
      case 'image_viewer':
      case 'maps':
        await allowAllOrientations();
        break;
      case 'video_player':
      case 'presentation':
        await lockToLandscape();
        break;
      default:
        await lockToPortrait();
    }
  }
}
