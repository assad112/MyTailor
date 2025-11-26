// نموذج بيانات الخامة مع دعم الألوان المتوفرة
import 'package:cloud_firestore/cloud_firestore.dart';

class FabricColor {
  final String colorName;
  final String colorHex;
  final String? imageUrl; // صورة اللون

  FabricColor({required this.colorName, required this.colorHex, this.imageUrl});

  factory FabricColor.fromMap(Map<String, dynamic> map) {
    return FabricColor(
      colorName: map['colorName'] ?? '',
      colorHex: map['colorHex'] ?? '#000000',
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'colorName': colorName, 'colorHex': colorHex, 'imageUrl': imageUrl};
  }
}

class Fabric {
  final String id;
  final String name;
  final String description;
  final String type;
  final String color;
  final double quantity;
  final double pricePerMeter;
  final String supplier;
  final String origin;
  final String composition;
  final double width;
  final String careInstructions;
  final String quality;
  final String season;
  final bool isAvailable;
  final DateTime lastUpdated;
  final String createdBy; // منشئ الخامة
  final DateTime createdAt; // تاريخ الإنشاء
  final List<FabricColor> availableColors; // ✨ الألوان المتوفرة
  final String? imageUrl; // صورة الخامة

  Fabric({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.color,
    required this.quantity,
    required this.pricePerMeter,
    required this.supplier,
    required this.origin,
    required this.composition,
    required this.width,
    required this.careInstructions,
    required this.quality,
    required this.season,
    required this.isAvailable,
    required this.lastUpdated,
    required this.createdBy,
    required this.createdAt,
    this.availableColors = const [],
    this.imageUrl,
  });

  // Factory constructor لإنشاء Fabric من Map (للاستخدام مع Firebase)
  factory Fabric.fromMap(Map<String, dynamic> map, String id) {
    List<FabricColor> colors = [];
    if (map['availableColors'] != null && map['availableColors'] is List) {
      colors = (map['availableColors'] as List)
          .map((c) => FabricColor.fromMap(c as Map<String, dynamic>))
          .toList();
    }

    // دالة مساعدة لتحويل Timestamp أو int إلى DateTime
    DateTime _parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    return Fabric(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? '',
      color: map['color'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      pricePerMeter: (map['pricePerMeter'] ?? 0).toDouble(),
      supplier: map['supplier'] ?? '',
      origin: map['origin'] ?? '',
      composition: map['composition'] ?? '',
      width: (map['width'] ?? 0).toDouble(),
      careInstructions: map['careInstructions'] ?? '',
      quality: map['quality'] ?? '',
      season: map['season'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      lastUpdated: _parseDateTime(map['lastUpdated']),
      createdBy: map['createdBy'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      availableColors: colors,
      imageUrl: map['imageUrl'],
    );
  }

  // تحويل Fabric إلى Map (للاستخدام مع Firebase)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'color': color,
      'quantity': quantity,
      'pricePerMeter': pricePerMeter,
      'supplier': supplier,
      'origin': origin,
      'composition': composition,
      'width': width,
      'careInstructions': careInstructions,
      'quality': quality,
      'season': season,
      'isAvailable': isAvailable,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'availableColors': availableColors.map((c) => c.toMap()).toList(),
      'imageUrl': imageUrl,
    };
  }

  // copyWith method لإنشاء نسخة معدلة من Fabric
  Fabric copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    String? color,
    double? quantity,
    double? pricePerMeter,
    String? supplier,
    String? origin,
    String? composition,
    double? width,
    String? careInstructions,
    String? quality,
    String? season,
    bool? isAvailable,
    DateTime? lastUpdated,
    String? createdBy,
    DateTime? createdAt,
    List<FabricColor>? availableColors,
    String? imageUrl,
  }) {
    return Fabric(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
      pricePerMeter: pricePerMeter ?? this.pricePerMeter,
      supplier: supplier ?? this.supplier,
      origin: origin ?? this.origin,
      composition: composition ?? this.composition,
      width: width ?? this.width,
      careInstructions: careInstructions ?? this.careInstructions,
      quality: quality ?? this.quality,
      season: season ?? this.season,
      isAvailable: isAvailable ?? this.isAvailable,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      availableColors: availableColors ?? this.availableColors,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() {
    return 'Fabric(id: $id, name: $name, type: $type, color: $color, quantity: $quantity, pricePerMeter: $pricePerMeter)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Fabric && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
