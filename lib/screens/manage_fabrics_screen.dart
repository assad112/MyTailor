import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image_picker/image_picker.dart';

class Fabric {
  final String id;
  final String name;
  final String type;
  final String color;
  final double quantity; // بالمتر
  final double pricePerMeter;
  final String supplier;
  final String quality;
  final String description;
  final bool isAvailable;
  final DateTime lastUpdated;
  final String createdBy; // معرف الخياط الذي أضاف الخامة
  final DateTime createdAt; // تاريخ الإضافة
  final String tailorName; // اسم الخياط (للأدمن)
  final String? imageUrl; // ✅ رابط صورة الخامة

  Fabric({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.quantity,
    required this.pricePerMeter,
    required this.supplier,
    required this.quality,
    required this.description,
    this.isAvailable = true,
    required this.lastUpdated,
    required this.createdBy,
    required this.createdAt,
    this.tailorName = '',
    this.imageUrl,
  });

  factory Fabric.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Fabric(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      color: data['color'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      pricePerMeter: (data['pricePerMeter'] ?? 0).toDouble(),
      supplier: data['supplier'] ?? '',
      quality: data['quality'] ?? '',
      description: data['description'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tailorName: data['tailorName'] ?? '',
      imageUrl: data['imageUrl'] as String?, // ✅
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'color': color,
      'quantity': quantity,
      'pricePerMeter': pricePerMeter,
      'supplier': supplier,
      'quality': quality,
      'description': description,
      'isAvailable': isAvailable,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'tailorName': tailorName,
      'imageUrl': imageUrl, // ✅
    };
  }

  Fabric copyWith({
    String? id,
    String? name,
    String? type,
    String? color,
    double? quantity,
    double? pricePerMeter,
    String? supplier,
    String? quality,
    String? description,
    bool? isAvailable,
    DateTime? lastUpdated,
    String? createdBy,
    DateTime? createdAt,
    String? tailorName,
    String? imageUrl,
  }) {
    return Fabric(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
      pricePerMeter: pricePerMeter ?? this.pricePerMeter,
      supplier: supplier ?? this.supplier,
      quality: quality ?? this.quality,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      tailorName: tailorName ?? this.tailorName,
      imageUrl: imageUrl ?? this.imageUrl, // ✅
    );
  }
}

class ManageFabricsScreen extends StatefulWidget {
  const ManageFabricsScreen({super.key});

  @override
  State<ManageFabricsScreen> createState() => _ManageFabricsScreenState();
}

class _ManageFabricsScreenState extends State<ManageFabricsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'الكل';
  String _selectedSupplier = 'الكل';
  String _selectedQuality = 'الكل';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Fabric> _fabrics = [];
  List<Fabric> _filteredFabrics = [];
  bool _isLoading = true;

  User? _currentUser;
  bool _isAdmin = false;
  String _currentUserName = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
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

  // جلب الخامات
  void _loadFabrics() {
    if (_currentUser == null) return;

    Query query = _firestore.collection('fabrics');
    if (!_isAdmin) {
      query = query.where('createdBy', isEqualTo: _currentUser!.uid);
    }

    query.snapshots().listen(
      (snapshot) {
        setState(() {
          _fabrics = snapshot.docs
              .map((doc) => Fabric.fromFirestore(doc))
              .toList();
          _fabrics.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _filterFabrics();
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

  // إضافة
  Future<void> _addFabricToFirebase(Fabric fabric) async {
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('يجب تسجيل الدخول أولاً');
        return;
      }
      final fabricWithUser = fabric.copyWith(
        createdBy: _currentUser!.uid,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        tailorName: _currentUserName,
      );
      await _firestore.collection('fabrics').add(fabricWithUser.toFirestore());
      _showSuccessSnackBar('تم إضافة الخامة بنجاح');
    } catch (e) {
      debugPrint('خطأ في إضافة الخامة: $e');
      _showErrorSnackBar('خطأ في إضافة الخامة: $e');
    }
  }

  // تعديل
  Future<void> _updateFabricInFirebase(Fabric fabric) async {
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('يجب تسجيل الدخول أولاً');
        return;
      }
      if (!_isAdmin && fabric.createdBy != _currentUser!.uid) {
        _showErrorSnackBar('غير مصرح لك بتعديل هذه الخامة');
        return;
      }
      final updated = fabric.copyWith(lastUpdated: DateTime.now());
      await _firestore
          .collection('fabrics')
          .doc(fabric.id)
          .update(updated.toFirestore());
      _showSuccessSnackBar('تم تعديل الخامة بنجاح');
    } catch (e) {
      debugPrint('خطأ في تعديل الخامة: $e');
      _showErrorSnackBar('خطأ في تعديل الخامة: $e');
    }
  }

  // حذف (+ حذف الصورة إن وجدت)
  Future<void> _deleteFabricFromFirebase(String fabricId) async {
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('يجب تسجيل الدخول أولاً');
        return;
      }
      final fabric = _fabrics.firstWhere((f) => f.id == fabricId);
      if (!_isAdmin && fabric.createdBy != _currentUser!.uid) {
        _showErrorSnackBar('غير مصرح لك بحذف هذه الخامة');
        return;
      }
      // حذف المستند
      await _firestore.collection('fabrics').doc(fabricId).delete();
      // حذف الصورة من التخزين (اختياري)
      if ((fabric.imageUrl ?? '').isNotEmpty) {
        try {
          final ref = firebase_storage.FirebaseStorage.instance.refFromURL(
            fabric.imageUrl!,
          );
          await ref.delete();
        } catch (_) {}
      }
      _showSuccessSnackBar('تم حذف الخامة بنجاح');
    } catch (e) {
      debugPrint('خطأ في حذف الخامة: $e');
      _showErrorSnackBar('خطأ في حذف الخامة: $e');
    }
  }

  // رفع صورة الخامة
  Future<String?> _pickAndUploadFabricImage({
    required String ownerUid,
    required void Function(void Function()) setDialogState,
    required void Function(Uint8List?) onPreview,
    required void Function(double) onProgress,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      onPreview(bytes);

      final ext = picked.name.split('.').last.toLowerCase();
      final String contentType = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp')
          ? 'image/webp'
          : 'image/jpeg';

      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'fabric_${ownerUid}_$ts.$ext';
      final path = 'fabrics/$ownerUid/$fileName';

      final ref = firebase_storage.FirebaseStorage.instance.ref().child(path);
      final meta = firebase_storage.SettableMetadata(contentType: contentType);

      setDialogState(() {});
      final uploadTask = ref.putData(bytes, meta);

      String? downloadUrl;
      await uploadTask.snapshotEvents.forEach((event) {
        final total = event.totalBytes == 0 ? 1 : event.totalBytes;
        final progress = event.bytesTransferred / total;
        onProgress(progress);
      });

      downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      _showErrorSnackBar('تعذر رفع الصورة: $e');
      return null;
    } finally {
      setDialogState(() {});
    }
  }

  // شاشة تسجيل الدخول
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
    _searchController.dispose();
    super.dispose();
  }

  void _filterFabrics() {
    setState(() {
      _filteredFabrics = _fabrics.where((fabric) {
        final q = _searchController.text.toLowerCase();
        final matchesSearch =
            fabric.name.toLowerCase().contains(q) ||
            fabric.description.toLowerCase().contains(q) ||
            fabric.color.toLowerCase().contains(q);
        final matchesType =
            _selectedType == 'الكل' || fabric.type == _selectedType;
        final matchesSupplier =
            _selectedSupplier == 'الكل' || fabric.supplier == _selectedSupplier;
        final matchesQuality =
            _selectedQuality == 'الكل' || fabric.quality == _selectedQuality;
        return matchesSearch &&
            matchesType &&
            matchesSupplier &&
            matchesQuality;
      }).toList();
    });
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
                    _buildSearchAndFilters(),
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
        'إدارة الخامات',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      // ✅ بدون زر رجوع
      actions: [
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
        color: _isAdmin
            ? Colors.purple.withOpacity(0.1)
            : Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAdmin
              ? Colors.purple.withOpacity(0.3)
              : Colors.teal.withOpacity(0.3),
        ),
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
                      ? 'مدير النظام - يمكنك رؤية جميع الخامات'
                      : 'خياط - ترى خاماتك فقط',
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

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _filterFabrics(),
            decoration: InputDecoration(
              hintText: 'البحث عن خامة...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _filterFabrics();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'النوع',
                  _selectedType,
                  ['الكل', 'قطن', 'حرير', 'صوف', 'كتان', 'مخلوط'],
                  (value) {
                    setState(() {
                      _selectedType = value;
                      _filterFabrics();
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'الجودة',
                  _selectedQuality,
                  ['الكل', 'فاخر', 'ممتاز', 'جيد'],
                  (value) {
                    setState(() {
                      _selectedQuality = value;
                      _filterFabrics();
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'المورد',
                  _selectedSupplier,
                  _getUniqueSuppliers(),
                  (value) {
                    setState(() {
                      _selectedSupplier = value;
                      _filterFabrics();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getUniqueSuppliers() {
    final suppliers = <String>{'الكل'};
    for (var fabric in _fabrics) {
      if (fabric.supplier.trim().isNotEmpty) suppliers.add(fabric.supplier);
    }
    return suppliers.toList();
  }

  Widget _buildFilterChip(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: const TextStyle(fontSize: 12)),
          items: options
              .map(
                (String option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (newValue) => onChanged(newValue!),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
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
    if (_filteredFabrics.isEmpty) {
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
      itemCount: _filteredFabrics.length,
      itemBuilder: (context, index) =>
          _buildFabricCard(_filteredFabrics[index], index),
    );
  }

  Widget _buildFabricCard(Fabric fabric, int index) {
    final isLowStock = fabric.quantity < 50;
    final isOwner = fabric.createdBy == _currentUser?.uid;
    final canEdit = _isAdmin || isOwner;

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
                  // ✅ صورة الخامة
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (fabric.imageUrl ?? '').isNotEmpty
                        ? Image.network(
                            fabric.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            color: _getTypeColor(fabric.type).withOpacity(0.1),
                            child: Icon(
                              _getTypeIcon(fabric.type),
                              color: _getTypeColor(fabric.type),
                            ),
                          ),
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
                                  'مخزون قليل',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (!isOwner && _isAdmin)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  fabric.tailorName.isNotEmpty
                                      ? fabric.tailorName
                                      : 'خياط آخر',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
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
                      fabric.isAvailable ? 'متاح' : 'غير متاح',
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

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'قطن':
        return Icons.eco;
      case 'حرير':
        return Icons.diamond;
      case 'صوف':
        return Icons.pets;
      case 'كتان':
        return Icons.grass;
      case 'مخلوط':
        return Icons.layers;
      default:
        return Icons.texture;
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
        'إضافة خامة',
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
          _filteredFabrics.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'price':
          _filteredFabrics.sort(
            (a, b) => a.pricePerMeter.compareTo(b.pricePerMeter),
          );
          break;
        case 'quantity':
          _filteredFabrics.sort((a, b) => b.quantity.compareTo(a.quantity));
          break;
        case 'date':
          _filteredFabrics.sort(
            (a, b) => b.lastUpdated.compareTo(a.lastUpdated),
          );
          break;
      }
    });
  }

  void _showFabricDetails(Fabric fabric) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(fabric.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((fabric.imageUrl ?? '').isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    fabric.imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
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
              Text('الحالة: ${fabric.isAvailable ? "متاح" : "غير متاح"}'),
              const SizedBox(height: 8),
              Text('تاريخ الإضافة: ${_formatDate(fabric.createdAt)}'),
              if (_isAdmin && fabric.tailorName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('الخياط: ${fabric.tailorName}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          if (_isAdmin || fabric.createdBy == _currentUser?.uid)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditFabricDialog(fabric);
              },
              child: const Text('تعديل'),
            ),
        ],
      ),
    );
  }

  void _showAddFabricDialog() => _showFabricDialog();

  void _showEditFabricDialog(Fabric fabric) =>
      _showFabricDialog(fabric: fabric);

  // ✅ نافذة الإضافة/التعديل + رفع الصورة
  void _showFabricDialog({Fabric? fabric}) {
    final isEditing = fabric != null;
    final nameController = TextEditingController(text: fabric?.name ?? '');
    final descriptionController = TextEditingController(
      text: fabric?.description ?? '',
    );
    final colorController = TextEditingController(text: fabric?.color ?? '');
    final quantityController = TextEditingController(
      text: fabric?.quantity.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: fabric?.pricePerMeter.toString() ?? '',
    );
    final supplierController = TextEditingController(
      text: fabric?.supplier ?? '',
    );
    String selectedType = fabric?.type ?? 'قطن';
    String selectedQuality = fabric?.quality ?? 'جيد';

    Uint8List? localPreviewBytes;
    String? uploadedImageUrl = fabric?.imageUrl;
    bool isLoading = false;
    double uploadProgress = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(isEditing ? 'تعديل الخامة' : 'إضافة خامة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ كيزة رفع صورة
                InkWell(
                  onTap: isLoading || _currentUser == null
                      ? null
                      : () async {
                          final url = await _pickAndUploadFabricImage(
                            ownerUid: _currentUser!.uid,
                            setDialogState: setDialogState,
                            onPreview: (bytes) =>
                                setDialogState(() => localPreviewBytes = bytes),
                            onProgress: (p) =>
                                setDialogState(() => uploadProgress = p),
                          );
                          if (url != null) {
                            setDialogState(() => uploadedImageUrl = url);
                            _showSuccessSnackBar('تم رفع الصورة بنجاح');
                          }
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (localPreviewBytes != null ||
                            (uploadedImageUrl ?? '').isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: localPreviewBytes != null
                                ? Image.memory(
                                    localPreviewBytes!,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : Image.network(
                                    uploadedImageUrl!,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                          )
                        else ...[
                          const Icon(
                            Icons.add_a_photo,
                            size: 36,
                            color: Colors.teal,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'اضغط لاختيار ورفع صورة الخامة',
                            style: TextStyle(fontSize: 12, color: Colors.teal),
                          ),
                        ],
                        if (uploadProgress > 0 && uploadProgress < 1) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: uploadProgress),
                          const SizedBox(height: 4),
                          Text(
                            '${(uploadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخامة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'النوع',
                          border: OutlineInputBorder(),
                        ),
                        items: ['قطن', 'حرير', 'صوف', 'كتان', 'مخلوط']
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => selectedType = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: colorController,
                        decoration: const InputDecoration(
                          labelText: 'اللون',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الكمية (متر)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر (ريال/متر)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: supplierController,
                  decoration: const InputDecoration(
                    labelText: 'المورد',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedQuality,
                  decoration: const InputDecoration(
                    labelText: 'الجودة',
                    border: OutlineInputBorder(),
                  ),
                  items: ['فاخر', 'ممتاز', 'جيد']
                      .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedQuality = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty ||
                          descriptionController.text.isEmpty ||
                          colorController.text.isEmpty ||
                          quantityController.text.isEmpty ||
                          priceController.text.isNotEmpty == false ||
                          supplierController.text.isEmpty) {
                        _showErrorSnackBar('يرجى ملء جميع الحقول');
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final newFabric = Fabric(
                        id: isEditing ? fabric.id : '',
                        name: nameController.text,
                        description: descriptionController.text,
                        type: selectedType,
                        color: colorController.text,
                        quantity: double.tryParse(quantityController.text) ?? 0,
                        pricePerMeter:
                            double.tryParse(priceController.text) ?? 0,
                        supplier: supplierController.text,
                        quality: selectedQuality,
                        isAvailable: fabric?.isAvailable ?? true,
                        lastUpdated: DateTime.now(),
                        createdBy: fabric?.createdBy ?? _currentUser?.uid ?? '',
                        createdAt: fabric?.createdAt ?? DateTime.now(),
                        tailorName: fabric?.tailorName ?? _currentUserName,
                        imageUrl: uploadedImageUrl, // ✅ حفظ الرابط
                      );

                      if (isEditing) {
                        await _updateFabricInFirebase(newFabric);
                      } else {
                        await _addFabricToFirebase(newFabric);
                      }

                      if (mounted) Navigator.pop(context);
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'تعديل' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
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
        // يمكنك هنا تبديل فلتر عرض الكل/خاماتي
        break;
      case 'logout':
        _handleLogout();
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
      quality: fabric.quality,
      lastUpdated: DateTime.now(),
      createdBy: _currentUser?.uid ?? '',
      createdAt: DateTime.now(),
      tailorName: _currentUserName,
      imageUrl: fabric.imageUrl, // نسخ الصورة أيضًا
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
        title: const Text('تأكيد الحذف'),
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
}
