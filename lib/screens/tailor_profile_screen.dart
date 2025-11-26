// lib/screens/tailor_profile_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

// ========= موديل بيانات الخياط =========
class TailorProfile {
  final String id;
  final String ownerName;
  final String shopName;
  final String email;
  final String phone;
  final String whatsapp;
  final String address;
  final String licenseNumber;
  final String profileImageUrl;
  final String description;
  final double rating;
  final int totalOrders;
  final String specialization;
  final bool isActive;
  final bool isVerified;
  final String userType;
  final String uid;
  final DateTime createdAt;
  final String createdBy;
  final Map<String, dynamic> location; // {address, latitude, longitude}
  final Map<String, dynamic> workingHours; // {start, end}
  final List<dynamic> gallery;
  final List<dynamic> services;

  TailorProfile({
    required this.id,
    required this.ownerName,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.whatsapp,
    required this.address,
    required this.licenseNumber,
    this.profileImageUrl = '',
    this.description = '',
    this.rating = 0.0,
    this.totalOrders = 0,
    this.specialization = '',
    this.isActive = true,
    this.isVerified = false,
    this.userType = 'tailor',
    required this.uid,
    required this.createdAt,
    required this.createdBy,
    this.location = const {},
    this.workingHours = const {},
    this.gallery = const [],
    this.services = const [],
  });

  // من Firestore
  factory TailorProfile.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    Map<String, dynamic> contact = {};
    if (data['contact'] is Map<String, dynamic>) contact = data['contact'];
    Map<String, dynamic> profile = {};
    if (data['profile'] is Map<String, dynamic>) profile = data['profile'];
    Map<String, dynamic> location = {};
    if (data['location'] is Map<String, dynamic>) location = data['location'];
    Map<String, dynamic> workingHours = {};
    if (data['workingHours'] is Map<String, dynamic>)
      workingHours = data['workingHours'];

    return TailorProfile(
      id: doc.id,
      ownerName: _s(data, 'ownerName'),
      shopName: _s(data, 'shopName'),
      email: _s(contact, 'email', fallback: _s(data, 'email')),
      phone: _s(contact, 'phone', fallback: _s(data, 'phone')),
      whatsapp: _s(contact, 'whatsapp'),
      address: _s(data, 'address', fallback: _s(location, 'address')),
      licenseNumber: _s(data, 'licenseNumber'),
      profileImageUrl: _s(profile, 'avatar'),
      description: _s(profile, 'description'),
      rating: _d(data, 'rating'),
      totalOrders: _i(data, 'totalOrders'),
      specialization: _s(data, 'specialization'),
      isActive: _b(data, 'isActive', def: true),
      isVerified: _b(data, 'isVerified'),
      userType: _s(data, 'userType', fallback: 'tailor'),
      uid: _s(data, 'uid', fallback: doc.id),
      createdAt: _dt(data, 'createdAt'),
      createdBy: _s(data, 'createdBy'),
      location: location,
      workingHours: workingHours,
      gallery: (data['gallery'] is List) ? data['gallery'] : const [],
      services: (data['services'] is List) ? data['services'] : const [],
    );
  }

  // إلى Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'ownerName': ownerName,
      'shopName': shopName,
      'address': address,
      'licenseNumber': licenseNumber,
      'rating': rating,
      'totalOrders': totalOrders,
      'specialization': specialization,
      'isActive': isActive,
      'isVerified': isVerified,
      'userType': userType,
      'uid': uid,
      'createdBy': createdBy,
      'contact': {'email': email, 'phone': phone, 'whatsapp': whatsapp},
      'profile': {'avatar': profileImageUrl, 'description': description},
      'location': location,
      'workingHours': workingHours,
      'gallery': gallery,
      'services': services,
    };
  }

  // تنسيقات عرض
  String getFormattedWorkingHours() {
    final s = workingHours['start']?.toString() ?? '';
    final e = workingHours['end']?.toString() ?? '';
    if (s.isEmpty || e.isEmpty) return 'غير محدد';
    return 'من $s إلى $e';
  }

  String getFormattedAddress() {
    if (location['address'] != null &&
        location['address'].toString().isNotEmpty) {
      return location['address'].toString();
    }
    return address.isNotEmpty ? address : 'غير محدد';
  }

  // copyWith
  TailorProfile copyWith({
    String? ownerName,
    String? shopName,
    String? email,
    String? phone,
    String? whatsapp,
    String? address,
    String? licenseNumber,
    String? profileImageUrl,
    String? description,
    double? rating,
    int? totalOrders,
    String? specialization,
    bool? isActive,
    bool? isVerified,
    String? userType,
    String? uid,
    DateTime? createdAt,
    String? createdBy,
    Map<String, dynamic>? location,
    Map<String, dynamic>? workingHours,
    List<dynamic>? gallery,
    List<dynamic>? services,
  }) {
    return TailorProfile(
      id: id,
      ownerName: ownerName ?? this.ownerName,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      specialization: specialization ?? this.specialization,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      userType: userType ?? this.userType,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      location: location ?? this.location,
      workingHours: workingHours ?? this.workingHours,
      gallery: gallery ?? this.gallery,
      services: services ?? this.services,
    );
  }

  // أدوات مساعدة
  static String _s(Map<String, dynamic> m, String k, {String fallback = ''}) {
    try {
      final v = m[k];
      return v == null ? fallback : v.toString();
    } catch (_) {
      return fallback;
    }
  }

  static double _d(Map<String, dynamic> m, String k, {double def = 0}) {
    try {
      final v = m[k];
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? def;
    } catch (_) {
      return def;
    }
  }

  static int _i(Map<String, dynamic> m, String k, {int def = 0}) {
    try {
      final v = m[k];
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? def;
    } catch (_) {
      return def;
    }
  }

  static bool _b(Map<String, dynamic> m, String k, {bool def = false}) {
    try {
      final v = m[k];
      if (v is bool) return v;
      final s = '$v'.toLowerCase();
      return s == 'true' || s == '1';
    } catch (_) {
      return def;
    }
  }

  static DateTime _dt(Map<String, dynamic> m, String k) {
    try {
      final v = m[k];
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }
}

// ========= خدمة مصادقة بسيطة =========
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static User? getCurrentUser() => _auth.currentUser;
  static Future<void> signOut() async => _auth.signOut();
  static bool isLoggedIn() => _auth.currentUser != null;
}

// ========= شاشة ملف الخياط =========
class TailorProfileScreen extends StatefulWidget {
  final String? tailorId;
  const TailorProfileScreen({super.key, this.tailorId});

  @override
  State<TailorProfileScreen> createState() => _TailorProfileScreenState();
}

class _TailorProfileScreenState extends State<TailorProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  TailorProfile? _p;
  bool _loading = true;
  bool _uploadingImage = false;
  String? _tailorId;
  String _err = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, .15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _init();
  }

  Future<void> _init() async {
    try {
      _tailorId = (widget.tailorId?.isNotEmpty ?? false)
          ? widget.tailorId
          : _auth.currentUser?.uid ?? 'i3ZSdx5x4FOuOOnChsw1HtvpoGy2';
      if (_tailorId == null) {
        setState(() {
          _loading = false;
          _err = 'لم يتم العثور على معرف الخياط';
        });
        return;
      }
      _listen();
      _ac.forward();
    } catch (e) {
      setState(() {
        _loading = false;
        _err = 'خطأ في التهيئة: $e';
      });
    }
  }

  void _listen() {
    _sub?.cancel();
    _sub = _fs
        .collection('tailors')
        .doc(_tailorId)
        .snapshots()
        .listen(
          (snap) {
            if (!snap.exists) {
              setState(() {
                _loading = false;
                _err = 'لا توجد بيانات.';
              });
              return;
            }
            setState(() {
              _p = TailorProfile.fromFirestore(snap);
              _loading = false;
              _err = '';
            });
          },
          onError: (e) {
            setState(() {
              _loading = false;
              _err = 'خطأ في الاتصال: $e';
            });
          },
        );
  }

  Future<void> _save(TailorProfile updated) async {
    try {
      final ref = _fs.collection('tailors').doc(_tailorId);
      final payload = updated.toFirestore()
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await ref.set(payload, SetOptions(merge: true));
      _ok('تم حفظ التعديلات');
    } catch (e) {
      _bad('خطأ في الحفظ: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ac.dispose();
    super.dispose();
  }

  // ====== رفع صورة البروفايل ======
  Future<void> _pickAndUploadProfileImage() async {
    if (_p == null) return;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر مصدر الصورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('الكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _uploadingImage = true);

      // رفع الصورة إلى Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${_tailorId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // تحديث البروفايل بالصورة الجديدة
      await _save(_p!.copyWith(profileImageUrl: downloadUrl));
      _ok('تم رفع الصورة بنجاح');
    } catch (e) {
      _bad('خطأ في رفع الصورة: $e');
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  // ====== تعديل الاسم ======
  Future<void> _editOwnerName() async {
    if (_p == null) return;

    // التحقق من صلاحية التعديل (مرة واحدة شهرياً)
    if (!await _canChangeName()) {
      if (mounted) {
        _bad(
          'يمكنك تغيير اسمك مرة واحدة فقط كل شهر. حاول مرة أخرى الشهر القادم.',
        );
      }
      return;
    }

    if (!mounted) return;

    final nameController = TextEditingController(text: _p!.ownerName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل اسم المالك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'يمكنك تغيير اسمك مرة واحدة فقط كل شهر',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المالك',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == _p!.ownerName) return;

    if (newName.length < 3) {
      _bad('الاسم يجب أن يكون 3 أحرف على الأقل');
      return;
    }

    try {
      // حفظ الاسم الجديد وتحديث تاريخ آخر تعديل
      await _saveWithNameChange(_p!.copyWith(ownerName: newName));
      _ok('تم تحديث الاسم بنجاح');
    } catch (e) {
      _bad('خطأ في تحديث الاسم: $e');
    }
  }

  // التحقق من إمكانية تغيير الاسم (مرة واحدة شهرياً)
  Future<bool> _canChangeName() async {
    try {
      final ref = _fs.collection('tailors').doc(_tailorId);
      final doc = await ref.get();

      if (!doc.exists) return true;

      final data = doc.data();
      final lastChangeDate = data?['lastNameChangeDate'] as Timestamp?;

      if (lastChangeDate == null) return true;

      final lastDate = lastChangeDate.toDate();
      final now = DateTime.now();

      // التحقق إذا كان الشهر الحالي مختلف عن الشهر السابق
      if (lastDate.year != now.year || lastDate.month != now.month) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('خطأ في التحقق من صلاحية تغيير الاسم: $e');
      return false;
    }
  }

  // حفظ مع تحديث تاريخ آخر تعديل للاسم
  Future<void> _saveWithNameChange(TailorProfile updated) async {
    try {
      final ref = _fs.collection('tailors').doc(_tailorId);
      final payload = updated.toFirestore()
        ..['updatedAt'] = FieldValue.serverTimestamp()
        ..['lastNameChangeDate'] = FieldValue.serverTimestamp();

      await ref.set(payload, SetOptions(merge: true));

      // إظهار رسالة نجاح
      if (mounted) {
        _ok('تم تحديث الاسم بنجاح. يمكنك تغييره مرة أخرى الشهر القادم.');
      }
    } catch (e) {
      if (mounted) {
        _bad('خطأ في الحفظ: $e');
      }
    }
  }

  // واجهة
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ملف التعريف',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'تعديل العنوان/الساعات/الوصف',
            icon: const Icon(Icons.edit, color: Colors.black54),
            onPressed: _p == null ? null : _openEditSheet,
          ),
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: () {
              setState(() => _loading = true);
              _listen();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_err.isNotEmpty || _p == null)
          ? Center(child: Text(_err.isEmpty ? 'لا توجد بيانات' : _err))
          : FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 24),
                        _section('المعلومات الشخصية', [
                          _rowWithAction(
                            Icons.person,
                            'اسم المالك',
                            _p!.ownerName,
                            icon: Icons.edit,
                            onActionTap: _editOwnerName,
                            tooltip: 'تعديل الاسم',
                          ),
                          _row(Icons.email, 'البريد الإلكتروني', _p!.email),
                          _row(Icons.badge, 'رقم الترخيص', _p!.licenseNumber),
                          _row(
                            Icons.account_circle,
                            'نوع المستخدم',
                            _p!.userType,
                          ),
                          _row(Icons.fingerprint, 'معرف المستخدم', _p!.uid),
                          _row(
                            Icons.calendar_today,
                            'تاريخ الإنشاء',
                            _formatDate(_p!.createdAt),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _section('معلومات المحل', [
                          _row(Icons.store, 'اسم المحل', _p!.shopName),
                          _row(
                            Icons.location_on,
                            'العنوان',
                            _p!.getFormattedAddress(),
                          ),
                          _row(
                            Icons.access_time,
                            'ساعات العمل',
                            _p!.getFormattedWorkingHours(),
                          ),
                          _row(Icons.description, 'الوصف', _p!.description),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _openEditSheet,
                                icon: const Icon(Icons.edit),
                                label: const Text(
                                  'تعديل العنوان/الساعات/الوصف',
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _pickOnMap,
                                icon: const Icon(Icons.map),
                                label: const Text('اختيار الموقع على الخريطة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _section('معلومات الاتصال', [
                          _row(Icons.phone, 'الهاتف', _p!.phone),
                          _row(Icons.email, 'البريد', _p!.email),
                          _row(Icons.chat, 'واتساب', _p!.whatsapp),
                        ]),
                        const SizedBox(height: 24),
                        _section('الإحصائيات', [
                          Row(
                            children: [
                              Expanded(
                                child: _stat(
                                  'إجمالي الطلبات',
                                  '${_p!.totalOrders}',
                                  Icons.shopping_bag,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _stat(
                                  'التقييم',
                                  _p!.rating.toStringAsFixed(1),
                                  Icons.star,
                                  Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _stat(
                                  'الحالة',
                                  _p!.isActive ? 'نشط' : 'غير نشط',
                                  _p!.isActive ? Icons.check : Icons.close,
                                  _p!.isActive ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _stat(
                                  'التحقق',
                                  _p!.isVerified ? 'محقق' : 'غير محقق',
                                  _p!.isVerified
                                      ? Icons.verified
                                      : Icons.pending,
                                  _p!.isVerified ? Colors.blue : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _section('الإجراءات', [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout),
                              label: const Text('تسجيل الخروج'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // Widgets مساعدة
  Widget _header() {
    final p = _p!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF26A69A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(.3),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _pickAndUploadProfileImage,
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: Colors.white,
                  backgroundImage: p.profileImageUrl.isNotEmpty
                      ? NetworkImage(p.profileImageUrl)
                      : null,
                  child: _uploadingImage
                      ? const CircularProgressIndicator(color: Colors.teal)
                      : (p.profileImageUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.teal,
                              )
                            : null),
                ),
              ),
              if (p.isVerified)
                const Positioned(
                  right: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.verified, color: Colors.white, size: 16),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadProfileImage,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.teal,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  p.ownerName.isEmpty ? 'خياط مجهول' : p.ownerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                onPressed: _editOwnerName,
                tooltip: 'تعديل الاسم',
              ),
            ],
          ),
          if (p.shopName.isNotEmpty)
            Text(
              p.shopName,
              style: TextStyle(color: Colors.white.withOpacity(.95)),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip(
                p.isActive ? 'نشط' : 'غير نشط',
                p.isActive ? Icons.check_circle : Icons.cancel,
                color: p.isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              if (p.specialization.isNotEmpty)
                _chip(p.specialization, Icons.work, color: Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: Colors.amber[600]),
              const SizedBox(width: 4),
              Text(
                '${p.rating.toStringAsFixed(1)} (${p.totalOrders} طلب)',
                style: TextStyle(color: Colors.white.withOpacity(.95)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon, {required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(.08),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget _row(IconData icon, String label, String value) {
    final empty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info, color: Colors.teal, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  empty ? 'غير محدد' : value,
                  style: TextStyle(
                    color: empty ? Colors.grey[400] : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowWithAction(
    IconData mainIcon,
    String label,
    String value, {
    required IconData icon,
    required VoidCallback onActionTap,
    String? tooltip,
  }) {
    final empty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info, color: Colors.teal, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  empty ? 'غير محدد' : value,
                  style: TextStyle(
                    color: empty ? Colors.grey[400] : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(icon, color: Colors.teal, size: 20),
            onPressed: onActionTap,
            tooltip: tooltip,
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  // ====== التحرير ======
  void _openEditSheet() {
    final p = _p!;
    final descCtrl = TextEditingController(text: p.description);
    final addrCtrl = TextEditingController(text: p.getFormattedAddress());
    String start = (p.workingHours['start'] ?? '08:00').toString();
    String end = (p.workingHours['end'] ?? '22:00').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'تعديل بيانات المحل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const Text('الوصف'),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(filled: true),
              ),
              const SizedBox(height: 12),
              const Text('العنوان النصي'),
              const SizedBox(height: 6),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(filled: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _timeBox('بداية الدوام', start, () async {
                      final r = await showTimePicker(
                        context: ctx,
                        initialTime:
                            _toTOD(start) ??
                            const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (r != null) setS(() => start = _fmtTOD(r));
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _timeBox('نهاية الدوام', end, () async {
                      final r = await showTimePicker(
                        context: ctx,
                        initialTime:
                            _toTOD(end) ?? const TimeOfDay(hour: 22, minute: 0),
                      );
                      if (r != null) setS(() => end = _fmtTOD(r));
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickOnMap();
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('اختيار الموقع على الخريطة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final newLoc = Map<String, dynamic>.from(p.location);
                        if (addrCtrl.text.trim().isNotEmpty)
                          newLoc['address'] = addrCtrl.text.trim();
                        await _save(
                          p.copyWith(
                            description: descCtrl.text.trim(),
                            address: addrCtrl.text.trim().isNotEmpty
                                ? addrCtrl.text.trim()
                                : p.address,
                            workingHours: {'start': start, 'end': end},
                            location: newLoc,
                          ),
                        );
                        if (mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeBox(String label, String value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.teal, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value')),
        ],
      ),
    ),
  );

  TimeOfDay? _toTOD(String s) {
    try {
      final p = s.split(':');
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    } catch (_) {
      return null;
    }
  }

  String _fmtTOD(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ====== فتح شاشة الخريطة ======
  Future<void> _pickOnMap() async {
    final p = _p!;
    final lat = (p.location['latitude'] as num?)?.toDouble();
    final lng = (p.location['longitude'] as num?)?.toDouble();
    final initial = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : const LatLng(23.5880, 58.3829);

    final result = await Navigator.push<_MapPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialPosition: initial),
        fullscreenDialog: true,
      ),
    );
    if (result != null) {
      await _save(
        p.copyWith(
          location: {
            'address': result.address ?? p.getFormattedAddress(),
            'latitude': result.position.latitude,
            'longitude': result.position.longitude,
          },
          address: result.address ?? p.address,
        ),
      );
    }
  }

  // ====== خروج ======
  Future<void> _logout() async {
    try {
      await AuthService.signOut();
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      _bad('خطأ في تسجيل الخروج: $e');
    }
  }

  void _ok(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green));
  void _bad(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
}

// ========= شاشة اختيار الموقع على الخريطة =========
class MapPickerScreen extends StatefulWidget {
  final LatLng initialPosition;
  const MapPickerScreen({super.key, required this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _controller;
  LatLng _picked = const LatLng(23.5880, 58.3829);
  Marker? _marker;
  bool _resolving = false;
  String? _resolvedAddress;
  MapType _mapType = MapType.normal;
  bool _goingMyLoc = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialPosition;
    _marker = Marker(
      markerId: const MarkerId('picked'),
      position: _picked,
      draggable: true,
      onDragEnd: (pos) {
        setState(() => _picked = pos);
        _resolveAddress(pos);
      },
    );
    _resolveAddress(_picked);
  }

  Future<void> _resolveAddress(LatLng pos) async {
    setState(() => _resolving = true);
    try {
      final p = await geocoding.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (p.isNotEmpty) {
        final a = p.first;
        final addr = [
          a.street,
          a.subLocality,
          a.locality,
          a.administrativeArea,
          a.country,
        ].where((e) => (e ?? '').toString().isNotEmpty).join(' - ');
        setState(() => _resolvedAddress = addr);
      } else {
        setState(() => _resolvedAddress = null);
      }
    } catch (_) {
      setState(() => _resolvedAddress = null);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _goMyLoc() async {
    setState(() => _goingMyLoc = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('خدمة الموقع غير مفعلة')));
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('يجب منح صلاحية الموقع')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = ll);
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(ll, 16));
      _resolveAddress(ll);
    } finally {
      if (mounted) setState(() => _goingMyLoc = false);
    }
  }

  Set<Circle> get _circles => {
    Circle(
      circleId: const CircleId('serviceArea'),
      center: _picked,
      radius: 1500,
      fillColor: Colors.teal.withOpacity(.15),
      strokeColor: Colors.teal,
      strokeWidth: 1,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار الموقع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'تأكيد',
            onPressed: () => Navigator.pop(
              context,
              _MapPickResult(position: _picked, address: _resolvedAddress),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _picked, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: _mapType,
            markers: _marker != null
                ? {_marker!.copyWith(positionParam: _picked)}
                : {},
            circles: _circles,
            onMapCreated: (c) => _controller = c,
            onTap: (pos) {
              setState(() => _picked = pos);
              _resolveAddress(pos);
            },
          ),

          // زر تغيير نوع الخريطة
          Positioned(
            right: 12,
            bottom: 160,
            child: FloatingActionButton.small(
              heroTag: 'layers',
              onPressed: () {
                setState(() {
                  final types = [
                    MapType.normal,
                    MapType.satellite,
                    MapType.terrain,
                    MapType.hybrid,
                  ];
                  _mapType =
                      types[(types.indexOf(_mapType) + 1) % types.length];
                });
              },
              child: const Icon(Icons.layers),
            ),
          ),

          // زر موقعي الحالي
          Positioned(
            right: 12,
            bottom: 100,
            child: FloatingActionButton.small(
              heroTag: 'myLoc',
              onPressed: _goingMyLoc ? null : _goMyLoc,
              child: _goingMyLoc
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          // البطاقة السفلية
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resolvedAddress ?? 'جاري تحديد العنوان...',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${_picked.latitude},${_picked.longitude}',
                        );
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('فتح بالخريطة'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        _MapPickResult(
                          position: _picked,
                          address: _resolvedAddress,
                        ),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('تأكيد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPickResult {
  final LatLng position;
  final String? address;
  _MapPickResult({required this.position, this.address});
}
