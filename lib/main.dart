import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/screen_orientation_service.dart';

// استيراد الشاشات
import 'screens/tailor_login_screen.dart';
import 'screens/tailor_dashboard_screen.dart';
import 'screens/tailor_orders_screen.dart';
import 'screens/manage_fabrics_modern_screen.dart'; // ✨ شاشة الخامات الحديثة
import 'screens/manage_embroidery_screen.dart';
import 'screens/tailor_settings_screen.dart';
import 'screens/embroidery_list_screen.dart'; // ✅ شاشة عرض التطريزات

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تهيئة تدوير الشاشة - قفل في الوضع العمودي افتراضياً
  await ScreenOrientationService.lockToPortrait();

  // تعيين نمط شريط الحالة
  ScreenOrientationService.setStatusBarStyle(
    isDark: false,
    statusBarColor: Colors.transparent,
  );

  runApp(const ThobiTailorApp());
}

class ThobiTailorApp extends StatelessWidget {
  const ThobiTailorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thobi Tailor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Cairo', // تأكد من إضافة الخط في pubspec.yaml
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const TailorLoginScreen(),
        '/login': (context) => const TailorLoginScreen(), // ✅ إضافة مسار /login
        '/dashboard': (context) => const TailorDashboardScreen(),
        '/orders': (context) => const TailorOrdersScreen(),
        '/fabrics': (context) => const ManageFabricsModernScreen(),
        '/embroidery': (context) => const ManageEmbroideryScreen(),
        '/embroidery_list': (context) =>
            const EmbroideryListScreen(), // ✅ تمت الإضافة هنا
        '/settings': (context) => const TailorSettingsScreen(),
      },

      // ✅ إضافة معالج للمسارات غير المعرفة لتجنب الأخطاء
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const NotFoundScreen());
      },

      // ✅ إضافة معالج إنشاء المسارات للمرونة الإضافية
      onGenerateRoute: (settings) {
        // طباعة المسار المطلوب للتشخيص
        print('المسار المطلوب: ${settings.name}');

        switch (settings.name) {
          case '/':
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const TailorLoginScreen(),
            );
          case '/dashboard':
            return MaterialPageRoute(
              builder: (context) => const TailorDashboardScreen(),
            );
          case '/orders':
            return MaterialPageRoute(
              builder: (context) => const TailorOrdersScreen(),
            );
          case '/fabrics':
            return MaterialPageRoute(
              builder: (context) =>
                  const ManageFabricsModernScreen(), // ✨ استخدام الشاشة الحديثة
            );
          case '/embroidery':
            return MaterialPageRoute(
              builder: (context) => const ManageEmbroideryScreen(),
            );
          case '/embroidery_list':
            return MaterialPageRoute(
              builder: (context) => const EmbroideryListScreen(),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (context) => const TailorSettingsScreen(),
            );
          default:
            // في حالة عدم وجود المسار، العودة لصفحة تسجيل الدخول
            print(
              'مسار غير معروف: ${settings.name}، العودة لصفحة تسجيل الدخول',
            );
            return MaterialPageRoute(
              builder: (context) => const TailorLoginScreen(),
            );
        }
      },
    );
  }
}

// ✅ صفحة خطأ 404 للمسارات غير الموجودة
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('صفحة غير موجودة'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة الخطأ
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: isSmallScreen ? 60 : 80,
                    color: Colors.red,
                  ),
                ),

                SizedBox(height: isSmallScreen ? 24 : 32),

                // عنوان الخطأ
                Text(
                  'الصفحة غير موجودة',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isSmallScreen ? 12 : 16),

                // وصف الخطأ
                Text(
                  'عذراً، لم يتم العثور على الصفحة المطلوبة.\nيرجى التحقق من الرابط أو العودة للصفحة الرئيسية.',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isSmallScreen ? 24 : 32),

                // أزرار الإجراءات
                isSmallScreen
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('العودة'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal,
                                side: const BorderSide(color: Colors.teal),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  Navigator.pushReplacementNamed(context, '/'),
                              icon: const Icon(Icons.home),
                              label: const Text('الصفحة الرئيسية'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // زر العودة للخلف
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('العودة'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // زر الصفحة الرئيسية
                          ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.pushReplacementNamed(context, '/'),
                            icon: const Icon(Icons.home),
                            label: const Text('الصفحة الرئيسية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
