import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../appointments/presentation/booking_format.dart';
import '../../../patient_profile/data/session_record.dart';
import '../../data/product.dart';
import 'product_glyph.dart';

/// Product popup for the patient.
class PatientProductDialog extends StatelessWidget {
  const PatientProductDialog({
    super.key,
    required this.product,
    this.record,
    this.prescribed = false,
    this.stoppedOn,
  });

  final Product product;

  /// The record that prescribed it.
  final SessionRecord? record;
  final bool prescribed;
  final String? stoppedOn;

  @override
  Widget build(BuildContext context) {
    final note = record?.note?.trim();

    return Dialog(
      backgroundColor: AppColors.bgCard,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hero(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      textAlign: TextAlign.center,
                      style: AppTypography.displaySubtitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.brandLabel} · ${product.typeLabel}',
                      style: AppTypography.bodySmall(),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _noteBlock(note),
                    ],
                    if (product.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Ask the pharmacist for',
                        style: AppTypography.labelSmall(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final ingredient in product.ingredients)
                            _chip(Product.label(ingredient)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _pharmacyStrip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: ProductGlyph(product: product, height: 200, glyphSize: 58),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: _pill(
            prescribed ? 'Prescribed' : 'Not prescribed to you',
            prescribed ? AppColors.roseDark : AppColors.textMuted,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: AppColors.bgCard,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: Icon(Icons.close, size: 16, color: AppColors.textSub),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _noteBlock(String note) {
    final author = record?.authorName;
    final when = record == null
        ? null
        : BookingFormat.dayWithYear(record!.createdAt.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (author != null || when != null) ...[
            Text(
              [author, when].whereType<String>().join(' · '),
              style: AppTypography.labelSmall(color: AppColors.roseDark),
            ),
            const SizedBox(height: 6),
          ],
          Text(note, style: AppTypography.bodyMedium(color: AppColors.textSub)),
        ],
      ),
    );
  }

  Widget _pharmacyStrip() {
    final stopped = stoppedOn;
    final line = stopped != null
        ? 'You stopped this on $stopped'
        : 'Buy at any pharmacy — the clinic does not sell products';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.hairline)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_pharmacy_outlined,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(line, style: AppTypography.bodySmall())),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(label, style: AppTypography.labelSmall(color: color)),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall(color: AppColors.textSub),
      ),
    );
  }
}
