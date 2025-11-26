import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import '../models/fabric_model.dart';
import '../services/screen_orientation_service.dart';
import '../widgets/optimized_image_widget.dart';
import 'modern_fabric_editor_screen.dart';

/// ============================================================================
/// 🎨 شاشة إدارة الخامات المحسّنة والعصرية
/// ============================================================================

class ManageFabricsModernScreen extends StatefulWidget {
  const ManageFabricsModernScreen({super.key});

  @override
  State<ManageFabricsModernScreen> createState() =>
      _ManageFabricsModernScreenState();
}

class _ManageFabricsModernScreenState extends State<ManageFabricsModernScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Fabric> _fabrics = [];
  bool _isLoading = true;

  User? _currentUser;
  bool _isAdmin = false;
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();

    // تعيين تدوير الشاشة للخامات (عمودي مع إمكانية أفقي للصور)
    ScreenOrientationService.setOrientationForScreen('fabrics');

    _initializeFirebase();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      await _checkCurrentUser();
      _loadFabrics();
    } catch (e) {
      debugPrint('خطأ في تهيئة Firebase: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkCurrentUser() async {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      _showLoginDialog();
      return;
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _isAdmin = userData['role'] == 'admin';
        _currentUserName =
            userData['name'] ?? _currentUser!.displayName ?? 'مستخدم';
      } else {
        _currentUserName = _currentUser!.displayName ?? 'مستخدم';
      }
    } catch (e) {
      debugPrint('خطأ في جلب بيانات المستخدم: $e');
      _currentUserName = _currentUser!.displayName ?? 'مستخدم';
    }
  }

  void _loadFabrics() {
    if (_currentUser == null) return;

    // جلب جميع الخامات أولاً
    _firestore
        .collection('fabrics')
        .snapshots()
        .listen(
          (snapshot) {
            setState(() {
              List<Fabric> allFabrics = snapshot.docs
                  .map((doc) => Fabric.fromMap(doc.data(), doc.id))
                  .toList();

              // فلترة الخامات حسب الصلاحيات
              if (_isAdmin) {
                // الأدمن يرى جميع الخامات
                _fabrics = allFabrics;
              } else {
                // الخياط يرى خاماته فقط + الخامات القديمة بدون createdBy
                _fabrics = allFabrics.where((fabric) {
                  return fabric.createdBy == _currentUser!.uid ||
                      fabric.createdBy.isEmpty;
                }).toList();
              }

              _fabrics.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
              _isLoading = false;
            });
          },
          onError: (error) {
            debugPrint('خطأ في جلب البيانات: $error');
            setState(() => _isLoading = false);
            _showErrorSnackBar('خطأ في جلب البيانات من الخادم');
          },
        );
  }

  Future<void> _addFabricToFirebase(Fabric fabric) async {
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('يجب تسجيل الدخول أولاً');
        return;
      }
      final fabricWithUser = fabric.copyWith(
        lastUpdated: DateTime.now(),
        createdBy: _currentUser!.uid,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('fabrics').add(fabricWithUser.toMap());
      _showSuccessSnackBar('✅ تم إضافة الخامة بنجاح');
    } catch (e) {
      debugPrint('خطأ في إضافة الخامة: $e');
      _showErrorSnackBar('خطأ في إضافة الخامة: $e');
    }
  }

  Future<void> _updateFabricInFirebase(Fabric fabric) async {
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('يجب تسجيل الدخول أولاً');
        return;
      }
      final updated = fabric.copyWith(lastUpdated: DateTime.now());
      await _firestore
          .collection('fabrics')
          .doc(fabric.id)
          .update(updated.toMap());
      _showSuccessSnackBar('✅ تم تعديل الخامة بنجاح');
    } catch (e) {
      debugPrint('خطأ في تعديل الخامة: $e');
      _showErrorSnackBar('خطأ في تعديل الخامة: $e');
    }
  }

  Future<void> _deleteFabricFromFirebase(String fabricId) async {
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('يجب تسجيل الدخول أولاً');
        return;
      }
      final fabric = _fabrics.firstWhere((f) => f.id == fabricId);
      await _firestore.collection('fabrics').doc(fabricId).delete();
      if ((fabric.imageUrl ?? '').isNotEmpty) {
        try {
          final ref = firebase_storage.FirebaseStorage.instance.refFromURL(
            fabric.imageUrl!,
          );
          await ref.delete();
        } catch (_) {}
      }
      _showSuccessSnackBar('🗑️ تم حذف الخامة بنجاح');
    } catch (e) {
      debugPrint('خطأ في حذف الخامة: $e');
      _showErrorSnackBar('خطأ في حذف الخامة: $e');
    }
  }

  void _showLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('تسجيل الدخول'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        _showErrorSnackBar('يرجى ملء جميع الحقول');
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      try {
                        await _auth.signInWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                        Navigator.pop(context);
                        await _checkCurrentUser();
                        _loadFabrics();
                      } catch (e) {
                        _showErrorSnackBar(
                          'خطأ في تسجيل الدخول: ${e.toString()}',
                        );
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('تسجيل الدخول'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.teal),
                      SizedBox(height: 16),
                      Text(
                        'جاري تحميل البيانات...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildUserInfo(),
                    _buildStatsSection(),
                    Expanded(child: _buildFabricsList()),
                  ],
                ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.grey.withOpacity(0.1),
      title: const Text(
        '🧵 إدارة الخامات',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        // زر التحكم في تدوير الشاشة
        PopupMenuButton<String>(
          onSelected: _handleOrientationAction,
          icon: const Icon(Icons.screen_rotation, color: Colors.black54),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'portrait',
              child: Row(
                children: [
                  Icon(Icons.phone_android, size: 18),
                  SizedBox(width: 8),
                  Text('عمودي'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'landscape',
              child: Row(
                children: [
                  Icon(Icons.phone_android, size: 18),
                  SizedBox(width: 8),
                  Text('أفقي'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'auto',
              child: Row(
                children: [
                  Icon(Icons.screen_rotation, size: 18),
                  SizedBox(width: 8),
                  Text('تلقائي'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.sort, color: Colors.black54),
          onPressed: _showSortOptions,
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.black54),
          onPressed: _showAdvancedFilters,
        ),
        PopupMenuButton<String>(
          onSelected: _handleAppBarMenuAction,
          itemBuilder: (context) => [
            if (_isAdmin)
              const PopupMenuItem(
                value: 'all_fabrics',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 18),
                    SizedBox(width: 8),
                    Text('عرض جميع الخامات'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    if (_currentUser == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isAdmin
                ? Colors.purple.withOpacity(0.1)
                : Colors.teal.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAdmin
              ? Colors.purple.withOpacity(0.3)
              : Colors.teal.withOpacity(0.3),
        ),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _isAdmin ? Colors.purple : Colors.teal,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              _isAdmin ? Icons.admin_panel_settings : Icons.content_cut,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUserName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _isAdmin
                      ? '👑 مدير النظام - يمكنك رؤية جميع الخامات'
                      : '✂️ خياط - ترى خاماتك فقط',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isAdmin
                  ? Colors.purple.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isAdmin ? 'أدمن' : 'خياط',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isAdmin ? Colors.purple : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalQuantity = _fabrics.fold<double>(
      0,
      (sum, fabric) => sum + fabric.quantity,
    );
    final availableFabrics = _fabrics.where((f) => f.isAvailable).length;
    final lowStockFabrics = _fabrics.where((f) => f.quantity < 50).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'المجموع',
            '${_fabrics.length}',
            Icons.inventory,
            Colors.blue,
          ),
          _buildStatItem(
            'متاح',
            '$availableFabrics',
            Icons.check_circle,
            Colors.green,
          ),
          _buildStatItem(
            'مخزون قليل',
            '$lowStockFabrics',
            Icons.warning,
            Colors.orange,
          ),
          _buildStatItem(
            'الكمية الكلية',
            '${totalQuantity.toInt()}م',
            Icons.straighten,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFabricsList() {
    if (_fabrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد خامات',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? 'لا توجد خامات في النظام'
                  : 'لم تقم بإضافة أي خامات بعد',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _fabrics.length,
      itemBuilder: (context, index) => _buildFabricCard(_fabrics[index], index),
    );
  }

  Widget _buildFabricCard(Fabric fabric, int index) {
    final isLowStock = fabric.quantity < 50;
    final canEdit = true; // يمكنك التحكم بالصلاحيات هنا

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLowStock ? Border.all(color: Colors.orange, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showFabricDetails(fabric),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // صورة الخامة المحسنة
                  OptimizedLargeImageWidget(
                    imageUrl: fabric.imageUrl,
                    width: 70,
                    height: 70,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fabric.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLowStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '⚠️ مخزون قليل',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fabric.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // عرض الألوان المتوفرة
                        if (fabric.availableColors.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            children: [
                              ...fabric.availableColors.take(5).map((color) {
                                return Tooltip(
                                  message: color.colorName,
                                  child: OptimizedSmallImageWidget(
                                    imageUrl: color.imageUrl,
                                    size: 24,
                                    fallbackColor: Color(
                                      int.parse(
                                        color.colorHex.replaceFirst(
                                          '#',
                                          '0xFF',
                                        ),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                );
                              }),
                              if (fabric.availableColors.length > 5)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${fabric.availableColors.length - 5}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleMenuAction(value, fabric),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 18),
                              SizedBox(width: 8),
                              Text('نسخ'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: fabric.isAvailable ? 'disable' : 'enable',
                          child: Row(
                            children: [
                              Icon(
                                fabric.isAvailable
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(fabric.isAvailable ? 'إيقاف' : 'تفعيل'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(fabric.type, _getTypeColor(fabric.type)),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    fabric.quality,
                    _getQualityColor(fabric.quality),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(fabric.color, Colors.grey),
                  const Spacer(),
                  Text(
                    '${fabric.pricePerMeter.toStringAsFixed(0)} ريال/م',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'الكمية: ${fabric.quantity.toStringAsFixed(1)} متر',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    'المورد: ${fabric.supplier}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: fabric.isAvailable
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      fabric.isAvailable ? '✓ متاح' : '✗ غير متاح',
                      style: TextStyle(
                        fontSize: 10,
                        color: fabric.isAvailable ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'آخر تحديث: ${_formatDate(fabric.lastUpdated)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'قطن':
        return Colors.green;
      case 'حرير':
        return Colors.purple;
      case 'صوف':
        return Colors.brown;
      case 'كتان':
        return Colors.orange;
      case 'مخلوط':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getQualityColor(String quality) {
    switch (quality) {
      case 'فاخر':
        return Colors.purple;
      case 'ممتاز':
        return Colors.green;
      case 'جيد':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return '${difference.inDays} يوم';
    if (difference.inHours > 0) return '${difference.inHours} ساعة';
    return 'الآن';
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddFabricDialog,
      backgroundColor: Colors.teal,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        '➕ إضافة خامة',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ترتيب حسب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('الاسم'),
              onTap: () {
                _sortBy('name');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('السعر'),
              onTap: () {
                _sortBy('price');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('الكمية'),
              onTap: () {
                _sortBy('quantity');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('آخر تحديث'),
              onTap: () {
                _sortBy('date');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAdvancedFilters() {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('فلاتر متقدمة'),
        content: Text('ستتم إضافة فلاتر متقدمة قريباً'),
      ),
    );
  }

  void _sortBy(String criteria) {
    setState(() {
      switch (criteria) {
        case 'name':
          _fabrics.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'price':
          _fabrics.sort((a, b) => a.pricePerMeter.compareTo(b.pricePerMeter));
          break;
        case 'quantity':
          _fabrics.sort((a, b) => b.quantity.compareTo(a.quantity));
          break;
        case 'date':
          _fabrics.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
          break;
      }
    });
  }

  void _showFabricDetails(Fabric fabric) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fabric.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // المحتوى القابل للتمرير
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((fabric.imageUrl ?? '').isNotEmpty) ...[
                        OptimizedLargeImageWidget(
                          imageUrl: fabric.imageUrl,
                          height: 160,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text('النوع: ${fabric.type}'),
                      const SizedBox(height: 8),
                      Text('اللون: ${fabric.color}'),
                      const SizedBox(height: 8),
                      Text('الجودة: ${fabric.quality}'),
                      const SizedBox(height: 8),
                      Text('الكمية: ${fabric.quantity.toStringAsFixed(1)} متر'),
                      const SizedBox(height: 8),
                      Text(
                        'السعر: ${fabric.pricePerMeter.toStringAsFixed(0)} ريال/متر',
                      ),
                      const SizedBox(height: 8),
                      Text('المورد: ${fabric.supplier}'),
                      const SizedBox(height: 8),
                      Text('الوصف: ${fabric.description}'),
                      const SizedBox(height: 8),
                      Text(
                        'الحالة: ${fabric.isAvailable ? "متاح" : "غير متاح"}',
                      ),
                      const SizedBox(height: 12),
                      if (fabric.availableColors.isNotEmpty) ...[
                        const Text(
                          '🎨 الألوان المتوفرة:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: fabric.availableColors.map((color) {
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // عرض صورة اللون أو اللون فقط
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey[400]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: OptimizedSmallImageWidget(
                                      imageUrl: color.imageUrl,
                                      size: 20,
                                      fallbackColor: Color(
                                        int.parse(
                                          color.colorHex.replaceFirst(
                                            '#',
                                            '0xFF',
                                          ),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    color.colorName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // الأزرار
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditFabricDialog(fabric);
                    },
                    child: const Text('تعديل'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFabricDialog() => _showFabricDialog();

  void _showEditFabricDialog(Fabric fabric) =>
      _showFabricDialog(fabric: fabric);

  // سأقوم بإنشاء الجزء الثاني في الملف التالي للنافذة المنبثقة
  void _showFabricDialog({Fabric? fabric}) {
    _showModernFabricDialog(fabric: fabric);
  }

  void _handleMenuAction(String action, Fabric fabric) {
    switch (action) {
      case 'edit':
        _showEditFabricDialog(fabric);
        break;
      case 'duplicate':
        _duplicateFabric(fabric);
        break;
      case 'enable':
      case 'disable':
        _toggleFabricAvailability(fabric);
        break;
      case 'delete':
        _showDeleteConfirmation(fabric);
        break;
    }
  }

  void _handleAppBarMenuAction(String action) {
    switch (action) {
      case 'all_fabrics':
        break;
      case 'logout':
        _handleLogout();
        break;
    }
  }

  // معالجة إجراءات تدوير الشاشة
  void _handleOrientationAction(String action) async {
    switch (action) {
      case 'portrait':
        await ScreenOrientationService.lockToPortrait();
        _showSuccessSnackBar('تم قفل الشاشة في الوضع العمودي');
        break;
      case 'landscape':
        await ScreenOrientationService.lockToLandscape();
        _showSuccessSnackBar('تم قفل الشاشة في الوضع الأفقي');
        break;
      case 'auto':
        await ScreenOrientationService.allowAllOrientations();
        _showSuccessSnackBar('تم السماح بجميع أوضاع الشاشة');
        break;
    }
  }

  void _handleLogout() {
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
              try {
                await _auth.signOut();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              } catch (e) {
                _showErrorSnackBar('خطأ في تسجيل الخروج: $e');
              }
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

  void _duplicateFabric(Fabric fabric) {
    final duplicated = Fabric(
      id: '',
      name: '${fabric.name} (نسخة)',
      description: fabric.description,
      type: fabric.type,
      color: fabric.color,
      quantity: fabric.quantity,
      pricePerMeter: fabric.pricePerMeter,
      supplier: fabric.supplier,
      origin: fabric.origin,
      composition: fabric.composition,
      width: fabric.width,
      careInstructions: fabric.careInstructions,
      quality: fabric.quality,
      season: fabric.season,
      isAvailable: fabric.isAvailable,
      lastUpdated: DateTime.now(),
      createdBy: _currentUser?.uid ?? '',
      createdAt: DateTime.now(),
      availableColors: fabric.availableColors,
      imageUrl: fabric.imageUrl,
    );
    _addFabricToFirebase(duplicated);
  }

  void _toggleFabricAvailability(Fabric fabric) {
    final updated = fabric.copyWith(
      isAvailable: !fabric.isAvailable,
      lastUpdated: DateTime.now(),
    );
    _updateFabricInFirebase(updated);
  }

  void _showDeleteConfirmation(Fabric fabric) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "${fabric.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteFabricFromFirebase(fabric.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // النافذة المنبثقة الحديثة لإضافة/تعديل الخامة
  void _showModernFabricDialog({Fabric? fabric}) {
    // سأقوم بإنشاء هذه الوظيفة في ملف منفصل
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernFabricEditorScreen(
          fabric: fabric,
          currentUser: _currentUser,
          onSave: (savedFabric) {
            if (fabric == null) {
              _addFabricToFirebase(savedFabric);
            } else {
              _updateFabricInFirebase(savedFabric);
            }
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }
}
