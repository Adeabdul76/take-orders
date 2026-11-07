import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/money.dart';

/// Shows a product's photo, or its emoji, or its first letter.
class ProductImage extends StatelessWidget {
  final Product product;
  final double size;
  const ProductImage({super.key, required this.product, this.size = 56});

  // Decoding base64 on every rebuild is wasteful, so keep recent photos.
  static final Map<String, Uint8List> _cache = {};

  static Uint8List? _bytes(String data) {
    final hit = _cache[data];
    if (hit != null) return hit;
    try {
      final b = base64Decode(data);
      if (_cache.length > 300) _cache.clear();
      return _cache[data] = b;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = product.imageData;
    final bytes = data == null ? null : _bytes(data);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    final path = product.imagePath;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    final emoji = product.emoji;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        (emoji != null && emoji.isNotEmpty)
            ? emoji
            : (product.name.isEmpty ? '?' : product.name[0].toUpperCase()),
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}

/// A big tappable product tile on the home screen.
class ProductCard extends StatelessWidget {
  final Product product;
  final String currency;
  final int qtyInCart;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.currency,
    required this.qtyInCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: qtyInCart > 0
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => ProductImage(
                        product: product,
                        size: c.maxHeight.clamp(40, 120).toDouble(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(product.priceCents, currency),
                    style: TextStyle(
                      fontSize: 16,
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (qtyInCart > 0)
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary,
                  child: Text(
                    '$qtyInCart',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
