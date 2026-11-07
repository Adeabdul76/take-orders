/// A product the shop owner created inside the app.
/// Prices are stored in cents (sen) as whole numbers so money maths is exact.
class Product {
  final String? id;
  final String name;
  final int priceCents;
  final String category;

  /// Small JPEG photo as base64 text, so it can be shared with other phones.
  final String? imageData;

  /// Old versions saved photos as a file on this phone only. Still shown,
  /// and converted to [imageData] when the cafe is shared.
  final String? imagePath;
  final String? emoji; // used when there is no photo
  final bool available;

  const Product({
    this.id,
    required this.name,
    required this.priceCents,
    this.category = '',
    this.imageData,
    this.imagePath,
    this.emoji,
    this.available = true,
  });

  Product copyWith({
    String? id,
    String? name,
    int? priceCents,
    String? category,
    String? imageData,
    String? emoji,
    bool? available,
    bool clearImage = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      category: category ?? this.category,
      imageData: clearImage ? null : (imageData ?? this.imageData),
      imagePath: clearImage ? null : imagePath,
      emoji: emoji ?? this.emoji,
      available: available ?? this.available,
    );
  }

  /// Fields shared online (no phone-only file path).
  Map<String, Object?> toCloud() => {
    'name': name,
    'priceCents': priceCents,
    'category': category,
    'imageData': imageData,
    'emoji': emoji,
    'available': available,
  };

  factory Product.fromCloud(String id, Map<String, dynamic> m) => Product(
    id: id,
    name: (m['name'] as String?) ?? '',
    priceCents: (m['priceCents'] as num?)?.toInt() ?? 0,
    category: (m['category'] as String?) ?? '',
    imageData: m['imageData'] as String?,
    emoji: m['emoji'] as String?,
    available: (m['available'] as bool?) ?? true,
  );
}
