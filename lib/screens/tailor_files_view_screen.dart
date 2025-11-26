import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ============================================================================
/// نماذج البيانات
/// ============================================================================

class TailorColor {
  final String id;
  final String colorName;
  final String colorHex;
  final String? imageUrl;
  final String? glbModelUrl;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  TailorColor({
    required this.id,
    required this.colorName,
    required this.colorHex,
    this.imageUrl,
    this.glbModelUrl,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory TailorColor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TailorColor(
      id: doc.id,
      colorName: (data['colorName'] ?? '').toString(),
      colorHex: (data['colorHex'] ?? '#000000').toString(),
      imageUrl: (data['imageUrl'] as String?),
      glbModelUrl: (data['glbModelUrl'] as String?),
      isAvailable: (data['isAvailable'] ?? true) as bool,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class TailorFile {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType; // image | 3d_model
  final int fileSize;
  final DateTime uploadedAt;
  final Map<String, dynamic>? metadata;

  TailorFile({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
    this.metadata,
  });

  factory TailorFile.fromFirestore(DocumentSnapshot doc, String type) {
    final data = doc.data() as Map<String, dynamic>;
    return TailorFile(
      id: doc.id,
      fileName: (data['imageName'] ?? data['modelName'] ?? 'ملف').toString(),
      fileUrl: (data['imageUrl'] ?? data['modelUrl'] ?? '').toString(),
      fileType: type,
      fileSize: (data['compressedSize'] ?? data['optimizedSize'] ?? 0) as int,
      uploadedAt: _parseDateTime(data['createdAt']),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

DateTime _parseDateTime(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

/// ============================================================================
/// الشاشة
/// ============================================================================

class TailorFilesViewScreen extends StatefulWidget {
  final String tailorId;
  final String tailorName;

  const TailorFilesViewScreen({
    Key? key,
    required this.tailorId,
    required this.tailorName,
  }) : super(key: key);

  @override
  State<TailorFilesViewScreen> createState() => _TailorFilesViewScreenState();
}

class _TailorFilesViewScreenState extends State<TailorFilesViewScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  late final TabController _tab;

  // ستريمات مباشرة (Realtime)
  Stream<QuerySnapshot<Map<String, dynamic>>> get _colorsStream =>
      _db.collection('tailors').doc(widget.tailorId).collection('colors').orderBy('updatedAt', descending: true).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _imagesStream =>
      _db.collection('tailors').doc(widget.tailorId).collection('images').orderBy('createdAt', descending: true).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _modelsStream =>
      _db.collection('tailors').doc(widget.tailorId).collection('3d_models').orderBy('createdAt', descending: true).snapshots();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// ========================================================================
  /// واجهة المستخدم
  /// ========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildHeader(),
          _buildTabs(),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _colorsTab(),
            _imagesTab(),
            _modelsTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  /// -------------------- SliverAppBar (العنوان + الإحصاءات) -------------------
  SliverAppBar _buildHeader() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 230,
      backgroundColor: Colors.teal,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.maybePop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF009688), Color(0xFF00695C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملفات الخياط',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.tailorName,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  const SizedBox(height: 12),
                  _statsRow(),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: _showTailorInfo,
        ),
      ],
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        // كل عنصر إحصائي مبني على ستريم لحظي
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _colorsStream,
            builder: (_, s) => _statCard('الألوان', (s.data?.docs.length ?? 0).toString(), Icons.palette),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _imagesStream,
            builder: (_, s) => _statCard('الصور', (s.data?.docs.length ?? 0).toString(), Icons.image),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _modelsStream,
            builder: (_, s) => _statCard('النماذج', (s.data?.docs.length ?? 0).toString(), Icons.view_in_ar),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// -------------------------- Tabs (مثبّتة) ----------------------------------
  SliverPersistentHeader _buildTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabsHeader(
        TabBar(
          controller: _tab,
          isScrollable: false,
          labelPadding: const EdgeInsets.symmetric(vertical: 6),
          indicator: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(12),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[700],
          tabs: const [
            Tab(icon: Icon(Icons.palette, size: 20), text: 'الألوان'),
            Tab(icon: Icon(Icons.image, size: 20), text: 'الصور'),
            Tab(icon: Icon(Icons.view_in_ar, size: 20), text: 'النماذج'),
          ],
        ),
      ),
    );
  }

  /// ---------------------------- محتوى التبويبات ------------------------------
  Widget _colorsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _colorsStream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _errorBox('خطأ في تحميل الألوان: ${snap.error}');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _empty('لا توجد ألوان', Icons.palette);

        final colors = docs.map((d) => TailorColor.fromFirestore(d)).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: colors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _colorCard(colors[i]),
        );
      },
    );
  }

  Widget _imagesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _imagesStream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _errorBox('خطأ في تحميل الصور: ${snap.error}');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _empty('لا توجد صور', Icons.image);

        final images = docs.map((d) => TailorFile.fromFirestore(d, 'image')).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8,
          ),
          itemCount: images.length,
          itemBuilder: (_, i) => _imageCard(images[i]),
        );
      },
    );
  }

  Widget _modelsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _modelsStream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _errorBox('خطأ في تحميل النماذج: ${snap.error}');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _empty('لا توجد نماذج ثلاثية الأبعاد', Icons.view_in_ar);

        final models = docs.map((d) => TailorFile.fromFirestore(d, '3d_model')).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: models.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _modelCard(models[i]),
        );
      },
    );
  }

  /// -------------------------------- بطاقات -----------------------------------
  Widget _colorCard(TailorColor color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _openAddOrEditColorSheet(existing: color),
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [BoxShadow(color: color.color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
          ),
        ),
        title: Text(color.colorName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            Text(color.colorHex, style: TextStyle(fontFamily: 'monospace', color: Colors.grey[600], fontSize: 12)),
            const SizedBox(width: 8),
            if (color.imageUrl != null) _chip(icon: Icons.image, label: 'صورة', color: Colors.blue),
            if (color.glbModelUrl != null) ...[
              const SizedBox(width: 4),
              _chip(icon: Icons.view_in_ar, label: 'نموذج 3D', color: Colors.purple),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'toggle') _toggleAvailability(color);
            if (v == 'edit') _openAddOrEditColorSheet(existing: color);
            if (v == 'delete') _deleteColor(color);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(color.isAvailable ? Icons.visibility_off : Icons.visibility, size: 18),
                const SizedBox(width: 8),
                Text(color.isAvailable ? 'تعطيل التوفر' : 'تفعيل التوفر'),
              ]),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('حذف')]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageCard(TailorFile image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصورة + زر القائمة
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: image.fileUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      child: PopupMenuButton<String>(
                        iconColor: Colors.white,
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (v) {
                          if (v == 'view') _viewImage(image);
                          if (v == 'rename') _renameImage(image);
                          if (v == 'replace') _replaceImageFile(image);
                          if (v == 'delete') _deleteImage(image);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'view', child: Text('عرض')),
                          PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
                          PopupMenuItem(value: 'replace', child: Text('استبدال الملف')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 6), Text('حذف')]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // معلومات
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(image.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(image.formattedSize, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Text(_fmt(image.uploadedAt), style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _modelCard(TailorFile model) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.deepPurple, Colors.purpleAccent.shade200], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.view_in_ar_rounded, color: Colors.white),
        ),
        title: Text(model.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            _chipText(model.formattedSize, Colors.purple),
            const SizedBox(width: 8),
            Text(_fmt(model.uploadedAt), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'open') _viewModel(model);
            if (v == 'rename') _renameModel(model);
            if (v == 'replace') _replaceModelFile(model);
            if (v == 'delete') _deleteModel(model);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('فتح/عرض')),
            PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
            PopupMenuItem(value: 'replace', child: Text('استبدال الملف')),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 6), Text('حذف')]),
            ),
          ],
        ),
      ),
    );
  }

  /// -------------------------------- حالات ------------------------------------
  Widget _empty(String msg, IconData icon) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: Colors.grey[400], size: 62)),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('لم يتم رفع أي ملفات من هذا النوع بعد', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ],
    ),
  );

  Widget _errorBox(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: Colors.red[400], size: 56),
        const SizedBox(height: 10),
        Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[600])),
      ]),
    ),
  );

  /// ------------------------------ FAB ----------------------------------------
  Widget _buildFab() {
    if (_tab.index == 0) {
      return FloatingActionButton.extended(
        onPressed: () => _openAddOrEditColorSheet(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة لون'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      );
    } else if (_tab.index == 1) {
      return FloatingActionButton.extended(
        onPressed: _addImage,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('رفع صورة'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: _addModel,
        icon: const Icon(Icons.add_to_photos),
        label: const Text('رفع نموذج 3D'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      );
    }
  }

  /// ---------------------- BottomSheet: إضافة/تعديل لون -----------------------
  void _openAddOrEditColorSheet({TailorColor? existing}) {
    final nameCtrl = TextEditingController(text: existing?.colorName ?? '');
    final hexCtrl = TextEditingController(text: existing?.colorHex ?? '#');
    String? imageUrl = existing?.imageUrl;
    String? glbUrl = existing?.glbModelUrl;
    bool available = existing?.isAvailable ?? true;

    Color preview = existing?.color ?? Colors.grey;

    void updatePreview() {
      try {
        final hex = hexCtrl.text.trim();
        if (hex.startsWith('#') && (hex.length == 7 || hex.length == 9)) {
          preview = Color(int.parse(hex.replaceFirst('#', '0xFF')));
        }
      } catch (_) {
        preview = Colors.grey;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16, right: 16, top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setM) {
              return SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 10),
                  Text(existing == null ? 'إضافة لون جديد' : 'تعديل اللون',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: preview,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'اسم اللون', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: hexCtrl,
                    onChanged: (_) => setM(() => updatePreview()),
                    decoration: const InputDecoration(
                      labelText: 'كود اللون HEX (مثل #C62828)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _presetHexes.map((hex) {
                      return InkWell(
                        onTap: () {
                          hexCtrl.text = hex;
                          setM(() {
                            updatePreview();
                          });
                        },
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  _uploadRow(
                    title: 'صورة اللون (اختياري)',
                    currentUrl: imageUrl,
                    onUpload: () async {
                      final url = await _pickAndUpload(
                        storePath: 'tailors/${widget.tailorId}/colors',
                        fileType: FileType.image,
                        contentType: 'image/*',
                        namePrefix: existing?.id ?? null,
                      );
                      if (url != null) setM(() => imageUrl = url);
                    },
                    onClear: () => setM(() => imageUrl = null),
                  ),
                  const SizedBox(height: 12),

                  _uploadRow(
                    title: 'نموذج GLB (اختياري)',
                    currentUrl: glbUrl,
                    onUpload: () async {
                      final url = await _pickAndUpload(
                        storePath: 'tailors/${widget.tailorId}/colors',
                        fileType: FileType.custom,
                        allowedExtensions: const ['glb'],
                        contentType: 'model/gltf-binary',
                        namePrefix: existing?.id ?? null,
                      );
                      if (url != null) setM(() => glbUrl = url);
                    },
                    onClear: () => setM(() => glbUrl = null),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Switch(
                        value: available,
                        activeColor: Colors.teal,
                        onChanged: (v) => setM(() => available = v),
                      ),
                      const SizedBox(width: 8),
                      const Text('متوفر حالياً'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(existing == null ? 'حفظ' : 'تحديث'),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final hex = hexCtrl.text.trim().toUpperCase();

                        if (name.isEmpty || !_isValidHex(hex)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تحقق من اسم اللون وكود HEX الصحيح')),
                          );
                          return;
                        }

                        try {
                          final colRef = _db.collection('tailors').doc(widget.tailorId).collection('colors');

                          if (existing == null) {
                            final doc = colRef.doc();
                            await doc.set({
                              'colorName': name,
                              'colorHex': hex,
                              'imageUrl': imageUrl,
                              'glbModelUrl': glbUrl,
                              'isAvailable': available,
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await colRef.doc(existing.id).update({
                              'colorName': name,
                              'colorHex': hex,
                              'imageUrl': imageUrl,
                              'glbModelUrl': glbUrl,
                              'isAvailable': available,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          }

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(existing == null ? 'تمت إضافة اللون' : 'تم تحديث اللون')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        );
      },
    );
  }

  final List<String> _presetHexes = const [
    '#000000', '#FFFFFF', '#C62828', '#AD1457', '#6A1B9A', '#283593', '#1565C0',
    '#00897B', '#2E7D32', '#9E9D24', '#EF6C00', '#4E342E', '#607D8B',
  ];

  /// ============================ عمليات الصور ============================

  Future<void> _addImage() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      final ext = (file.extension?.isNotEmpty ?? false) ? '.${file.extension}' : '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final path = 'tailors/${widget.tailorId}/images/$fileName';

      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/*'));
      final url = await ref.getDownloadURL();

      await _db.collection('tailors').doc(widget.tailorId).collection('images').add({
        'imageName': file.name,
        'imageUrl': url,
        'compressedSize': bytes.length,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {'ext': ext},
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الصورة')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الصورة: $e')));
    }
  }

  Future<void> _renameImage(TailorFile f) async {
    final ctrl = TextEditingController(text: f.fileName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تسمية الصورة'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    final newName = ctrl.text.trim();
    if (newName.isEmpty) return;

    try {
      await _db.collection('tailors').doc(widget.tailorId).collection('images').doc(f.id).update({
        'imageName': newName,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الاسم')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }

  Future<void> _replaceImageFile(TailorFile f) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      // ارفع الجديد
      final ext = (file.extension?.isNotEmpty ?? false) ? '.${file.extension}' : '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final path = 'tailors/${widget.tailorId}/images/$fileName';
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/*'));
      final url = await ref.getDownloadURL();

      // حدّث الوثيقة
      await _db.collection('tailors').doc(widget.tailorId).collection('images').doc(f.id).update({
        'imageUrl': url,
        'imageName': file.name,
        'compressedSize': bytes.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // احذف القديم من التخزين (اختياري)
      try {
        await _storage.refFromURL(f.fileUrl).delete();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استبدال الملف')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاستبدال: $e')));
    }
  }

  Future<void> _deleteImage(TailorFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الصورة'),
        content: Text('هل تريد حذف "${f.fileName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.collection('tailors').doc(widget.tailorId).collection('images').doc(f.id).delete();
      try {
        await _storage.refFromURL(f.fileUrl).delete();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الصورة')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  void _viewImage(TailorFile f) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: CachedNetworkImage(
          imageUrl: f.fileUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
          errorWidget: (_, __, ___) => const SizedBox(height: 300, child: Center(child: Icon(Icons.broken_image))),
        ),
      ),
    );
  }

  /// ============================ عمليات النماذج ============================

  Future<void> _addModel() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['glb'],
      withData: true,
    );
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      final ext = (file.extension?.isNotEmpty ?? false) ? '.${file.extension}' : '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final path = 'tailors/${widget.tailorId}/3d_models/$fileName';

      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'model/gltf-binary'));
      final url = await ref.getDownloadURL();

      await _db.collection('tailors').doc(widget.tailorId).collection('3d_models').add({
        'modelName': file.name,
        'modelUrl': url,
        'optimizedSize': bytes.length,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {'ext': ext},
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع النموذج')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع النموذج: $e')));
    }
  }

  Future<void> _renameModel(TailorFile f) async {
    final ctrl = TextEditingController(text: f.fileName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تسمية النموذج'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    final newName = ctrl.text.trim();
    if (newName.isEmpty) return;

    try {
      await _db.collection('tailors').doc(widget.tailorId).collection('3d_models').doc(f.id).update({
        'modelName': newName,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الاسم')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }

  Future<void> _replaceModelFile(TailorFile f) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['glb'],
      withData: true,
    );
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      final ext = (file.extension?.isNotEmpty ?? false) ? '.${file.extension}' : '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final path = 'tailors/${widget.tailorId}/3d_models/$fileName';
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'model/gltf-binary'));
      final url = await ref.getDownloadURL();

      await _db.collection('tailors').doc(widget.tailorId).collection('3d_models').doc(f.id).update({
        'modelUrl': url,
        'modelName': file.name,
        'optimizedSize': bytes.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await _storage.refFromURL(f.fileUrl).delete();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استبدال النموذج')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاستبدال: $e')));
    }
  }

  Future<void> _deleteModel(TailorFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف النموذج'),
        content: Text('هل تريد حذف "${f.fileName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.collection('tailors').doc(widget.tailorId).collection('3d_models').doc(f.id).delete();
      try {
        await _storage.refFromURL(f.fileUrl).delete();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف النموذج')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  /// ------------------------------ أدوات رفع عامّة ----------------------------

  Future<String?> _pickAndUpload({
    required String storePath,
    required FileType fileType,
    String? contentType,
    List<String>? allowedExtensions,
    String? namePrefix,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: fileType,
        allowedExtensions: allowedExtensions,
      );
      if (result == null) return null;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر قراءة الملف')));
        return null;
      }

      final ext = (file.extension?.isNotEmpty == true) ? '.${file.extension}' : '';
      final fileName = '${namePrefix ?? DateTime.now().millisecondsSinceEpoch}$ext';

      final ref = _storage.ref('$storePath/$fileName');
      final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
      await task;
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
      return null;
    }
  }

  Future<void> _toggleAvailability(TailorColor color) async {
    try {
      await _db
          .collection('tailors').doc(widget.tailorId)
          .collection('colors').doc(color.id)
          .update({'isAvailable': !color.isAvailable, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }

  Future<void> _deleteColor(TailorColor color) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف اللون'),
        content: Text('هل تريد حذف "${color.colorName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.collection('tailors').doc(widget.tailorId).collection('colors').doc(color.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  /// ------------------------------ أدوات صغيرة --------------------------------
  Widget _chip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _chipText(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _uploadRow({
    required String title,
    required String? currentUrl,
    required VoidCallback onUpload,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (currentUrl != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'إزالة',
          ),
        ElevatedButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.cloud_upload),
          label: Text(currentUrl == null ? 'رفع' : 'إعادة الرفع'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  void _showTailorInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('معلومات الخياط'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاسم: ${widget.tailorName}'),
            Text('المعرف: ${widget.tailorId}'),
            const SizedBox(height: 12),
            const Text('تلميح: الإحصائيات تتحدّث تلقائيًا من الداتا.'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  void _viewModel(TailorFile model) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('عرض النموذج: ${model.fileName}'), action: SnackBarAction(label: 'فتح', onPressed: () {})),
    );
  }

  bool _isValidHex(String s) {
    final r = RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
    return r.hasMatch(s);
  }
}

/// ============================================================================
/// Delegate لضبط شريط التبويب المثبّت بارتفاع مريح يمنع الـ overflow
/// ============================================================================
class _TabsHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabsHeader(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: tabBar);
  }

  @override
  double get minExtent => tabBar.preferredSize.height + 28;

  @override
  double get maxExtent => tabBar.preferredSize.height + 28;

  @override
  bool shouldRebuild(covariant _TabsHeader oldDelegate) => oldDelegate.tabBar != tabBar;
}
