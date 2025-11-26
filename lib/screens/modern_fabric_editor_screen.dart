import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/fabric_model.dart';
import '../services/screen_orientation_service.dart';
import '../widgets/optimized_image_widget.dart';

/// ============================================================================
/// 🎨 شاشة محرر الخامات الحديثة والعصرية
/// ============================================================================

class ModernFabricEditorScreen extends StatefulWidget {
  final Fabric? fabric;
  final User? currentUser;
  final Function(Fabric) onSave;

  const ModernFabricEditorScreen({
    super.key,
    this.fabric,
    required this.currentUser,
    required this.onSave,
  });

  @override
  State<ModernFabricEditorScreen> createState() =>
      _ModernFabricEditorScreenState();
}

class _ModernFabricEditorScreenState extends State<ModernFabricEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _colorController;
  late final TextEditingController _quantityController;
  late final TextEditingController _originController;

  // Values
  String _selectedType = 'قطن';
  String _selectedQuality = 'جيد';
  List<FabricColor> _availableColors = [];

  // Image
  Uint8List? _localImageBytes;
  String? _uploadedImageUrl;
  double _uploadProgress = 0;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // تعيين تدوير الشاشة لمحرر الخامات (تلقائي للصور)
    ScreenOrientationService.setOrientationForScreen('fabric_editor');

    _tabController = TabController(length: 3, vsync: this);

    // Initialize controllers
    final fabric = widget.fabric;
    _nameController = TextEditingController(text: fabric?.name ?? '');
    _descriptionController = TextEditingController(
      text: fabric?.description ?? '',
    );
    _colorController = TextEditingController(text: fabric?.color ?? '');
    _quantityController = TextEditingController(
      text: fabric?.quantity.toString() ?? '',
    );
    _originController = TextEditingController(text: fabric?.origin ?? '');

    if (fabric != null) {
      _selectedType = fabric.type.isNotEmpty ? fabric.type : 'قطن';
      _selectedQuality = fabric.quality.isNotEmpty ? fabric.quality : 'جيد';
      _uploadedImageUrl = fabric.imageUrl;
      _availableColors = List.from(fabric.availableColors);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _colorController.dispose();
    _quantityController.dispose();
    _originController.dispose();
    super.dispose();
  }

  void _showImageSourceDialog() {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'اختر مصدر الصورة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.photo_library,
                    title: 'المعرض',
                    subtitle: 'اختيار من الصور المحفوظة',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.gallery);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    title: 'الكاميرا',
                    subtitle: 'التصوير المباشر',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.camera);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.teal, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _localImageBytes = bytes;
        _isUploading = true;
        _uploadProgress = 0;
      });

      // Upload to Firebase Storage
      final ext = picked.name.split('.').last.toLowerCase();
      final contentType = (ext == 'png') ? 'image/png' : 'image/jpeg';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'fabric_${widget.currentUser?.uid}_$ts.$ext';
      final path = 'fabrics/${widget.currentUser?.uid}/$fileName';

      final ref = firebase_storage.FirebaseStorage.instance.ref().child(path);
      final uploadTask = ref.putData(
        bytes,
        firebase_storage.SettableMetadata(contentType: contentType),
      );

      uploadTask.snapshotEvents.listen((event) {
        setState(() {
          _uploadProgress = event.bytesTransferred / event.totalBytes;
        });
      });

      await uploadTask;
      final url = await ref.getDownloadURL();

      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم رفع الصورة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في رفع الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addColor() {
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        onColorSelected: (colorName, colorHex) {
          setState(() {
            _availableColors.add(
              FabricColor(colorName: colorName, colorHex: colorHex),
            );
          });
        },
      ),
    );
  }

  Future<void> _captureColorsFromImage(ImageSource source) async {
    try {
      final List<XFile> pickedFiles;

      // اختيار الصور حسب المصدر
      if (source == ImageSource.gallery) {
        // فتح المعرض لاختيار عدة صور
        pickedFiles = await _picker.pickMultiImage(imageQuality: 85);
      } else {
        // فتح الكاميرا لالتقاط صورة واحدة
        final pickedFile = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );

        pickedFiles = pickedFile != null ? [pickedFile] : [];
      }

      if (pickedFiles.isEmpty) return;

      // معالجة كل صورة على حدة
      for (int i = 0; i < pickedFiles.length; i++) {
        final XFile picked = pickedFiles[i];

        // رفع الصورة إلى Firebase Storage
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();
        final contentType = (ext == 'png') ? 'image/png' : 'image/jpeg';
        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = 'fabrics/${widget.currentUser?.uid}/color_${ts}_$i.$ext';

        final ref = firebase_storage.FirebaseStorage.instance.ref().child(path);
        final uploadTask = ref.putData(
          bytes,
          firebase_storage.SettableMetadata(contentType: contentType),
        );

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // استخراج الألوان الفعلية من الصورة
        final colors = await _extractRealColorsFromImage(bytes);

        // إضافة الألوان مع رابط الصورة
        setState(() {
          _availableColors.addAll(
            colors.map(
              (color) => FabricColor(
                colorName: color['name']!,
                colorHex: color['hex']!,
                imageUrl: downloadUrl,
              ),
            ),
          );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم رفع ${pickedFiles.length} صورة واستخراج الألوان'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في رفع صور الألوان: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة مساعدة لاستخراج الألوان الفعلية من الصورة
  Future<List<Map<String, String>>> _extractRealColorsFromImage(
    Uint8List imageBytes,
  ) async {
    try {
      // إنشاء صورة من bytes
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // استخدام palette_generator لاستخراج الألوان
      final paletteGenerator = await PaletteGenerator.fromImage(image);

      List<Map<String, String>> colors = [];

      // استخراج الألوان السائدة (Vibrant)
      if (paletteGenerator.vibrantColor != null) {
        final color = paletteGenerator.vibrantColor!;
        colors.add({
          'name': _getColorName(color.color),
          'hex': _colorToHex(color.color),
        });
      }

      // استخراج الألوان الناعمة (Light Vibrant)
      if (paletteGenerator.lightVibrantColor != null) {
        final color = paletteGenerator.lightVibrantColor!;
        colors.add({
          'name': _getColorName(color.color),
          'hex': _colorToHex(color.color),
        });
      }

      // استخراج الألوان الغامقة (Dark Vibrant)
      if (paletteGenerator.darkVibrantColor != null) {
        final color = paletteGenerator.darkVibrantColor!;
        colors.add({
          'name': _getColorName(color.color),
          'hex': _colorToHex(color.color),
        });
      }

      // استخراج الألوان الناعمة (Muted)
      if (paletteGenerator.mutedColor != null) {
        final color = paletteGenerator.mutedColor!;
        colors.add({
          'name': _getColorName(color.color),
          'hex': _colorToHex(color.color),
        });
      }

      // استخراج الألوان الغامقة (Dark Muted)
      if (paletteGenerator.darkMutedColor != null) {
        final color = paletteGenerator.darkMutedColor!;
        colors.add({
          'name': _getColorName(color.color),
          'hex': _colorToHex(color.color),
        });
      }

      // استخراج الألوان الفاتحة (Light Muted)
      if (paletteGenerator.lightMutedColor != null) {
        final color = paletteGenerator.lightMutedColor!;
        colors.add({
          'name': _getColorName(color.color),
          'hex': _colorToHex(color.color),
        });
      }

      // إضافة ألوان إضافية من Palette
      final dominantColors = paletteGenerator.colors.toList();
      for (int i = 0; i < dominantColors.length && i < 3; i++) {
        final colorValue = dominantColors[i];
        colors.add({
          'name': _getColorName(colorValue),
          'hex': _colorToHex(colorValue),
        });
      }

      return colors.take(6).toList(); // أقصى 6 ألوان
    } catch (e) {
      debugPrint('خطأ في استخراج الألوان: $e');
      // في حالة الخطأ، أرجع ألوان افتراضية
      return _getDefaultColors();
    }
  }

  // تحويل Color إلى hex
  String _colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  // تحديد اسم اللون حسب قيم RGB
  String _getColorName(Color color) {
    final r = (color.r * 255).round() & 0xff;
    final g = (color.g * 255).round() & 0xff;
    final b = (color.b * 255).round() & 0xff;

    // تحديد اللون حسب القيم
    if (r > 200 && g < 100 && b < 100) return 'أحمر';
    if (r < 100 && g > 200 && b < 100) return 'أخضر';
    if (r < 100 && g < 100 && b > 200) return 'أزرق';
    if (r > 200 && g > 200 && b < 100) return 'أصفر';
    if (r > 200 && g > 150 && b < 100) return 'برتقالي';
    if (r > 180 && g > 120 && b > 180) return 'بنفسجي';
    if (r > 200 && g < 150 && b > 200) return 'وردي';
    if (r > 100 && g > 200 && b > 200) return 'فيروزي';
    if (r > 150 && g > 150 && b > 150) return 'رمادي فاتح';
    if (r < 100 && g < 100 && b < 100) return 'رمادي غامق';
    if (r > 150 && g > 150 && b < 100) return 'أخضر مصفر';
    if (r < 150 && g > 200 && b > 200) return 'أزرق فاتح';

    return 'لون مخصص';
  }

  // ألوان افتراضية في حالة الخطأ
  List<Map<String, String>> _getDefaultColors() {
    return [
      {'name': 'لون الخامة', 'hex': '#808080'},
      {'name': 'لون ثانوي', 'hex': '#A0A0A0'},
      {'name': 'لون إضافي', 'hex': '#B0B0B0'},
    ];
  }

  void _removeColor(int index) {
    setState(() {
      _availableColors.removeAt(index);
    });
  }

  // معالجة إجراءات تدوير الشاشة
  void _handleOrientationAction(String action) async {
    switch (action) {
      case 'portrait':
        await ScreenOrientationService.lockToPortrait();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قفل الشاشة في الوضع العمودي'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case 'landscape':
        await ScreenOrientationService.lockToLandscape();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قفل الشاشة في الوضع الأفقي'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case 'auto':
        await ScreenOrientationService.allowAllOrientations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم السماح بجميع أوضاع الشاشة'),
            backgroundColor: Colors.green,
          ),
        );
        break;
    }
  }

  Future<void> _saveFabric() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final fabric = Fabric(
        id: widget.fabric?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        color: _colorController.text.trim(),
        quantity: double.tryParse(_quantityController.text) ?? 0,
        pricePerMeter: 0, // قيمة افتراضية
        supplier: '', // قيمة افتراضية
        origin: _originController.text.trim(),
        composition: '', // قيمة افتراضية
        width: 0, // قيمة افتراضية
        careInstructions: '', // قيمة افتراضية
        quality: _selectedQuality,
        season: '', // قيمة افتراضية
        isAvailable: true,
        lastUpdated: DateTime.now(),
        createdBy: widget.currentUser?.uid ?? '',
        createdAt: widget.fabric?.createdAt ?? DateTime.now(),
        availableColors: _availableColors,
        imageUrl: _uploadedImageUrl,
      );

      widget.onSave(fabric);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.fabric == null ? '➕ إضافة خامة جديدة' : '✏️ تعديل الخامة',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
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
          if (!_isSaving)
            TextButton.icon(
              onPressed: _saveFabric,
              icon: const Icon(Icons.save, size: 20),
              label: const Text('حفظ'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'المعلومات الأساسية'),
            Tab(icon: Icon(Icons.image), text: 'الصورة'),
            Tab(icon: Icon(Icons.palette), text: 'الألوان المتوفرة'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [_buildBasicInfoTab(), _buildImageTab(), _buildColorsTab()],
        ),
      ),
    );
  }

  // ======================== Tab 1: المعلومات الأساسية ========================
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('📝 معلومات الخامة'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nameController,
            label: 'اسم الخامة *',
            hint: 'مثال: قماش قطني فاخر',
            icon: Icons.label,
            validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionController,
            label: 'الوصف *',
            hint: 'أدخل وصف تفصيلي للخامة',
            icon: Icons.description,
            maxLines: 3,
            validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'النوع *',
                  value: _selectedType,
                  items: ['قطن', 'حرير', 'صوف', 'كتان', 'مخلوط'],
                  icon: Icons.category,
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _colorController,
                  label: 'اللون الأساسي',
                  hint: 'أبيض',
                  icon: Icons.color_lens,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _quantityController,
            label: 'الكمية (متر) *',
            hint: '100',
            icon: Icons.straighten,
            keyboardType: TextInputType.number,
            validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _originController,
                  label: 'بلد المنشأ',
                  hint: 'مصر',
                  icon: Icons.flag,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'الجودة *',
                  value: _selectedQuality,
                  items: ['فاخر', 'ممتاز', 'جيد'],
                  icon: Icons.star,
                  onChanged: (value) =>
                      setState(() => _selectedQuality = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ======================== Tab 2: الصورة ========================
  Widget _buildImageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('📸 صورة الخامة'),
          const SizedBox(height: 8),
          const Text(
            'أضف صورة واضحة للخامة لتسهيل التعرف عليها',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                // Preview area
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child:
                      _localImageBytes != null ||
                          (_uploadedImageUrl?.isNotEmpty ?? false)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _localImageBytes != null
                              ? Image.memory(
                                  _localImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : OptimizedLargeImageWidget(
                                  imageUrl: _uploadedImageUrl,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد صورة',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اضغط على الزر أدناه لإضافة صورة',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                // Upload button
                if (_isUploading)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'جاري الرفع... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(
                          _uploadedImageUrl == null
                              ? 'رفع صورة'
                              : 'تغيير الصورة',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_uploadedImageUrl != null) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _uploadedImageUrl = null;
                              _localImageBytes = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('إزالة'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الصور تُحفظ تلقائياً في Firebase Storage بجودة محسّنة',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================== Tab 3: الألوان المتوفرة ========================
  Widget _buildColorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🎨 الألوان المتوفرة'),
          const SizedBox(height: 8),
          const Text(
            'أضف الألوان المتوفرة من هذه الخامة لتسهيل الاختيار على العملاء',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          // Add color buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addColor,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('إضافة لون'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // فتح الألبوم مباشرة عند الضغط على زر "تصوير الخامة"
                    _captureColorsFromImage(ImageSource.gallery);
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('تصوير الخامة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Colors list
          if (_availableColors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لم يتم إضافة ألوان بعد',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط على الزر أعلاه لإضافة الألوان المتوفرة',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                return _buildColorItem(color, index);
              },
            ),
          const SizedBox(height: 16),
          if (_availableColors.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✓ تم إضافة ${_availableColors.length} لون${_availableColors.length > 1 ? '' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorItem(FabricColor color, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Color preview with image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
            child: OptimizedSmallImageWidget(
              imageUrl: color.imageUrl,
              size: 50,
              fallbackColor: Color(
                int.parse(color.colorHex.replaceFirst('#', '0xFF')),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 16),
          // Color info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  color.colorName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  color.colorHex,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            onPressed: () => _removeColor(index),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'حذف اللون',
          ),
        ],
      ),
    );
  }

  // ======================== Helper Widgets ========================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.teal) : null,
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
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    IconData? icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.teal) : null,
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
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// ============================================================================
/// 🎨 نافذة اختيار اللون
/// ============================================================================

class _ColorPickerDialog extends StatefulWidget {
  final Function(String colorName, String colorHex) onColorSelected;

  const _ColorPickerDialog({required this.onColorSelected});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  final TextEditingController _colorNameController = TextEditingController();
  Color _selectedColor = Colors.red;

  // الألوان الشائعة للاختيار السريع
  final List<Map<String, dynamic>> _commonColors = [
    {'name': 'أحمر', 'color': Colors.red},
    {'name': 'أزرق', 'color': Colors.blue},
    {'name': 'أخضر', 'color': Colors.green},
    {'name': 'أصفر', 'color': Colors.yellow},
    {'name': 'برتقالي', 'color': Colors.orange},
    {'name': 'بنفسجي', 'color': Colors.purple},
    {'name': 'وردي', 'color': Colors.pink},
    {'name': 'بني', 'color': Colors.brown},
    {'name': 'رمادي', 'color': Colors.grey},
    {'name': 'أسود', 'color': Colors.black},
    {'name': 'أبيض', 'color': Colors.white},
    {'name': 'كريمي', 'color': const Color(0xFFFFF8DC)},
  ];

  @override
  void dispose() {
    _colorNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.palette,
                      color: Colors.teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إضافة لون جديد',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'اختر اللون وأدخل الاسم',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Color preview
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Color name input
              TextField(
                controller: _colorNameController,
                decoration: InputDecoration(
                  labelText: 'اسم اللون',
                  hintText: 'مثال: أحمر داكن',
                  prefixIcon: const Icon(Icons.label, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'اختيار سريع:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Common colors grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _commonColors.length,
                itemBuilder: (context, index) {
                  final colorData = _commonColors[index];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorData['color'];
                        _colorNameController.text = colorData['name'];
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorData['color'],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedColor == colorData['color']
                              ? Colors.teal
                              : Colors.grey[300]!,
                          width: _selectedColor == colorData['color'] ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Custom color picker
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('اختيار لون مخصص'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: _selectedColor,
                          onColorChanged: (color) {
                            setState(() => _selectedColor = color);
                          },
                          pickerAreaHeightPercent: 0.8,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('تم'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.colorize),
                label: const Text('اختيار لون مخصص'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_colorNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى إدخال اسم اللون'),
                            ),
                          );
                          return;
                        }
                        final hexColor =
                            '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
                        widget.onColorSelected(
                          _colorNameController.text.trim(),
                          hexColor,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إضافة اللون'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
