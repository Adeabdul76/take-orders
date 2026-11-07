/// A product the shop owner created inside the app.
/// Prices are stored in cents (sen) as whole numbers so money maths is exact.
class Product {
  final int? id;
  final String name;
  final int priceCents;
  final String category;
  final String? imagePath; // photo from gallery, copied into app storage
  final String? emoji; // used when there is no photo
  final bool available;

  const Product({
    this.id,
    required this.name,
    required this.priceCents,
    this.category = '',
    this.imagePath,
    this.emoji,
    this.available = true,
  });

  Product copyWith({
    int? id,
    String? name,
    int? priceCents,
    String? category,
    String? imagePath,
    String? emoji,
    bool? available,
    bool clearImage = false,
    bool clearEmoji = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      category: category ?? this.category,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      emoji: clearEmoji ? null : (emoji ?? this.emoji),
      available: available ?? this.available,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'price_cents': priceCents,
    'category': category,
    'image_path': imagePath,
    'emoji': emoji,
    'available': available ? 1 : 0,
  };

  factory Product.fromMap(Map<String, Object?> m) => Product(
    id: m['id'] as int?,
    name: m['name'] as String,
    priceCents: m['price_cents'] as int,
    category: (m['category'] as String?) ?? '',
    imagePath: m['image_path'] as String?,
    emoji: m['emoji'] as String?,
    available: (m['available'] as int? ?? 1) == 1,
  );
}
