import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class EmbroideryListScreen extends StatefulWidget {
  const EmbroideryListScreen({super.key});

  @override
  State<EmbroideryListScreen> createState() => _EmbroideryListScreenState();
}

class _EmbroideryListScreenState extends State<EmbroideryListScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _searchQuery = '';
  bool _isGridView = true;

  // للتحكم في التحميل التلقائي
  final ScrollController _scrollController = ScrollController();

  // معرف الخياط الحالي
  String? _currentTailorId;
  bool _isLoadingUser = true;

  // للتحكم في حالة رفع الصورة
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    _loadCurrentTailor();
  }

  // جلب معرف الخياط الحالي
  Future<void> _loadCurrentTailor() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _currentTailorId = currentUser.uid;
          _isLoadingUser = false;
        });
      } else {
        // في حالة عدم وجود مستخدم مسجل، استخدام معرف تجريبي
        setState(() {
          _currentTailorId = 'i3ZSdx5x4FOuOOnChsw1HtvpoGy2';
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب معرف الخياط: $e');
      setState(() {
        _currentTailorId = 'i3ZSdx5x4FOuOOnChsw1HtvpoGy2';
        _isLoadingUser = false;
      });
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // التحميل التلقائي عند الوصول لنهاية القائمة
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // يمكن إضافة منطق التحميل الإضافي هنا إذا لزم الأمر
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // وظيفة رفع صورة تطريز جديدة
  Future<void> _uploadEmbroideryImage() async {
    // التحقق من أن الـ widget ما زال موجوداً
    if (!mounted) return;

    // التحقق من أن معرف الخياط موجود
    if (_currentTailorId == null) {
      _showErrorSnackBar('خطأ: لم يتم تحديد معرف الخياط');
      return;
    }

    // منع فتح Image Picker إذا كان مفتوحاً بالفعل
    if (_isUploadingImage) {
      debugPrint('⚠️ عملية رفع صورة جارية بالفعل');
      return;
    }

    try {
      setState(() => _isUploadingImage = true);

      // اختيار الصورة
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (!mounted) return;

      if (image == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      // عرض dialog للوصف
      final description = await _showDescriptionDialog();

      if (!mounted) return;

      if (description == null || description.isEmpty) {
        setState(() => _isUploadingImage = false);
        return;
      }

      // عرض مؤشر التحميل
      if (mounted) {
        _showLoadingDialog();
      }

      // رفع الصورة إلى Firebase Storage
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('tailors')
          .child(_currentTailorId!)
          .child('embroidery_images')
          .child(fileName);

      final File imageFile = File(image.path);
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // حفظ البيانات في Firestore
      await FirebaseFirestore.instance
          .collection('tailors')
          .doc(_currentTailorId!)
          .collection('embroidery_images')
          .add({
            'imageUrl': downloadUrl,
            'description': description,
            'timestamp': FieldValue.serverTimestamp(),
            'tailorId': _currentTailorId,
          });

      if (!mounted) return;

      // إغلاق dialog التحميل
      Navigator.of(context).pop();

      // عرض رسالة نجاح
      _showSuccessSnackBar('تم رفع صورة التطريز بنجاح ✅');

      setState(() => _isUploadingImage = false);
    } catch (e) {
      debugPrint('خطأ في رفع الصورة: $e');

      if (!mounted) return;

      // إغلاق dialog التحميل إن كان مفتوحًا
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      _showErrorSnackBar('فشل رفع الصورة: ${e.toString()}');

      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  // حذف صورة تطريز
  Future<void> _deleteEmbroideryImage(String docId, String imageUrl) async {
    if (!mounted) return;

    try {
      final bool? confirm = await _showDeleteConfirmDialog();

      if (!mounted) return;
      if (confirm != true) return;

      // عرض مؤشر التحميل
      if (mounted) {
        _showLoadingDialog();
      }

      // حذف الصورة من Storage
      try {
        final Reference imageRef = FirebaseStorage.instance.refFromURL(
          imageUrl,
        );
        await imageRef.delete();
      } catch (e) {
        debugPrint('خطأ في حذف الصورة من Storage: $e');
      }

      // حذف البيانات من Firestore
      await FirebaseFirestore.instance
          .collection('tailors')
          .doc(_currentTailorId!)
          .collection('embroidery_images')
          .doc(docId)
          .delete();

      if (!mounted) return;

      // إغلاق dialog التحميل
      Navigator.of(context).pop();

      _showSuccessSnackBar('تم حذف صورة التطريز بنجاح ✅');
    } catch (e) {
      debugPrint('خطأ في حذف الصورة: $e');

      if (!mounted) return;

      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      _showErrorSnackBar('فشل حذف الصورة: ${e.toString()}');
    }
  }

  Future<String?> _showDescriptionDialog() async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('وصف التطريز'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'أدخل وصف للتطريز...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الصورة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري المعالجة...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // التحقق من تحميل معرف الخياط
    if (_isLoadingUser || _currentTailorId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        appBar: _buildAppBar(),
        body: _buildLoadingWidget(),
      );
    }

    // استخدام معرف الخياط الحالي بدلاً من default_admin
    final CollectionReference embroideryCollection = FirebaseFirestore.instance
        .collection('tailors')
        .doc(_currentTailorId!) // ✅ كل خياط له قائمته الخاصة
        .collection('embroidery_images');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildSearchAndControls(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: embroideryCollection
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingWidget();
                    }
                    if (snapshot.hasError) {
                      return _buildErrorWidget();
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyWidget();
                    }

                    final docs = snapshot.data!.docs;
                    final filteredDocs = _filterDocuments(docs);

                    if (filteredDocs.isEmpty) {
                      return _buildNoResultsWidget();
                    }

                    return _isGridView
                        ? _buildGridView(filteredDocs)
                        : _buildListView(filteredDocs);
                  },
                ),
              ),
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
        'قائمة التطريزات',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isGridView ? Icons.view_list : Icons.grid_view,
            color: Colors.black54,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSearchAndControls() {
    // إذا لم يتم تحميل معرف الخياط بعد، عرض 0
    if (_currentTailorId == null) {
      return _buildSearchControlsWidget(0);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tailors')
          .doc(_currentTailorId!) // ✅ استخدام معرف الخياط الحالي
          .collection('embroidery_images')
          .snapshots(),
      builder: (context, snapshot) {
        final itemCount = snapshot.hasData
            ? _filterDocuments(snapshot.data!.docs).length
            : 0;

        return _buildSearchControlsWidget(itemCount);
      },
    );
  }

  Widget _buildSearchControlsWidget(int itemCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'البحث في التطريزات...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تطريزاتي - $itemCount عنصر',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'جاري التحميل التلقائي...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'حدث خطأ في التحميل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يرجى المحاولة مرة أخرى',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('إعادة التحميل'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد تطريزات في قائمتك',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'ابدأ بإضافة صور التطريزات الخاصة بك\nلعرضها للعملاء',
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isUploadingImage ? null : _uploadEmbroideryImage,
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate),
              label: Text(
                _isUploadingImage ? 'جاري الرفع...' : 'إضافة صورة تطريز',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isUploadingImage
                    ? Colors.grey
                    : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                elevation: _isUploadingImage ? 0 : 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.search_off,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نتائج للبحث',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب البحث بكلمات مختلفة',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<QueryDocumentSnapshot> docs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          return _buildGridItem(docs[index], index);
        },
      ),
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        return _buildListItem(docs[index], index);
      },
    );
  }

  Widget _buildGridItem(QueryDocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final description = data['description'] ?? 'بدون وصف';
    final imageUrl = data['imageUrl'] ?? '';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTap: () => _showImageDialog(imageUrl, description, doc.id),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 2,
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // صورة التطريز
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? _buildAutoLoadingImage(imageUrl)
                                  : _buildPlaceholderImage(),
                            ),
                          ),
                        ),
                        // معلومات التطريز
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF10B981),
                                              Color(0xFF059669),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'تطريز',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // زر الحذف
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _deleteEmbroideryImage(doc.id, imageUrl),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListItem(QueryDocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final description = data['description'] ?? 'بدون وصف';
    final imageUrl = data['imageUrl'] ?? '';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 150 + (index * 30)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () => _showImageDialog(imageUrl, description, doc.id),
                child: Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(20),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(20),
                        ),
                        child: imageUrl.isNotEmpty
                            ? _buildAutoLoadingImage(imageUrl)
                            : _buildPlaceholderImage(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'تطريزي',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // زر الحذف
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEmbroideryImage(doc.id, imageUrl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ميزة التحميل التلقائي للصور
  Widget _buildAutoLoadingImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[200]!, Colors.grey[100]!],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildPlaceholderImage(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: 400,
      memCacheHeight: 400,
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF059669).withOpacity(0.1),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 32,
              color: Color(0xFF10B981),
            ),
            SizedBox(height: 4),
            Text(
              'تطريز',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _isUploadingImage ? null : _uploadEmbroideryImage,
      backgroundColor: _isUploadingImage
          ? Colors.grey
          : const Color(0xFF10B981),
      foregroundColor: Colors.white,
      elevation: _isUploadingImage ? 0 : 8,
      icon: _isUploadingImage
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.add_photo_alternate),
      label: Text(
        _isUploadingImage ? 'جاري الرفع...' : 'إضافة صورة',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterDocuments(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final description = (data['description'] ?? '').toString().toLowerCase();
      return description.contains(_searchQuery);
    }).toList();
  }

  void _showImageDialog(String imageUrl, String description, String docId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 300,
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: imageUrl.isNotEmpty
                      ? _buildAutoLoadingImage(imageUrl)
                      : _buildPlaceholderImage(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('إغلاق'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteEmbroideryImage(docId, imageUrl);
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('حذف'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
