import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tailor_profile_screen.dart';
import 'manage_services_screen.dart';
import 'tailor_files_view_screen.dart'; // إضافة استيراد الصفحة الجديدة
import 'embroidery_list_screen.dart'; // إضافة استيراد صفحة قائمة الطريز

// نموذج بيانات الخياط
class TailorData {
  final String id;
  final String ownerName;
  final String shopName;
  final String email;
  final String phone;
  final bool isActive;
  final bool isVerified;
  final double rating;
  final int totalOrders;
  final String specialization;

  TailorData({
    required this.id,
    required this.ownerName,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.isVerified,
    required this.rating,
    required this.totalOrders,
    required this.specialization,
  });

  factory TailorData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // استخراج بيانات contact بشكل آمن
    Map<String, dynamic> contact = {};
    if (data['contact'] != null && data['contact'] is Map<String, dynamic>) {
      contact = data['contact'] as Map<String, dynamic>;
    }

    return TailorData(
      id: doc.id,
      ownerName: data['ownerName']?.toString() ?? 'خياط غير معروف',
      shopName: data['shopName']?.toString() ?? 'محل غير معروف',
      email: contact['email']?.toString() ?? data['email']?.toString() ?? '',
      phone: contact['phone']?.toString() ?? data['phone']?.toString() ?? '',
      isActive: data['isActive'] ?? true,
      isVerified: data['isVerified'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalOrders: data['totalOrders'] ?? 0,
      specialization: data['specialization']?.toString() ?? '',
    );
  }
}

// نموذج بيانات الطلب
class OrderData {
  final String id;
  final String customerName;
  final String status;
  final double totalAmount;
  final DateTime createdAt;
  final String serviceType;

  OrderData({
    required this.id,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.serviceType,
  });

  factory OrderData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return OrderData(
      id: doc.id,
      customerName: data['customerName']?.toString() ?? 'عميل غير معروف',
      status: data['status']?.toString() ?? 'pending',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      serviceType: data['serviceType']?.toString() ?? 'خياطة عامة',
    );
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// نموذج بيانات الإحصائيات
class DashboardStats {
  final int newOrders;
  final int inProgressOrders;
  final int completedToday;
  final int totalCustomers;
  final double todayRevenue;
  final double monthlyRevenue;

  DashboardStats({
    required this.newOrders,
    required this.inProgressOrders,
    required this.completedToday,
    required this.totalCustomers,
    required this.todayRevenue,
    required this.monthlyRevenue,
  });
}

class TailorDashboardScreen extends StatefulWidget {
  const TailorDashboardScreen({super.key});

  @override
  State<TailorDashboardScreen> createState() => _TailorDashboardScreenState();
}

class _TailorDashboardScreenState extends State<TailorDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // بيانات الخياط والإحصائيات
  TailorData? _tailorData;
  DashboardStats? _dashboardStats;
  List<OrderData> _recentOrders = [];
  bool _isLoading = true;
  String? _currentTailorId;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  Future<void> _initializeData() async {
    try {
      // تحديد معرف الخياط الحالي
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        _currentTailorId = currentUser.uid;
      } else {
        // استخدام معرف ثابت للاختبار
        _currentTailorId = 'i3ZSdx5x4FOuOOnChsw1HtvpoGy2';
      }

      if (_currentTailorId != null) {
        await _loadTailorData();
        await _loadDashboardStats();
        await _loadRecentOrders();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTailorData() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('tailors')
          .doc(_currentTailorId)
          .get();

      if (doc.exists) {
        setState(() {
          _tailorData = TailorData.fromFirestore(doc);
        });
      }
    } catch (e) {
      print('خطأ في تحميل بيانات الخياط: $e');
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime startOfMonth = DateTime(now.year, now.month, 1);

      // جلب الطلبات الجديدة
      QuerySnapshot newOrdersSnapshot = await _firestore
          .collection('tailors')
          .doc(_currentTailorId)
          .collection('orders')
          .where('status', isEqualTo: 'pending')
          .get();

      // جلب الطلبات قيد التنفيذ
      QuerySnapshot inProgressSnapshot = await _firestore
          .collection('tailors')
          .doc(_currentTailorId)
          .collection('orders')
          .where('status', isEqualTo: 'in_progress')
          .get();

      // جلب الطلبات المكتملة اليوم
      QuerySnapshot completedTodaySnapshot = await _firestore
          .collection('tailors')
          .doc(_currentTailorId)
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .where(
            'updatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .get();

      // جلب إجمالي العملاء (عملاء فريدين)
      QuerySnapshot allOrdersSnapshot = await _firestore
          .collection('tailors')
          .doc(_currentTailorId)
          .collection('orders')
          .get();

      Set<String> uniqueCustomers = {};
      double todayRevenue = 0.0;
      double monthlyRevenue = 0.0;

      for (var doc in allOrdersSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // إضافة العميل للقائمة الفريدة
        if (data['customerId'] != null) {
          uniqueCustomers.add(data['customerId'].toString());
        }

        // حساب الإيرادات
        if (data['status'] == 'completed' && data['totalAmount'] != null) {
          double amount = (data['totalAmount'] as num).toDouble();

          // إيرادات اليوم
          if (data['updatedAt'] != null) {
            DateTime orderDate = (data['updatedAt'] as Timestamp).toDate();
            if (orderDate.isAfter(startOfDay)) {
              todayRevenue += amount;
            }
            if (orderDate.isAfter(startOfMonth)) {
              monthlyRevenue += amount;
            }
          }
        }
      }

      setState(() {
        _dashboardStats = DashboardStats(
          newOrders: newOrdersSnapshot.docs.length,
          inProgressOrders: inProgressSnapshot.docs.length,
          completedToday: completedTodaySnapshot.docs.length,
          totalCustomers: uniqueCustomers.length,
          todayRevenue: todayRevenue,
          monthlyRevenue: monthlyRevenue,
        );
      });
    } catch (e) {
      print('خطأ في تحميل الإحصائيات: $e');
      // إنشاء إحصائيات افتراضية في حالة الخطأ
      setState(() {
        _dashboardStats = DashboardStats(
          newOrders: 0,
          inProgressOrders: 0,
          completedToday: 0,
          totalCustomers: 0,
          todayRevenue: 0.0,
          monthlyRevenue: 0.0,
        );
      });
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('tailors')
          .doc(_currentTailorId)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      setState(() {
        _recentOrders = snapshot.docs
            .map((doc) => OrderData.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('خطأ في تحميل الطلبات الحديثة: $e');
      setState(() {
        _recentOrders = [];
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _initializeData();
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإشعارات'),
        content: const Text('لا توجد إشعارات جديدة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ميزة $feature قريباً...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final verticalPadding = isSmallScreen ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingWidget()
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeSection(),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          _buildStatsSection(),
                          SizedBox(height: isSmallScreen ? 20 : 32),
                          _buildQuickActionsSection(),
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          _buildRecentOrdersSection(),
                          SizedBox(height: isSmallScreen ? 16 : 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 16),
          Text('جاري تحميل البيانات...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.grey.withOpacity(0.1),
      title: const Text(
        'لوحة تحكم الخياط',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.black54,
                size: 24,
              ),
              onPressed: () {
                _showNotifications();
              },
            ),
            if (_dashboardStats != null && _dashboardStats!.newOrders > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    '${_dashboardStats!.newOrders}',
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(
            Icons.account_circle,
            color: Colors.black54,
            size: 24,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TailorProfileScreen(tailorId: _currentTailorId),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    String welcomeMessage = 'مرحبًا بك 👋';
    String subMessage = 'لا توجد طلبات جديدة';

    if (_tailorData != null) {
      welcomeMessage = 'مرحبًا بك، ${_tailorData!.ownerName} 👋';
    }

    if (_dashboardStats != null && _dashboardStats!.newOrders > 0) {
      subMessage =
          'لديك ${_dashboardStats!.newOrders} طلب${_dashboardStats!.newOrders == 1 ? '' : 'ات'} جديد${_dashboardStats!.newOrders == 1 ? '' : 'ة'} تحتاج إلى مراجعة';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00695C), Color(0xFF26A69A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      welcomeMessage,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    if (_tailorData != null &&
                        _tailorData!.shopName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _tailorData!.shopName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.content_cut, size: 60, color: Colors.white24),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/orders');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'عرض الطلبات',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_dashboardStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات سريعة',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            double childAspectRatio = constraints.maxWidth > 600 ? 1.3 : 1.2;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isSmallScreen ? 8 : 12,
              mainAxisSpacing: isSmallScreen ? 8 : 12,
              childAspectRatio: childAspectRatio,
              children: [
                _buildStatCard(
                  title: 'طلبات جديدة',
                  count: _dashboardStats!.newOrders,
                  icon: Icons.assignment_turned_in_outlined,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: 'قيد التنفيذ',
                  count: _dashboardStats!.inProgressOrders,
                  icon: Icons.hourglass_empty,
                  color: Colors.orange,
                ),
                _buildStatCard(
                  title: 'مكتملة اليوم',
                  count: _dashboardStats!.completedToday,
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                _buildStatCard(
                  title: 'إجمالي العملاء',
                  count: _dashboardStats!.totalCustomers,
                  icon: Icons.people_outline,
                  color: Colors.purple,
                ),
              ],
            );
          },
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        // إضافة بطاقات الإيرادات
        isSmallScreen
            ? Column(
                children: [
                  _buildRevenueCard(
                    title: 'إيرادات اليوم',
                    amount: _dashboardStats!.todayRevenue,
                    icon: Icons.today,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildRevenueCard(
                    title: 'إيرادات الشهر',
                    amount: _dashboardStats!.monthlyRevenue,
                    icon: Icons.calendar_month,
                    color: Colors.teal,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildRevenueCard(
                      title: 'إيرادات اليوم',
                      amount: _dashboardStats!.todayRevenue,
                      icon: Icons.today,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRevenueCard(
                      title: 'إيرادات الشهر',
                      amount: _dashboardStats!.monthlyRevenue,
                      icon: Icons.calendar_month,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              Text(
                'ريال',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوصول السريع',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 600 ? 6 : 3;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isSmallScreen ? 8 : 12,
              mainAxisSpacing: isSmallScreen ? 8 : 12,
              childAspectRatio: 1.0,
              children: [
                _buildMenuButton(
                  context,
                  title: 'الخدمات',
                  icon: Icons.design_services,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageServicesScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context,
                  title: 'الطلبات',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pushNamed(context, '/orders');
                  },
                ),
                _buildMenuButton(
                  context,
                  title: 'الطريز',
                  icon: Icons.auto_awesome,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmbroideryListScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuButton(
                  context,
                  title: 'الألوان',
                  icon: Icons.palette,
                  color: Colors.pink,
                  onTap: () {
                    // التعديل الجديد: فتح صفحة عرض ملفات الخياط
                    if (_currentTailorId != null && _tailorData != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TailorFilesViewScreen(
                            tailorId: _currentTailorId!,
                            tailorName: _tailorData!.shopName.isNotEmpty
                                ? _tailorData!.shopName
                                : _tailorData!.ownerName,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('خطأ: لا يمكن تحديد معرف الخياط'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                _buildMenuButton(
                  context,
                  title: 'الخامات',
                  icon: Icons.cut,
                  color: Colors.brown,
                  onTap: () {
                    Navigator.pushNamed(context, '/fabrics');
                  },
                ),
                _buildMenuButton(
                  context,
                  title: 'العملاء',
                  icon: Icons.group,
                  color: Colors.blueGrey,
                  onTap: () {
                    _showComingSoon('العملاء');
                  },
                ),
                _buildMenuButton(
                  context,
                  title: 'التقارير',
                  icon: Icons.bar_chart,
                  color: Colors.indigo,
                  onTap: () {
                    _showComingSoon('التقارير');
                  },
                ),
                _buildMenuButton(
                  context,
                  title: 'الإعدادات',
                  icon: Icons.settings,
                  color: Colors.grey[700]!,
                  onTap: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrdersSection() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الطلبات الحديثة',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/orders');
              },
              child: Text(
                'عرض الكل',
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        _recentOrders.isEmpty
            ? _buildEmptyOrdersWidget()
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(_recentOrders[index]);
                },
              ),
      ],
    );
  }

  Widget _buildEmptyOrdersWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات حديثة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر الطلبات الجديدة هنا',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderData order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: order.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getOrderIcon(order.status),
              color: order.statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  order.serviceType,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(order.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: order.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.statusText,
                  style: TextStyle(
                    fontSize: 10,
                    color: order.statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${order.totalAmount.toStringAsFixed(0)} ريال',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getOrderIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.work_outline;
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
