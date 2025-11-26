import 'package:flutter/material.dart';

class EmbroideryType {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String difficulty;
  final int estimatedTime; // بالدقائق
  final bool isActive;

  EmbroideryType({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.difficulty,
    required this.estimatedTime,
    this.isActive = true,
  });
}

class ManageEmbroideryScreen extends StatefulWidget {
  const ManageEmbroideryScreen({super.key});

  @override
  State<ManageEmbroideryScreen> createState() => _ManageEmbroideryScreenState();
}

class _ManageEmbroideryScreenState extends State<ManageEmbroideryScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'الكل';
  String _selectedDifficulty = 'الكل';

  // بيانات تجريبية لأنواع التطريز
  List<EmbroideryType> _embroideryTypes = [
    EmbroideryType(
      id: '1',
      name: 'تطريز يدوي كلاسيكي',
      description: 'تطريز يدوي تقليدي بخيوط ذهبية وفضية',
      price: 150.0,
      category: 'تقليدي',
      difficulty: 'متوسط',
      estimatedTime: 180,
    ),
    EmbroideryType(
      id: '2',
      name: 'تطريز آلي حديث',
      description: 'تطريز بالماكينة بأشكال هندسية معاصرة',
      price: 80.0,
      category: 'حديث',
      difficulty: 'سهل',
      estimatedTime: 60,
    ),
    EmbroideryType(
      id: '3',
      name: 'تطريز بالخرز',
      description: 'تطريز مزين بالخرز والأحجار الكريمة',
      price: 250.0,
      category: 'فاخر',
      difficulty: 'صعب',
      estimatedTime: 300,
    ),
    EmbroideryType(
      id: '4',
      name: 'تطريز الأسماء',
      description: 'تطريز الأسماء والعبارات بخطوط عربية جميلة',
      price: 50.0,
      category: 'شخصي',
      difficulty: 'سهل',
      estimatedTime: 30,
    ),
    EmbroideryType(
      id: '5',
      name: 'تطريز الورود',
      description: 'تطريز أشكال الورود والزهور الطبيعية',
      price: 120.0,
      category: 'طبيعي',
      difficulty: 'متوسط',
      estimatedTime: 120,
    ),
  ];

  List<EmbroideryType> _filteredTypes = [];

  @override
  void initState() {
    super.initState();
    _filteredTypes = _embroideryTypes;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterEmbroideryTypes() {
    setState(() {
      _filteredTypes = _embroideryTypes.where((type) {
        final matchesSearch = type.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            type.description.toLowerCase().contains(_searchController.text.toLowerCase());
        final matchesCategory = _selectedCategory == 'الكل' || type.category == _selectedCategory;
        final matchesDifficulty = _selectedDifficulty == 'الكل' || type.difficulty == _selectedDifficulty;

        return matchesSearch && matchesCategory && matchesDifficulty;
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
          child: Column(
            children: [
              _buildSearchAndFilters(),
              _buildStatsSection(),
              Expanded(
                child: _buildEmbroideryList(),
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
        'إدارة التطريز',
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
      actions: [
        IconButton(
          icon: const Icon(Icons.sort, color: Colors.black54),
          onPressed: _showSortOptions,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // شريط البحث
          TextField(
            controller: _searchController,
            onChanged: (value) => _filterEmbroideryTypes(),
            decoration: InputDecoration(
              hintText: 'البحث عن نوع التطريز...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
          // فلاتر
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'الفئة',
                  _selectedCategory,
                  ['الكل', 'تقليدي', 'حديث', 'فاخر', 'شخصي', 'طبيعي'],
                      (value) {
                    setState(() {
                      _selectedCategory = value!;
                      _filterEmbroideryTypes();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'الصعوبة',
                  _selectedDifficulty,
                  ['الكل', 'سهل', 'متوسط', 'صعب'],
                      (value) {
                    setState(() {
                      _selectedDifficulty = value!;
                      _filterEmbroideryTypes();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
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
          _buildStatItem('المجموع', '${_embroideryTypes.length}', Icons.auto_fix_high, Colors.blue),
          _buildStatItem('النشط', '${_embroideryTypes.where((e) => e.isActive).length}', Icons.check_circle, Colors.green),
          _buildStatItem('المعروض', '${_filteredTypes.length}', Icons.visibility, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmbroideryList() {
    if (_filteredTypes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب تغيير معايير البحث',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredTypes.length,
      itemBuilder: (context, index) {
        final embroideryType = _filteredTypes[index];
        return _buildEmbroideryCard(embroideryType, index);
      },
    );
  }

  Widget _buildEmbroideryCard(EmbroideryType embroideryType, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEmbroideryDetails(embroideryType),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(embroideryType.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_fix_high,
                      color: _getCategoryColor(embroideryType.category),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          embroideryType.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          embroideryType.description,
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
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(value, embroideryType),
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
                  _buildInfoChip(embroideryType.category, _getCategoryColor(embroideryType.category)),
                  const SizedBox(width: 8),
                  _buildInfoChip(embroideryType.difficulty, _getDifficultyColor(embroideryType.difficulty)),
                  const Spacer(),
                  Text(
                    '${embroideryType.price.toStringAsFixed(0)} ريال',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${embroideryType.estimatedTime} دقيقة',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: embroideryType.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      embroideryType.isActive ? 'نشط' : 'غير نشط',
                      style: TextStyle(
                        fontSize: 10,
                        color: embroideryType.isActive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'تقليدي':
        return Colors.brown;
      case 'حديث':
        return Colors.blue;
      case 'فاخر':
        return Colors.purple;
      case 'شخصي':
        return Colors.orange;
      case 'طبيعي':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'سهل':
        return Colors.green;
      case 'متوسط':
        return Colors.orange;
      case 'صعب':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddEmbroideryDialog,
      backgroundColor: Colors.teal,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'إضافة تطريز',
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
              leading: const Icon(Icons.access_time),
              title: const Text('الوقت المقدر'),
              onTap: () {
                _sortBy('time');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sortBy(String criteria) {
    setState(() {
      switch (criteria) {
        case 'name':
          _filteredTypes.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'price':
          _filteredTypes.sort((a, b) => a.price.compareTo(b.price));
          break;
        case 'time':
          _filteredTypes.sort((a, b) => a.estimatedTime.compareTo(b.estimatedTime));
          break;
      }
    });
  }

  void _showEmbroideryDetails(EmbroideryType embroideryType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(embroideryType.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الوصف: ${embroideryType.description}'),
            const SizedBox(height: 8),
            Text('الفئة: ${embroideryType.category}'),
            const SizedBox(height: 8),
            Text('الصعوبة: ${embroideryType.difficulty}'),
            const SizedBox(height: 8),
            Text('السعر: ${embroideryType.price.toStringAsFixed(0)} ريال'),
            const SizedBox(height: 8),
            Text('الوقت المقدر: ${embroideryType.estimatedTime} دقيقة'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditEmbroideryDialog(embroideryType);
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  void _showAddEmbroideryDialog() {
    _showEmbroideryDialog();
  }

  void _showEditEmbroideryDialog(EmbroideryType embroideryType) {
    _showEmbroideryDialog(embroideryType: embroideryType);
  }

  void _showEmbroideryDialog({EmbroideryType? embroideryType}) {
    final isEditing = embroideryType != null;
    final nameController = TextEditingController(text: embroideryType?.name ?? '');
    final descriptionController = TextEditingController(text: embroideryType?.description ?? '');
    final priceController = TextEditingController(text: embroideryType?.price.toString() ?? '');
    final timeController = TextEditingController(text: embroideryType?.estimatedTime.toString() ?? '');
    String selectedCategory = embroideryType?.category ?? 'تقليدي';
    String selectedDifficulty = embroideryType?.difficulty ?? 'سهل';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'تعديل التطريز' : 'إضافة تطريز جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم التطريز',
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
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر (ريال)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: timeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الوقت (دقيقة)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'الفئة',
                    border: OutlineInputBorder(),
                  ),
                  items: ['تقليدي', 'حديث', 'فاخر', 'شخصي', 'طبيعي'].map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'الصعوبة',
                    border: OutlineInputBorder(),
                  ),
                  items: ['سهل', 'متوسط', 'صعب'].map((difficulty) {
                    return DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDifficulty = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty &&
                    priceController.text.isNotEmpty &&
                    timeController.text.isNotEmpty) {

                  final newEmbroideryType = EmbroideryType(
                    id: isEditing ? embroideryType.id : DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    description: descriptionController.text,
                    price: double.parse(priceController.text),
                    category: selectedCategory,
                    difficulty: selectedDifficulty,
                    estimatedTime: int.parse(timeController.text),
                  );

                  setState(() {
                    if (isEditing) {
                      final index = _embroideryTypes.indexWhere((e) => e.id == embroideryType.id);
                      if (index != -1) {
                        _embroideryTypes[index] = newEmbroideryType;
                      }
                    } else {
                      _embroideryTypes.add(newEmbroideryType);
                    }
                    _filterEmbroideryTypes();
                  });

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing ? 'تم تعديل التطريز بنجاح' : 'تم إضافة التطريز بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(isEditing ? 'تعديل' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action, EmbroideryType embroideryType) {
    switch (action) {
      case 'edit':
        _showEditEmbroideryDialog(embroideryType);
        break;
      case 'duplicate':
        _duplicateEmbroideryType(embroideryType);
        break;
      case 'delete':
        _showDeleteConfirmation(embroideryType);
        break;
    }
  }

  void _duplicateEmbroideryType(EmbroideryType embroideryType) {
    final duplicatedType = EmbroideryType(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${embroideryType.name} (نسخة)',
      description: embroideryType.description,
      price: embroideryType.price,
      category: embroideryType.category,
      difficulty: embroideryType.difficulty,
      estimatedTime: embroideryType.estimatedTime,
    );

    setState(() {
      _embroideryTypes.add(duplicatedType);
      _filterEmbroideryTypes();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ التطريز بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showDeleteConfirmation(EmbroideryType embroideryType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "${embroideryType.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _embroideryTypes.removeWhere((e) => e.id == embroideryType.id);
                _filterEmbroideryTypes();
              });
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف التطريز بنجاح'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

