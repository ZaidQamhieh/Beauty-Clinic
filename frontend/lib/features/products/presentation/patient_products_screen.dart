import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../../appointments/presentation/booking_format.dart';
import '../../patient_profile/data/session_record.dart';
import '../../patient_profile/data/session_record_api.dart';
import '../data/product.dart';
import '../data/product_api.dart';
import 'widgets/patient_product_dialog.dart';
import 'widgets/product_glyph.dart';

enum _Shelf { prescribed, stopped, everything }

/// The patient's own products, read-only.
class PatientProductsScreen extends StatefulWidget {
  const PatientProductsScreen({
    super.key,
    required this.productApi,
    required this.apiClient,
    required this.patientId,
  });

  final ProductApi productApi;
  final ApiClient apiClient;
  final String? patientId;

  @override
  State<PatientProductsScreen> createState() => _PatientProductsScreenState();
}

class _PatientProductsScreenState extends State<PatientProductsScreen> {
  List<Product> _catalogue = const [];
  List<Product> _prescribed = const [];
  List<PatientProductRecord> _routine = const [];
  List<SessionRecord> _records = const [];

  bool _loading = true;
  String? _error;
  _Shelf _shelf = _Shelf.everything;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patientId = widget.patientId;
    if (patientId == null) {
      setState(() {
        _loading = false;
        _error = 'We could not tell which account this is.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.productApi.list(),
        widget.productApi.prescribedForPatient(patientId),
        widget.productApi.listForPatient(patientId),
        SessionRecordApi(widget.apiClient).listForPatient(patientId),
      ]);
      if (!mounted) return;
      setState(() {
        _catalogue = results[0] as List<Product>;
        _prescribed = results[1] as List<Product>;
        _routine = results[2] as List<PatientProductRecord>;
        _records = results[3] as List<SessionRecord>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your products.';
      });
    }
  }

  // Newest record naming this product wins.
  SessionRecord? _recordFor(String productId) {
    SessionRecord? found;
    for (final record in _records) {
      if (!record.prescribedProductIds.contains(productId)) continue;
      if (found == null || record.createdAt.isAfter(found.createdAt)) {
        found = record;
      }
    }
    return found;
  }

  SessionRecord? get _latestNote {
    SessionRecord? found;
    for (final record in _records) {
      if ((record.note ?? '').trim().isEmpty) continue;
      if (found == null || record.createdAt.isAfter(found.createdAt)) {
        found = record;
      }
    }
    return found;
  }

  Map<String, String> get _stoppedOn {
    return {
      for (final item in _routine)
        if (item.discontinuedOn != null) item.productId: item.discontinuedOn!,
    };
  }

  List<Product> get _stopped {
    final stopped = _stoppedOn.keys.toSet();
    return _catalogue.where((product) => stopped.contains(product.id)).toList();
  }

  List<Product> get _visible => switch (_shelf) {
    _Shelf.prescribed => _prescribed,
    _Shelf.stopped => _stopped,
    _Shelf.everything => _catalogue,
  };

  void _open(Product product) {
    final stopped = _stoppedOn[product.id];
    showDialog<void>(
      context: context,
      builder: (_) => PatientProductDialog(
        product: product,
        record: _recordFor(product.id),
        prescribed: _prescribed.any((item) => item.id == product.id),
        stoppedOn: stopped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: SkeletonGrid());
    }

    final error = _error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, style: AppTypography.bodyMedium()),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My products', style: AppTypography.displayTitle()),
          if (_latestNote != null) ...[
            const SizedBox(height: 14),
            _noteStrip(_latestNote!),
          ],
          const SizedBox(height: 14),
          _shelfChips(),
          const SizedBox(height: 16),
          Expanded(child: _grid()),
        ],
      ),
    );
  }

  Widget _noteStrip(SessionRecord record) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 16,
            color: AppColors.roseDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              record.note!.trim(),
              style: AppTypography.bodyMedium(color: AppColors.textSub),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            [
              record.authorName,
              BookingFormat.dayWithYear(record.createdAt.toLocal()),
            ].whereType<String>().join(' · '),
            style: AppTypography.bodySmall(color: AppColors.roseDark),
          ),
        ],
      ),
    );
  }

  Widget _shelfChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('All products', _catalogue.length, _Shelf.everything),
        _chip('Prescribed', _prescribed.length, _Shelf.prescribed),
        _chip('Stopped', _stopped.length, _Shelf.stopped),
      ],
    );
  }

  Widget _chip(String label, int count, _Shelf shelf) {
    final selected = _shelf == shelf;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _shelf = shelf),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.rose : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall(
                color: selected ? AppColors.white : AppColors.textSub,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: AppTypography.numeric(
                color: selected ? AppColors.white : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid() {
    final products = _visible;
    if (products.isEmpty) {
      return Center(
        child: Text(_emptyText(), style: AppTypography.bodySmall()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          >= 1100 => 4,
          >= 820 => 3,
          >= 560 => 2,
          _ => 1,
        };
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 262,
          ),
          itemCount: products.length,
          itemBuilder: (_, index) => _card(products[index]),
        );
      },
    );
  }

  String _emptyText() => switch (_shelf) {
    _Shelf.prescribed => 'Your doctor has not prescribed any products yet.',
    _Shelf.stopped => 'Nothing you have stopped using.',
    _Shelf.everything => 'The clinic has not listed any products yet.',
  };

  Widget _card(Product product) {
    final stopped = _stoppedOn[product.id];
    final prescribed = _prescribed.any((item) => item.id == product.id);
    final record = _recordFor(product.id);

    final line = stopped != null
        ? 'Stopped $stopped'
        : record != null
        ? 'Prescribed ${BookingFormat.dayWithYear(record.createdAt.toLocal())}'
        : product.typeLabel;

    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(product),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ProductGlyph(product: product, height: 150),
                  if (prescribed || stopped != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          stopped != null ? 'Stopped' : 'Prescribed',
                          style: AppTypography.labelSmall(
                            color: stopped != null
                                ? AppColors.textMuted
                                : AppColors.roseDark,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge(),
                    ),
                    const SizedBox(height: 2),
                    Text(product.brandLabel, style: AppTypography.bodySmall()),
                    const SizedBox(height: 9),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(color: AppColors.textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
