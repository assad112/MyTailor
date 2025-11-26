// lib/screens/tailor_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TailorOrdersScreen extends StatefulWidget {
  const TailorOrdersScreen({super.key});

  @override
  State<TailorOrdersScreen> createState() => _TailorOrdersScreenState();
}

class _TailorOrdersScreenState extends State<TailorOrdersScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedFilter = 'all';
  bool _isLoading = false;

  final String? _tailorId = FirebaseAuth.instance.currentUser?.uid;

  // تسميات الحالات
  final Map<String, String> _statusLabels = {
    'pending_payment': 'بانتظار الدفع',
    'pending': 'في الانتظار',
    'confirmed': 'مؤكدة',
    'in_progress': 'قيد التنفيذ',
    'ready': 'جاهزة للاستلام',
    'completed': 'مكتملة',
    'cancelled': 'ملغية',
    'rejected': 'مرفوضة',
  };

  // ألوان/تدرجات الحالات
  final Map<String, List<Color>> _statusGradients = {
    'pending_payment': [Color(0xFF607D8B), Color(0xFF455A64)],
    'pending': [Color(0xFF2196F3), Color(0xFF1976D2)],
    'confirmed': [Color(0xFFFF9800), Color(0xFFF57C00)],
    'in_progress': [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
    'ready': [Color(0xFF009688), Color(0xFF00695C)],
    'completed': [Color(0xFF4CAF50), Color(0xFF388E3C)],
    'cancelled': [Color(0xFFF44336), Color(0xFFD32F2F)],
    'rejected': [Color(0xFF795548), Color(0xFF5D4037)],
  };

  // خيارات الفلتر
  final List<Map<String, dynamic>> _filterOptions = [
    {'key': 'all', 'label': 'جميع الطلبات', 'icon': Icons.list_alt},
    {
      'key': 'pending_payment',
      'label': 'بانتظار الدفع',
      'icon': Icons.payments_outlined,
    },
    {'key': 'pending', 'label': 'في الانتظار', 'icon': Icons.pending},
    {'key': 'confirmed', 'label': 'مؤكدة', 'icon': Icons.check_circle_outline},
    {'key': 'in_progress', 'label': 'قيد التنفيذ', 'icon': Icons.work_outline},
    {'key': 'ready', 'label': 'جاهزة', 'icon': Icons.done_all},
    {'key': 'completed', 'label': 'مكتملة', 'icon': Icons.check_circle},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String _getStatusLabel(String status) => _statusLabels[status] ?? 'غير معروف';

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_payment':
        return Icons.payments_outlined;
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'in_progress':
        return Icons.work_outline;
      case 'ready':
        return Icons.done_all;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.info_outline;
    }
  }

  List<Color> _getStatusGradient(String status) =>
      _statusGradients[status] ?? [Colors.grey, Colors.grey.shade700];

  // تحويل آمن للتواريخ
  DateTime? _safeParseDate(dynamic v) {
    if (v == null) return null;
    try {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {}
    return null;
  }

  String _formatDate(DateTime? d) => d == null
      ? 'غير محدد'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(DateTime? d) => d == null
      ? 'غير محدد'
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _updateOrderStatus(
    String orderId,
    String newStatus,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    setState(() => _isLoading = true);
    try {
      await ref.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث حالة الطلب إلى ${_getStatusLabel(newStatus)}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الطلب: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStatusUpdateDialog(
    String orderId,
    String currentStatus,
    DocumentReference<Map<String, dynamic>> orderRef,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تحديث حالة الطلب', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _statusLabels.entries
                .where((e) => e.key != currentStatus)
                .map(
                  (e) => ListTile(
                    leading: Icon(_getStatusIcon(e.key)),
                    title: Text(e.value),
                    onTap: () {
                      Navigator.pop(context);
                      _updateOrderStatus(orderId, e.key, orderRef);
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(
    String orderId,
    Map<String, dynamic> data,
    DocumentReference<Map<String, dynamic>> orderRef,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOrderDetailsSheet(orderId, data, orderRef),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tailorId == null) {
      return _buildAuthErrorScreen();
    }

    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildFilterChips(isSmallScreen)),
          _buildOrdersList(isSmallScreen),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildAuthErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'يجب تسجيل الدخول أولاً',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'الرجاء تسجيل الدخول لعرض طلباتك',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.login),
              label: const Text('تسجيل الدخول'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'طلباتي',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(Icons.assignment, size: 60, color: Colors.white24),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildFilterChips(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 55 : 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 10 : 12,
        ),
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter['key'];
          return Container(
            margin: EdgeInsets.only(right: isSmallScreen ? 6 : 8),
            child: FilterChip(
              selected: isSelected,
              onSelected: (_) =>
                  setState(() => _selectedFilter = filter['key']),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1565C0),
              elevation: isSelected ? 4 : 1,
              shadowColor: Colors.black26,
              label: Text(
                filter['label'],
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 13,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
              avatar: Icon(
                filter['icon'],
                size: isSmallScreen ? 16 : 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1565C0)
                      : Colors.grey[300]!,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// استعلام collectionGroup + فرز من الخادم بالأحدث تحديثًا
  Stream<QuerySnapshot<Map<String, dynamic>>> _getOrdersStream() {
    Query<Map<String, dynamic>> q = _firestore
        .collectionGroup('orders')
        .where('tailorId', isEqualTo: _tailorId);

    if (_selectedFilter != 'all') {
      q = q.where('status', isEqualTo: _selectedFilter);
    }

    // الفرز من الخادم: الأحدث أولًا
    q = q.orderBy('updatedAt', descending: true);

    return q.snapshots();
  }

  SliverToBoxAdapter _buildOrdersList(bool isSmallScreen) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _getOrdersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              // لا نستخدم فرز محلي بعد الآن
              final orders = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                ),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data();
                  return _buildOrderCard(
                    doc.id,
                    data,
                    index,
                    doc.reference,
                    isSmallScreen,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    String orderId,
    Map<String, dynamic> data,
    int index,
    DocumentReference<Map<String, dynamic>> orderRef,
    bool isSmallScreen,
  ) {
    final status = (data['status'] as String?) ?? 'pending_payment';
    final orderDate = _safeParseDate(data['updatedAt'] ?? data['createdAt']);

    final serviceName = (data['serviceName'] as String?) ?? 'غير محدد';
    final clientName = (data['clientName'] as String?) ?? 'غير محدد';

    final qty = (data['qty'] as num?)?.toDouble() ?? 0.0;
    final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final subtotalRaw = (data['subtotal'] as num?)?.toDouble();
    final currency = (data['currency'] as String?) ?? 'OMR';
    final totalAmount = subtotalRaw ?? (qty * unitPrice);

    final statusGradient = _getStatusGradient(status);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showOrderDetails(orderId, data, orderRef),
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // رأس البطاقة
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'طلب #${orderId.substring(0, 8)}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 2 : 4),
                                  Text(
                                    _formatDate(orderDate),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 11 : 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 8 : 12,
                                vertical: isSmallScreen ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: statusGradient,
                                ),
                                borderRadius: BorderRadius.circular(
                                  isSmallScreen ? 16 : 20,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(status),
                                    size: isSmallScreen ? 14 : 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: isSmallScreen ? 3 : 4),
                                  Text(
                                    _getStatusLabel(status),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 10 : 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: isSmallScreen ? 12 : 16),

                        // معلومات العميل والخدمة
                        isSmallScreen
                            ? Column(
                                children: [
                                  _buildInfoItem(
                                    Icons.person_outline,
                                    'العميل',
                                    clientName,
                                    isSmallScreen,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoItem(
                                    Icons.design_services_outlined,
                                    'الخدمة',
                                    serviceName,
                                    isSmallScreen,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoItem(
                                      Icons.person_outline,
                                      'العميل',
                                      clientName,
                                      isSmallScreen,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInfoItem(
                                      Icons.design_services_outlined,
                                      'الخدمة',
                                      serviceName,
                                      isSmallScreen,
                                    ),
                                  ),
                                ],
                              ),

                        SizedBox(height: isSmallScreen ? 12 : 12),

                        // الكمية/الإجمالي
                        isSmallScreen
                            ? Column(
                                children: [
                                  _buildInfoItem(
                                    Icons.numbers_outlined,
                                    'الكمية',
                                    qty == 0
                                        ? '-'
                                        : qty.toStringAsFixed(
                                            qty == qty.roundToDouble() ? 0 : 2,
                                          ),
                                    isSmallScreen,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoItem(
                                    Icons.attach_money,
                                    'الإجمالي',
                                    '${totalAmount.toStringAsFixed(2)} ${currency == "OMR" ? "ر.ع" : currency}',
                                    isSmallScreen,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoItem(
                                      Icons.numbers_outlined,
                                      'الكمية',
                                      qty == 0
                                          ? '-'
                                          : qty.toStringAsFixed(
                                              qty == qty.roundToDouble()
                                                  ? 0
                                                  : 2,
                                            ),
                                      isSmallScreen,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInfoItem(
                                      Icons.attach_money,
                                      'الإجمالي',
                                      '${totalAmount.toStringAsFixed(2)} ${currency == "OMR" ? "ر.ع" : currency}',
                                      isSmallScreen,
                                    ),
                                  ),
                                ],
                              ),

                        SizedBox(height: isSmallScreen ? 12 : 16),

                        // أزرار
                        isSmallScreen
                            ? Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showOrderDetails(
                                        orderId,
                                        data,
                                        orderRef,
                                      ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('عرض التفاصيل'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF1565C0,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF1565C0),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _showStatusUpdateDialog(
                                              orderId,
                                              status,
                                              orderRef,
                                            ),
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                            ),
                                      label: const Text('تحديث الحالة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1565C0,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showOrderDetails(
                                        orderId,
                                        data,
                                        orderRef,
                                      ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('عرض التفاصيل'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF1565C0,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF1565C0),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _showStatusUpdateDialog(
                                              orderId,
                                              status,
                                              orderRef,
                                            ),
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                      label: const Text('تحديث الحالة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1565C0,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value,
    bool isSmallScreen,
  ) {
    return Row(
      children: [
        Icon(icon, size: isSmallScreen ? 14 : 16, color: Colors.grey[600]),
        SizedBox(width: isSmallScreen ? 4 : 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailsSheet(
    String orderId,
    Map<String, dynamic> data,
    DocumentReference<Map<String, dynamic>> orderRef,
  ) {
    final createdAt = _safeParseDate(data['createdAt']);
    final updatedAt = _safeParseDate(data['updatedAt']);
    final status = (data['status'] as String?) ?? 'pending_payment';

    // معلومات العميل
    final customerName = (data['customerName'] as String?) ?? 'غير محدد';
    final customerPhone = (data['customerPhone'] as String?) ?? '';

    // معلومات الخياط
    final tailorName = (data['tailorName'] as String?) ?? '';
    final tailorId = (data['tailorId'] as String?) ?? '';

    // معلومات القماش
    final fabricName = (data['fabricName'] as String?) ?? '';
    final fabricType = (data['fabricType'] as String?) ?? '';
    final fabricImageUrl = (data['fabricImageUrl'] as String?) ?? '';

    // معلومات اللون
    final colorName = (data['colorName'] as String?) ?? '';
    final colorHex = (data['colorHex'] as String?) ?? '';

    // الخدمة
    final serviceName = (data['serviceName'] as String?) ?? 'غير محدد';
    final mode = (data['mode'] as String?) ?? '';

    // السعر
    final qty = (data['qty'] as num?)?.toDouble() ?? 0.0;
    final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final subtotalRaw = (data['subtotal'] as num?)?.toDouble();
    final currency = (data['currency'] as String?) ?? 'OMR';
    final totalAmount = subtotalRaw ?? (qty * unitPrice);

    // المقاسات
    final measurements = (data['measurements'] as Map<String, dynamic>?) ?? {};

    // الملاحظات
    final notes = (data['notes'] as String?) ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'تفاصيل الطلب',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات العميل
                  _buildDetailSection('👤 معلومات العميل', [
                    _buildDetailRow('الاسم', customerName),
                    _buildDetailRow(
                      'الهاتف',
                      customerPhone.isEmpty ? '-' : customerPhone,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // معلومات الخياط
                  _buildDetailSection('✂️ معلومات الخياط', [
                    _buildDetailRow(
                      'الاسم',
                      tailorName.isEmpty ? 'غير محدد' : tailorName,
                    ),
                    _buildDetailRow(
                      'المعرف',
                      tailorId.isEmpty ? '-' : tailorId.substring(0, 12),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // معلومات القماش
                  if (fabricName.isNotEmpty ||
                      fabricType.isNotEmpty ||
                      fabricImageUrl.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🧵 معلومات القماش',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (fabricImageUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      fabricImageUrl,
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              height: 150,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              _buildDetailRow(
                                'الاسم',
                                fabricName.isEmpty ? '-' : fabricName,
                              ),
                              _buildDetailRow(
                                'النوع',
                                fabricType.isEmpty ? '-' : fabricType,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (fabricName.isNotEmpty ||
                      fabricType.isNotEmpty ||
                      fabricImageUrl.isNotEmpty)
                    const SizedBox(height: 20),

                  // معلومات اللون
                  if (colorName.isNotEmpty || colorHex.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎨 معلومات اللون',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              if (colorHex.isNotEmpty)
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                        colorHex.replaceFirst('#', '0xFF'),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow(
                                      'الاسم',
                                      colorName.isEmpty ? '-' : colorName,
                                    ),
                                    _buildDetailRow(
                                      'Hex Code',
                                      colorHex.isEmpty
                                          ? '-'
                                          : colorHex.toUpperCase(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (colorName.isNotEmpty || colorHex.isNotEmpty)
                    const SizedBox(height: 20),

                  // الخدمة والدفع
                  _buildDetailSection('📋 الخدمة والدفع', [
                    _buildDetailRow('الخدمة', serviceName),
                    if (mode.isNotEmpty) _buildDetailRow('طريقة التلوين', mode),
                    if (qty > 0)
                      _buildDetailRow(
                        'الكمية',
                        qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2),
                      ),
                    if (unitPrice > 0)
                      _buildDetailRow(
                        'سعر الوحدة',
                        '${unitPrice.toStringAsFixed(2)} ${currency == 'OMR' ? 'ر.ع' : currency}',
                      ),
                    _buildDetailRow(
                      'الإجمالي',
                      '${totalAmount.toStringAsFixed(2)} ${currency == 'OMR' ? 'ر.ع' : currency}',
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // المقاسات
                  if (measurements.isNotEmpty)
                    _buildDetailSection(
                      '📏 المقاسات',
                      _buildMeasurementsList(measurements),
                    ),
                  if (measurements.isNotEmpty) const SizedBox(height: 20),

                  // الملاحظات
                  if (notes.isNotEmpty)
                    _buildDetailSection('📝 الملاحظات', [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          notes,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ]),
                  if (notes.isNotEmpty) const SizedBox(height: 20),

                  // معلومات إضافية
                  _buildDetailSection('ℹ️ معلومات الطلب', [
                    _buildDetailRow('رقم الطلب', '#${orderId.substring(0, 8)}'),
                    _buildDetailRow('الحالة', _getStatusLabel(status)),
                    _buildDetailRow('تاريخ الإنشاء', _formatDate(createdAt)),
                    if (updatedAt != null)
                      _buildDetailRow('آخر تحديث', _formatDate(updatedAt)),
                    _buildDetailRow(
                      'الوقت',
                      _formatTime(updatedAt ?? createdAt),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // actions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('إغلاق'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showStatusUpdateDialog(orderId, status, orderRef);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('تحديث الحالة'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMeasurementsList(Map<String, dynamic> m) {
    final entries = m.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => _buildDetailRow(e.key.replaceAll('_', ' '), '${e.value}'))
        .toList();
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // حالات "تحميل/خطأ/فارغ/لا نتائج" بدون ارتفاعات ثابتة
  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الطلبات...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'حدث خطأ في تحميل الطلبات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'لا توجد طلبات حالياً',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'ستظهر طلباتك هنا عندما يقوم العملاء بطلب خدماتك',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => setState(() {}),
      backgroundColor: const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.refresh),
      label: const Text('تحديث', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
