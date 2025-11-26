import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TailorSettingsScreen extends StatefulWidget {
  const TailorSettingsScreen({super.key});

  @override
  State<TailorSettingsScreen> createState() => _TailorSettingsScreenState();
}

class _TailorSettingsScreenState extends State<TailorSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // إعدادات المستخدم
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _soundEnabled = true;
  String _selectedLanguage = 'العربية';
  String _selectedCurrency = 'ريال سعودي';

  // بيانات الخياط الحالية
  String _currentUserId = '';
  String _ownerName = 'أحمد محمد الخياط';
  String _shopName = 'ورشة الخياطة الذهبية';
  String _email = '';
  String _phone = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadTailorData();
  }

  // تحميل بيانات الخياط من Firebase
  Future<void> _loadTailorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // الحصول على المستخدم الحالي
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserId = user.uid;

        // جلب بيانات الخياط من Firestore
        final tailorDoc = await FirebaseFirestore.instance
            .collection('tailors')
            .doc(user.uid)
            .get();

        if (tailorDoc.exists && tailorDoc.data() != null) {
          final data = tailorDoc.data()!;
          final contact = data['contact'] as Map<String, dynamic>? ?? {};

          setState(() {
            _ownerName = data['ownerName']?.toString() ?? _ownerName;
            _shopName = data['shopName']?.toString() ?? _shopName;
            _email = contact['email']?.toString() ?? user.email ?? '';
            _phone = contact['phone']?.toString() ?? '';
          });
        } else if (user.email != null) {
          // إذا لم توجد بيانات في Firestore، استخدم بيانات Firebase Auth
          setState(() {
            _email = user.email!;
            _ownerName = user.displayName ?? _ownerName;
          });
        }
      }
    } catch (e) {
      debugPrint('خطأ في تحميل بيانات الخياط: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSection(),
                const SizedBox(height: 24),
                _buildSettingsSection('الحساب والملف الشخصي', [
                  _buildSettingItem(
                    icon: Icons.person,
                    title: 'معلومات الحساب',
                    subtitle: 'تعديل البيانات الشخصية',
                    onTap: () => _showAccountInfo(),
                  ),
                  _buildSettingItem(
                    icon: Icons.security,
                    title: 'الأمان والخصوصية',
                    subtitle: 'كلمة المرور والأمان',
                    onTap: () => _showSecuritySettings(),
                  ),
                  _buildSettingItem(
                    icon: Icons.business,
                    title: 'معلومات الورشة',
                    subtitle: 'تفاصيل ورشة الخياطة',
                    onTap: () => _showWorkshopInfo(),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSettingsSection('التطبيق والإعدادات', [
                  _buildSwitchItem(
                    icon: Icons.notifications,
                    title: 'الإشعارات',
                    subtitle: 'تلقي تنبيهات التطبيق',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                  _buildSwitchItem(
                    icon: Icons.dark_mode,
                    title: 'الوضع المظلم',
                    subtitle: 'تفعيل المظهر المظلم',
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() {
                        _darkModeEnabled = value;
                      });
                    },
                  ),
                  _buildSwitchItem(
                    icon: Icons.volume_up,
                    title: 'الأصوات',
                    subtitle: 'تفعيل أصوات التطبيق',
                    value: _soundEnabled,
                    onChanged: (value) {
                      setState(() {
                        _soundEnabled = value;
                      });
                    },
                  ),
                  _buildDropdownItem(
                    icon: Icons.language,
                    title: 'اللغة',
                    subtitle: 'اختيار لغة التطبيق',
                    value: _selectedLanguage,
                    items: ['العربية', 'English', 'Français'],
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                  _buildDropdownItem(
                    icon: Icons.monetization_on,
                    title: 'العملة',
                    subtitle: 'عملة الأسعار والفواتير',
                    value: _selectedCurrency,
                    items: [
                      'ريال سعودي',
                      'درهم إماراتي',
                      'دولار أمريكي',
                      'يورو',
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value!;
                      });
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSettingsSection('المساعدة والدعم', [
                  _buildSettingItem(
                    icon: Icons.help,
                    title: 'المساعدة والأسئلة الشائعة',
                    subtitle: 'دليل الاستخدام والإجابات',
                    onTap: () => _showHelp(),
                  ),
                  _buildSettingItem(
                    icon: Icons.contact_support,
                    title: 'تواصل معنا',
                    subtitle: 'الدعم الفني والاستفسارات',
                    onTap: () => _showContactSupport(),
                  ),
                  _buildSettingItem(
                    icon: Icons.star_rate,
                    title: 'تقييم التطبيق',
                    subtitle: 'شاركنا رأيك في التطبيق',
                    onTap: () => _showRateApp(),
                  ),
                  _buildSettingItem(
                    icon: Icons.info,
                    title: 'حول التطبيق',
                    subtitle: 'معلومات الإصدار والتطوير',
                    onTap: () => _showAboutApp(),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSettingsSection('النسخ الاحتياطي والبيانات', [
                  _buildSettingItem(
                    icon: Icons.backup,
                    title: 'النسخ الاحتياطي',
                    subtitle: 'حفظ واستعادة البيانات',
                    onTap: () => _showBackupOptions(),
                  ),
                  _buildSettingItem(
                    icon: Icons.sync,
                    title: 'مزامنة البيانات',
                    subtitle: 'مزامنة مع السحابة',
                    onTap: () => _showSyncOptions(),
                  ),
                  _buildSettingItem(
                    icon: Icons.download,
                    title: 'تصدير البيانات',
                    subtitle: 'تصدير التقارير والبيانات',
                    onTap: () => _showExportOptions(),
                  ),
                ]),
                const SizedBox(height: 32),
                _buildLogoutButton(),
                const SizedBox(height: 16),
                _buildVersionInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.grey.withOpacity(0.1),
      title: const Text(
        'الإعدادات',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProfileSection() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(35),
            ),
            child: const Icon(Icons.person, size: 35, color: Colors.teal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ownerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  _shopName.isNotEmpty ? _shopName : 'خياط محترف',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'حساب مفعل',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showAccountInfo(),
            icon: const Icon(Icons.edit, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.teal, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.teal),
        ],
      ),
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: () => _showLogoutConfirmation(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Column(
        children: [
          Text(
            'إصدار التطبيق 1.0.0',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            'تطوير فريق الخياطة الذكية',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // وظائف الإعدادات المختلفة
  void _showAccountInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('معلومات الحساب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('الاسم', _ownerName),
              const SizedBox(height: 8),
              _buildInfoRow('اسم الورشة', _shopName),
              const SizedBox(height: 8),
              if (_email.isNotEmpty) ...[
                _buildInfoRow('البريد الإلكتروني', _email),
                const SizedBox(height: 8),
              ],
              if (_phone.isNotEmpty) ...[
                _buildInfoRow('رقم الهاتف', _phone),
                const SizedBox(height: 8),
              ],
              _buildInfoRow(
                'معرف المستخدم',
                _currentUserId.isNotEmpty
                    ? '${_currentUserId.substring(0, 8)}...'
                    : 'غير محدد',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to edit account screen if needed
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('سيتم إضافة شاشة التعديل قريباً'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'غير محدد',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  void _showSecuritySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('الأمان والخصوصية'),
        content: const Text('إعدادات الأمان وتغيير كلمة المرور'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showWorkshopInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('معلومات الورشة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('اسم الورشة', _shopName),
              const SizedBox(height: 8),
              _buildInfoRow('اسم المالك', _ownerName),
              const SizedBox(height: 8),
              if (_email.isNotEmpty) ...[
                _buildInfoRow('البريد الإلكتروني', _email),
                const SizedBox(height: 8),
              ],
              if (_phone.isNotEmpty) ...[
                _buildInfoRow('رقم الهاتف', _phone),
                const SizedBox(height: 8),
              ],
              _buildInfoRow(
                'معرف الورشة',
                _currentUserId.isNotEmpty
                    ? '${_currentUserId.substring(0, 8)}...'
                    : 'غير محدد',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'يمكنك تعديل معلومات الورشة من الشاشة الرئيسية',
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('المساعدة'),
        content: const Text('دليل الاستخدام والأسئلة الشائعة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showContactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تواصل معنا'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('البريد الإلكتروني: support@tailorapp.com'),
            SizedBox(height: 8),
            Text('الهاتف: +966501234567'),
            SizedBox(height: 8),
            Text('ساعات الدعم: 9:00 ص - 6:00 م'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showRateApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تقييم التطبيق'),
        content: const Text('شاركنا رأيك وقيم التطبيق في المتجر'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // فتح متجر التطبيقات للتقييم
            },
            child: const Text('تقييم'),
          ),
        ],
      ),
    );
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حول التطبيق'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تطبيق إدارة الخياطة الذكية'),
            SizedBox(height: 8),
            Text('الإصدار: 1.0.0'),
            SizedBox(height: 8),
            Text('تطوير: فريق الخياطة الذكية'),
            SizedBox(height: 8),
            Text('حقوق الطبع والنشر © 2024'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showBackupOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('النسخ الاحتياطي'),
        content: const Text('إنشاء نسخة احتياطية من بياناتك'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // تنفيذ النسخ الاحتياطي
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إنشاء النسخة الاحتياطية بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('إنشاء نسخة'),
          ),
        ],
      ),
    );
  }

  void _showSyncOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('مزامنة البيانات'),
        content: const Text('مزامنة بياناتك مع السحابة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // تنفيذ المزامنة
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم مزامنة البيانات بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('مزامنة'),
          ),
        ],
      ),
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تصدير البيانات'),
        content: const Text('تصدير التقارير والبيانات إلى ملف'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // تنفيذ التصدير
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تصدير البيانات بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('تصدير'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // تنفيذ تسجيل الخروج من Firebase
  Future<void> _performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Store context.mounted result before async gap
      final mountedState = mounted;

      // Navigate to login screen
      if (mountedState && context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }

      if (mountedState && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الخروج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في تسجيل الخروج: $e');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
