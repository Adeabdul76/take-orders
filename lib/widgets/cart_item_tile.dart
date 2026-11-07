import 'package:flutter/material.dart';

import '../providers/cart_provider.dart';
import '../utils/money.dart';
import 'product_card.dart';

class CartItemTile extends StatelessWidget {
  final CartLine line;
  final String currency;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final VoidCallback onRemove;
  final VoidCallback onNote;

  const CartItemTile({
    super.key,
    required this.line,
    required this.currency,
    required this.onPlus,
    required this.onMinus,
    required this.onRemove,
    required this.onNote,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductImage(product: line.product, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${formatMoney(line.product.priceCents, currency)} each',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(line.totalCents, currency),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            if (line.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 60),
                child: Text(
                  'Note: ${line.note}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _RoundButton(icon: Icons.remove, onTap: onMinus),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${line.qty}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _RoundButton(icon: Icons.add, onTap: onPlus),
                const Spacer(),
                IconButton(
                  tooltip: 'Add note',
                  iconSize: 28,
                  onPressed: onNote,
                  icon: const Icon(Icons.edit_note),
                ),
                IconButton(
                  tooltip: 'Remove',
                  iconSize: 28,
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
      ),
    );
  }
}
