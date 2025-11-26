import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// =======================
/// نماذج البيانات (Models)
/// =======================

class Service {
  final String id;
  final String name;
  final String description;
  final ServiceCategory category;
  final double price;
  final int estimatedDays;
  final ServiceDifficulty difficulty;
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final String tailorId;

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.estimatedDays,
    required this.difficulty,
    required this.isActive,
    required this.createdAt,
    required this.lastUpdated,
    required this.tailorId,
  });

  factory Service.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Service(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: ServiceCategory.values.firstWhere(
        (e) => e.toString() == 'ServiceCategory.${data['category']}',
        orElse: () => ServiceCategory.menClothing,
      ),
      price: (data['price'] ?? 0).toDouble(),
      estimatedDays: (data['estimatedDays'] ?? 1) is int
          ? (data['estimatedDays'] ?? 1)
          : int.tryParse('${data['estimatedDays']}') ?? 1,
      difficulty: ServiceDifficulty.values.firstWhere(
        (e) => e.toString() == 'ServiceDifficulty.${data['difficulty']}',
        orElse: () => ServiceDifficulty.easy,
      ),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tailorId: data['tailorId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category.toString().split('.').last,
      'price': price,
      'estimatedDays': estimatedDays,
      'difficulty': difficulty.toString().split('.').last,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'tailorId': tailorId,
    };
  }

  Service copyWith({
    String? id,
    String? name,
    String? description,
    ServiceCategory? category,
    double? price,
    int? estimatedDays,
    ServiceDifficulty? difficulty,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? tailorId,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      tailorId: tailorId ?? this.tailorId,
    );
  }
}

enum ServiceCategory {
  menClothing,
  womenClothing,
  childrenClothing,
  embroidery,
  alterations,
  accessories,
}

enum ServiceDifficulty { easy, medium, hard }

class TailorModel {
  final String id;
  final String name;
  final String email;
  final bool isActive;
  final String? phone;
  final String? address;
  final DateTime? createdAt;

  TailorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    this.phone,
    this.address,
    this.createdAt,
  });

  factory TailorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TailorModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      isActive: data['isActive'] ?? true,
      phone: data['phone'],
      address: data['address'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'isActive': isActive,
      'phone': phone,
      'address': address,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.customer,
      ),
      isActive: data['isActive'] ?? true,
    );
  }
}

enum UserRole { customer, tailor, admin }

/// =======================
/// إدارة المستخدمين
/// =======================
class UserManager {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<dynamic> getCurrentUser() async {
    try {
      final current = _auth.currentUser;
      if (current == null) return null;

      final tailorDoc = await _firestore
          .collection('tailors')
          .doc(current.uid)
          .get();
      if (tailorDoc.exists) return TailorModel.fromFirestore(tailorDoc);

      final userDoc = await _firestore
          .collection('users')
          .doc(current.uid)
          .get();
      if (userDoc.exists) return UserModel.fromFirestore(userDoc);

      return null;
    } catch (e) {
      debugPrint('خطأ في الحصول على بيانات المستخدم: $e');
      return null;
    }
  }

  static Future<bool> isCurrentUserTailor() async {
    try {
      final current = _auth.currentUser;
      if (current == null) return false;
      final doc = await _firestore.collection('tailors').doc(current.uid).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      return data['isActive'] ?? false;
    } catch (e) {
      debugPrint('خطأ في التحقق من دور الخياط: $e');
      return false;
    }
  }

  static String? getCurrentUserId() => _auth.currentUser?.uid;

  static Future<UserRole> getCurrentUserRole() async {
    try {
      final current = _auth.currentUser;
      if (current == null) return UserRole.customer;

      final tailorDoc = await _firestore
          .collection('tailors')
          .doc(current.uid)
          .get();
      if (tailorDoc.exists) return UserRole.tailor;

      final userDoc = await _firestore
          .collection('users')
          .doc(current.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final role = (data['role'] ?? 'customer').toString();
        return UserRole.values.firstWhere(
          (e) => e.toString() == 'UserRole.$role',
          orElse: () => UserRole.customer,
        );
      }
      return UserRole.customer;
    } catch (e) {
      debugPrint('خطأ في الحصول على دور المستخدم: $e');
      return UserRole.customer;
    }
  }

  static Future<void> createTailorAccount({
    required String name,
    required String email,
    String? phone,
    String? address,
  }) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }
    final data = {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('tailors').doc(current.uid).set(data);
  }

  static Future<void> updateTailorAccount({
    required String name,
    String? phone,
    String? address,
  }) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }
    await _firestore.collection('tailors').doc(current.uid).update({
      'name': name,
      'phone': phone,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// =======================
/// إدارة الخدمات (Firestore)
/// =======================
class FirebaseServicesManager {
  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'services';

  static Future<void> addService(Service service) async {
    try {
      final isTailor = await UserManager.isCurrentUserTailor();
      if (!isTailor) {
        throw Exception(
          'غير مسموح لك بإضافة خدمات. هذه الميزة متاحة للخياطين فقط.',
        );
      }
      final uid = UserManager.getCurrentUserId();
      if (uid == null) throw Exception('يجب تسجيل الدخول أولاً');

      final withTailor = service.copyWith(tailorId: uid);
      await _firestore.collection(_collection).add(withTailor.toFirestore());
    } catch (e) {
      throw Exception('فشل في إضافة الخدمة: $e');
    }
  }

  static Future<void> updateService(Service service) async {
    try {
      final role = await UserManager.getCurrentUserRole();
      final uid = UserManager.getCurrentUserId();
      if (uid == null) throw Exception('يجب تسجيل الدخول أولاً');

      if (role != UserRole.tailor && role != UserRole.admin) {
        throw Exception('غير مسموح لك بتعديل الخدمات.');
      }
      if (service.tailorId != uid && role != UserRole.admin) {
        throw Exception('يمكنك تعديل الخدمات التي أضفتها أنت فقط.');
      }

      await _firestore
          .collection(_collection)
          .doc(service.id)
          .update(service.copyWith(lastUpdated: DateTime.now()).toFirestore());
    } catch (e) {
      throw Exception('فشل في تحديث الخدمة: $e');
    }
  }

  static Future<void> deleteService(String id) async {
    try {
      final role = await UserManager.getCurrentUserRole();
      final uid = UserManager.getCurrentUserId();
      if (uid == null) throw Exception('يجب تسجيل الدخول أولاً');

      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) throw Exception('الخدمة غير موجودة');

      final service = Service.fromFirestore(doc);

      if (role != UserRole.tailor && role != UserRole.admin) {
        throw Exception('غير مسموح لك بحذف الخدمات.');
      }
      if (service.tailorId != uid && role != UserRole.admin) {
        throw Exception('يمكنك حذف الخدمات التي أضفتها أنت فقط.');
      }

      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('فشل في حذف الخدمة: $e');
    }
  }

  static Stream<List<Service>> getServices() async* {
    try {
      final role = await UserManager.getCurrentUserRole();
      final uid = UserManager.getCurrentUserId();
      if (uid == null) {
        yield [];
        return;
      }

      if (role == UserRole.admin) {
        yield* _firestore
            .collection(_collection)
            .orderBy('lastUpdated', descending: true)
            .snapshots()
            .map((s) => s.docs.map(Service.fromFirestore).toList());
      } else if (role == UserRole.tailor) {
        yield* _firestore
            .collection(_collection)
            .where('tailorId', isEqualTo: uid)
            .orderBy('lastUpdated', descending: true)
            .snapshots()
            .map((s) => s.docs.map(Service.fromFirestore).toList());
      } else {
        yield* _firestore
            .collection(_collection)
            .where('isActive', isEqualTo: true)
            .orderBy('lastUpdated', descending: true)
            .snapshots()
            .map((s) => s.docs.map(Service.fromFirestore).toList());
      }
    } catch (e) {
      debugPrint('خطأ في جلب الخدمات: $e');
      yield [];
    }
  }

  static Stream<List<Service>> getTailorServices(String tailorId) {
    return _firestore
        .collection(_collection)
        .where('tailorId', isEqualTo: tailorId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Service.fromFirestore).toList());
  }

  static Stream<List<Service>> searchServices(String query) async* {
    try {
      final role = await UserManager.getCurrentUserRole();
      final uid = UserManager.getCurrentUserId();
      if (uid == null) {
        yield [];
        return;
      }

      Query q = _firestore
          .collection(_collection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff');

      if (role == UserRole.tailor) {
        q = q.where('tailorId', isEqualTo: uid);
      } else if (role == UserRole.customer) {
        q = q.where('isActive', isEqualTo: true);
      }

      yield* q.snapshots().map(
        (s) => s.docs.map(Service.fromFirestore).toList(),
      );
    } catch (e) {
      debugPrint('خطأ في البحث: $e');
      yield [];
    }
  }
}

/// =======================
/// شاشة الإدارة/العرض
/// =======================
class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen>
    with TickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final _searchController = TextEditingController();
  ServiceCategory? _selectedCategory;
  ServiceDifficulty? _selectedDifficulty;
  String _sortBy = 'lastUpdated';

  dynamic _currentUser;
  UserRole _currentUserRole = UserRole.customer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, .15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await UserManager.getCurrentUser();
      final role = await UserManager.getCurrentUserRole();
      setState(() {
        _currentUser = user;
        _currentUserRole = role;
        _loading = false;
      });
      _anim.forward();
    } catch (e) {
      setState(() => _loading = false);
      _toast('خطأ في تحميل بيانات المستخدم: $e');
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isUserTailor {
    if (_currentUser is TailorModel)
      return (_currentUser as TailorModel).isActive;
    return _currentUserRole == UserRole.tailor;
  }

  String _currency(num v) => '${v.toStringAsFixed(2)} ر.ع';

  // -------- واجهة --------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String title = 'إدارة الخدمات';
    if (_currentUserRole == UserRole.tailor) title = 'خدماتي';
    if (_currentUserRole == UserRole.customer) title = 'الخدمات المتاحة';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.08),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_currentUserRole == UserRole.admin ||
              _currentUserRole == UserRole.tailor)
            IconButton(
              tooltip: 'تصدير البيانات',
              onPressed: _exportData,
              icon: const Icon(Icons.download, color: Colors.black54),
            ),
          if (_currentUserRole == UserRole.tailor)
            IconButton(
              tooltip: 'الملف الشخصي',
              onPressed: _showTailorProfile,
              icon: const Icon(Icons.person, color: Colors.black54),
            ),
        ],
      ),
      floatingActionButton: _isUserTailor
          ? FloatingActionButton.extended(
              onPressed: _showAddServiceDialog,
              backgroundColor: Colors.teal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'إضافة خدمة',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            children: [
              _buildSearchAndFilters(),
              Expanded(
                child: StreamBuilder<List<Service>>(
                  stream: FirebaseServicesManager.getServices(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) return _errorState();

                    final services = snapshot.data ?? [];
                    if (services.isEmpty) return _buildEmptyState();

                    final filtered = _filterServices(services);

                    return Column(
                      children: [
                        _buildStatsSection(services),
                        Expanded(child: _buildServicesList(filtered)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------- عناصر الواجهة --------
  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'البحث في الخدمات...',
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'الفئة',
                  _selectedCategory == null
                      ? 'الكل'
                      : _getCategoryDisplayName(_selectedCategory!),
                  _showCategoryFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'الصعوبة',
                  _selectedDifficulty == null
                      ? 'الكل'
                      : _getDifficultyDisplayName(_selectedDifficulty!),
                  _showDifficultyFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'ترتيب',
                  _getSortDisplayName(_sortBy),
                  _showSortOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.teal, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(List<Service> services) {
    final active = services.where((s) => s.isActive).length;
    final inactive = services.length - active;
    final avg = services.isEmpty
        ? 0.0
        : services.map((s) => s.price).reduce((a, b) => a + b) /
              services.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'المجموع',
              services.length.toString(),
              Icons.design_services,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'نشطة',
              active.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'غير نشطة',
              inactive.toString(),
              Icons.pause_circle,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'متوسط السعر',
              _currency(avg),
              Icons.attach_money,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList(List<Service> services) {
    if (services.isEmpty) return _noMatchState();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (_, i) => _buildServiceCard(services[i]),
    );
  }

  Widget _buildServiceCard(Service s) {
    final myId = UserManager.getCurrentUserId();
    final canModify =
        _isUserTailor &&
        (s.tailorId == myId || _currentUserRole == UserRole.admin);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(s.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(s.category),
                    color: _getCategoryColor(s.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCategoryDisplayName(s.category),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (canModify)
                  Switch(
                    value: s.isActive,
                    onChanged: (v) => _toggleServiceStatus(s, v),
                    activeColor: Colors.teal,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              s.description,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  _currency(s.price),
                  Icons.payments,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  '${s.estimatedDays} أيام',
                  Icons.schedule,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  _getDifficultyDisplayName(s.difficulty),
                  Icons.trending_up,
                  _getDifficultyColor(s.difficulty),
                ),
              ],
            ),
            if (canModify)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blue),
                    tooltip: 'نسخ',
                    onPressed: () => _duplicateService(s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    tooltip: 'تعديل',
                    onPressed: () => _showEditServiceDialog(s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'حذف',
                    onPressed: () => _deleteService(s),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'لا توجد خدمات حتى الآن';
    String sub = 'لا توجد خدمات متاحة حالياً';
    if (_currentUserRole == UserRole.tailor) sub = 'ابدأ بإضافة خدماتك الأولى';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.design_services, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 24),
          if (_isUserTailor)
            ElevatedButton.icon(
              onPressed: _showAddServiceDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('إضافة خدمة جديدة'),
            ),
        ],
      ),
    );
  }

  Widget _noMatchState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          'لا توجد خدمات تطابق البحث',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _searchController.clear();
            _selectedCategory = null;
            _selectedDifficulty = null;
            setState(() {});
          },
          child: const Text('مسح الفلاتر'),
        ),
      ],
    ),
  );

  Widget _errorState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text(
          'حدث خطأ في تحميل البيانات',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() {}),
          child: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );

  // -------- منطق التصفية والترتيب --------
  List<Service> _filterServices(List<Service> services) {
    var filtered = services;

    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase().trim();
      filtered = filtered
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.description.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_selectedCategory != null) {
      filtered = filtered
          .where((s) => s.category == _selectedCategory)
          .toList();
    }
    if (_selectedDifficulty != null) {
      filtered = filtered
          .where((s) => s.difficulty == _selectedDifficulty)
          .toList();
    }

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'price':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'lastUpdated':
        filtered.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
    }
    return filtered;
  }

  // -------- الحوارات (إضافة/تعديل) --------
  void _showAddServiceDialog() {
    if (!_isUserTailor) {
      _toast('غير مسموح لك بإضافة خدمات. هذه الميزة متاحة للخياطين فقط.');
      return;
    }
    _showServiceDialog();
  }

  void _showEditServiceDialog(Service s) => _showServiceDialog(service: s);

  void _showServiceDialog({Service? service}) {
    final isEditing = service != null;

    final nameCtrl = TextEditingController(text: service?.name ?? '');
    final descCtrl = TextEditingController(text: service?.description ?? '');
    final priceCtrl = TextEditingController(
      text: service == null ? '' : service.price.toStringAsFixed(2),
    );
    final daysCtrl = TextEditingController(
      text: service?.estimatedDays.toString() ?? '',
    );

    ServiceCategory cat = service?.category ?? ServiceCategory.menClothing;
    ServiceDifficulty diff = service?.difficulty ?? ServiceDifficulty.easy;
    bool active = service?.isActive ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: StatefulBuilder(
          builder: (context, setD) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        isEditing ? 'تعديل الخدمة' : 'إضافة خدمة جديدة',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _field(
                        controller: nameCtrl,
                        label: 'اسم الخدمة',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: descCtrl,
                        label: 'وصف الخدمة',
                        icon: Icons.description,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: priceCtrl,
                              label: 'السعر (ر.ع)',
                              icon: Icons.payments,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d{0,6}(\.\d{0,2})?$'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: daysCtrl,
                              label: 'عدد الأيام',
                              icon: Icons.schedule,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ServiceCategory>(
                        value: cat,
                        decoration: _ddDecoration('الفئة'),
                        items: ServiceCategory.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_getCategoryDisplayName(e)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setD(() => cat = v ?? cat),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ServiceDifficulty>(
                        value: diff,
                        decoration: _ddDecoration('مستوى الصعوبة'),
                        items: ServiceDifficulty.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_getDifficultyDisplayName(e)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setD(() => diff = v ?? diff),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('خدمة نشطة'),
                        value: active,
                        activeColor: Colors.teal,
                        onChanged: (v) => setD(() => active = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _saveService(
                              context,
                              service,
                              nameCtrl.text.trim(),
                              descCtrl.text.trim(),
                              double.tryParse(
                                    priceCtrl.text.replaceAll(',', '.'),
                                  ) ??
                                  -1,
                              int.tryParse(daysCtrl.text) ?? 0,
                              cat,
                              diff,
                              active,
                            ),
                            child: Text(isEditing ? 'تحديث' : 'إضافة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _ddDecoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.teal),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal),
        ),
      ),
    );
  }

  void _saveService(
    BuildContext context,
    Service? existingService,
    String name,
    String description,
    double price,
    int days,
    ServiceCategory category,
    ServiceDifficulty difficulty,
    bool isActive,
  ) async {
    if (name.isEmpty || description.isEmpty || price < 0 || days <= 0) {
      _toast('يرجى تعبئة الحقول بشكل صحيح');
      return;
    }

    try {
      final uid = UserManager.getCurrentUserId();
      final service = Service(
        id: existingService?.id ?? '',
        name: name,
        description: description,
        category: category,
        price: price,
        estimatedDays: days,
        difficulty: difficulty,
        isActive: isActive,
        createdAt: existingService?.createdAt ?? DateTime.now(),
        lastUpdated: DateTime.now(),
        tailorId: existingService?.tailorId ?? uid ?? '',
      );

      if (existingService != null) {
        await FirebaseServicesManager.updateService(service);
        _toast('تم تحديث الخدمة بنجاح');
      } else {
        await FirebaseServicesManager.addService(service);
        _toast('تم إضافة الخدمة بنجاح');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('حدث خطأ: $e');
    }
  }

  void _deleteService(Service s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف خدمة "${s.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await FirebaseServicesManager.deleteService(s.id);
                if (mounted) Navigator.pop(context);
                _toast('تم حذف الخدمة بنجاح');
              } catch (e) {
                if (mounted) Navigator.pop(context);
                _toast('حدث خطأ في الحذف: $e');
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateService(Service s) async {
    try {
      final uid = UserManager.getCurrentUserId();
      final copy = s.copyWith(
        id: '',
        name: '${s.name} (نسخة)',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        tailorId: uid ?? '',
      );
      await FirebaseServicesManager.addService(copy);
      _toast('تم نسخ الخدمة بنجاح');
    } catch (e) {
      _toast('حدث خطأ في النسخ: $e');
    }
  }

  Future<void> _toggleServiceStatus(Service s, bool active) async {
    try {
      await FirebaseServicesManager.updateService(s.copyWith(isActive: active));
      _toast(active ? 'تم تفعيل الخدمة' : 'تم إيقاف الخدمة');
    } catch (e) {
      _toast('حدث خطأ: $e');
    }
  }

  void _showCategoryFilter() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تصفية حسب الفئة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('الكل'),
              leading: Radio<ServiceCategory?>(
                value: null,
                groupValue: _selectedCategory,
                onChanged: (v) {
                  setState(() => _selectedCategory = v);
                  Navigator.pop(context);
                },
              ),
            ),
            ...ServiceCategory.values.map(
              (c) => ListTile(
                title: Text(_getCategoryDisplayName(c)),
                leading: Radio<ServiceCategory?>(
                  value: c,
                  groupValue: _selectedCategory,
                  onChanged: (v) {
                    setState(() => _selectedCategory = v);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDifficultyFilter() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تصفية حسب الصعوبة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('الكل'),
              leading: Radio<ServiceDifficulty?>(
                value: null,
                groupValue: _selectedDifficulty,
                onChanged: (v) {
                  setState(() => _selectedDifficulty = v);
                  Navigator.pop(context);
                },
              ),
            ),
            ...ServiceDifficulty.values.map(
              (d) => ListTile(
                title: Text(_getDifficultyDisplayName(d)),
                leading: Radio<ServiceDifficulty?>(
                  value: d,
                  groupValue: _selectedDifficulty,
                  onChanged: (v) {
                    setState(() => _selectedDifficulty = v);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ترتيب حسب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sortTile('name'),
            _sortTile('price'),
            _sortTile('lastUpdated'),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(String key) => ListTile(
    title: Text(_getSortDisplayName(key)),
    leading: Radio<String>(
      value: key,
      groupValue: _sortBy,
      onChanged: (v) {
        setState(() => _sortBy = v!);
        Navigator.pop(context);
      },
    ),
  );

  void _exportData() {
    _toast('ميزة التصدير قيد التطوير');
  }

  void _showTailorProfile() {
    if (_currentUser is! TailorModel) return;
    final t = _currentUser as TailorModel;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الملف الشخصي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاسم: ${t.name}'),
            const SizedBox(height: 8),
            Text('البريد الإلكتروني: ${t.email}'),
            const SizedBox(height: 8),
            if (t.phone != null) Text('الهاتف: ${t.phone}'),
            const SizedBox(height: 8),
            if (t.address != null) Text('العنوان: ${t.address}'),
            const SizedBox(height: 8),
            Text('الحالة: ${t.isActive ? "نشط" : "غير نشط"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditTailorProfile();
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  void _showEditTailorProfile() {
    if (_currentUser is! TailorModel) return;
    final t = _currentUser as TailorModel;

    final nameCtrl = TextEditingController(text: t.name);
    final phoneCtrl = TextEditingController(text: t.phone ?? '');
    final addrCtrl = TextEditingController(text: t.address ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل الملف الشخصي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(controller: nameCtrl, label: 'الاسم', icon: Icons.person),
            const SizedBox(height: 12),
            _field(
              controller: phoneCtrl,
              label: 'رقم الهاتف',
              icon: Icons.phone,
            ),
            const SizedBox(height: 12),
            _field(
              controller: addrCtrl,
              label: 'العنوان',
              icon: Icons.place,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await UserManager.updateTailorAccount(
                  name: nameCtrl.text,
                  phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                  address: addrCtrl.text.isEmpty ? null : addrCtrl.text,
                );
                if (mounted) Navigator.pop(context);
                _toast('تم تحديث الملف الشخصي بنجاح');
                _loadCurrentUser();
              } catch (e) {
                _toast('حدث خطأ: $e');
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // -------- أدوات مساعدة للألوان/الأسماء --------
  Color _getCategoryColor(ServiceCategory c) {
    switch (c) {
      case ServiceCategory.menClothing:
        return Colors.blue;
      case ServiceCategory.womenClothing:
        return Colors.pink;
      case ServiceCategory.childrenClothing:
        return Colors.orange;
      case ServiceCategory.embroidery:
        return Colors.purple;
      case ServiceCategory.alterations:
        return Colors.green;
      case ServiceCategory.accessories:
        return Colors.brown;
    }
  }

  IconData _getCategoryIcon(ServiceCategory c) {
    switch (c) {
      case ServiceCategory.menClothing:
        return Icons.man;
      case ServiceCategory.womenClothing:
        return Icons.woman;
      case ServiceCategory.childrenClothing:
        return Icons.child_care;
      case ServiceCategory.embroidery:
        return Icons.auto_fix_high;
      case ServiceCategory.alterations:
        return Icons.content_cut;
      case ServiceCategory.accessories:
        return Icons.watch;
    }
  }

  String _getCategoryDisplayName(ServiceCategory c) {
    switch (c) {
      case ServiceCategory.menClothing:
        return 'ملابس رجالية';
      case ServiceCategory.womenClothing:
        return 'ملابس نسائية';
      case ServiceCategory.childrenClothing:
        return 'ملابس أطفال';
      case ServiceCategory.embroidery:
        return 'تطريز';
      case ServiceCategory.alterations:
        return 'تعديلات';
      case ServiceCategory.accessories:
        return 'إكسسوارات';
    }
  }

  Color _getDifficultyColor(ServiceDifficulty d) {
    switch (d) {
      case ServiceDifficulty.easy:
        return Colors.green;
      case ServiceDifficulty.medium:
        return Colors.orange;
      case ServiceDifficulty.hard:
        return Colors.red;
    }
  }

  String _getDifficultyDisplayName(ServiceDifficulty d) {
    switch (d) {
      case ServiceDifficulty.easy:
        return 'سهل';
      case ServiceDifficulty.medium:
        return 'متوسط';
      case ServiceDifficulty.hard:
        return 'صعب';
    }
  }

  String _getSortDisplayName(String k) {
    switch (k) {
      case 'name':
        return 'الاسم';
      case 'price':
        return 'السعر';
      case 'lastUpdated':
        return 'آخر تحديث';
      default:
        return 'الاسم';
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
