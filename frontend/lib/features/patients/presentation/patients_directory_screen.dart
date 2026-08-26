import '../../../core/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../forms/data/clinical_intake_api.dart';

/// Patient directory with search and intake status.
class PatientsDirectoryScreen extends StatefulWidget {
  final ClinicalIntakeApi clinicalApi;
  final ValueChanged<String> onSelectPatient;
  final String? title;
  final String? subtitle;

  const PatientsDirectoryScreen({
    super.key,
    required this.clinicalApi,
    required this.onSelectPatient,
    this.title,
    this.subtitle,
  });

  @override
  State<PatientsDirectoryScreen> createState() =>
      _PatientsDirectoryScreenState();
}

class _PatientsDirectoryScreenState extends State<PatientsDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'ALL'; // ALL, COMPLETED, PENDING

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients([String query = '']) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await widget.clinicalApi.searchClinical(query);
      if (!mounted) return;
      setState(() {
        _patients = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load patients: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    return _patients.where((p) {
      final skinType = p['skinType']?.toString().trim();
      final hasCompleted = skinType != null && skinType.isNotEmpty;

      if (_selectedFilter == 'COMPLETED' && !hasCompleted) return false;
      if (_selectedFilter == 'PENDING' && hasCompleted) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPatients;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          _buildHeaderBanner(),
          const SizedBox(height: 24),

          // Search & Filter Toolbar
          _buildSearchAndFilters(),
          const SizedBox(height: 20),

          // Content Area
          if (_isLoading)
            const SizedBox(height: 420, child: SkeletonList())
          else if (_error != null)
            _buildErrorState()
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            _buildPatientsGrid(filtered),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: AppColors.rose,
              size: 28,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? 'Patients Directory',
                  style: AppTypography.displayTitle(),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle ??
                      'Browse registered clinic patients, inspect medical histories, and review clinical intake records.',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.folder_shared_outlined,
                  size: 16,
                  color: AppColors.rose,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_patients.length} Patients',
                  style: AppTypography.labelLarge(color: AppColors.roseDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Search Input
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                hintText: 'Search by patient name, email, or phone number...',
                onSubmitted: (query) => _loadPatients(query.trim()),
                onChanged: (val) {
                  if (val.isEmpty) _loadPatients('');
                },
                onClear: () {
                  _searchController.clear();
                  _loadPatients('');
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _loadPatients(_searchController.text.trim()),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Filter Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip('ALL', 'All Patients (${_patients.length})'),
            _buildFilterChip(
              'COMPLETED',
              'Intake Complete (${_patients.where((p) => (p['skinType'] ?? '').toString().isNotEmpty).length})',
            ),
            _buildFilterChip(
              'PENDING',
              'Intake Pending (${_patients.where((p) => (p['skinType'] ?? '').toString().isEmpty).length})',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      label: Text(label),
      labelStyle: AppTypography.labelSmall(
        color: isSelected ? Colors.white : AppColors.textSub,
      ),
      selectedColor: AppColors.rose,
      backgroundColor: AppColors.bgAlt,
      side: BorderSide(color: isSelected ? AppColors.rose : AppColors.border),
      showCheckmark: false,
    );
  }

  Widget _buildPatientsGrid(List<Map<String, dynamic>> patients) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 650
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 250,
          ),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            return _buildPatientCard(patient);
          },
        );
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final patientId = patient['id']?.toString() ?? '';
    final firstName = patient['firstName']?.toString() ?? '';
    final lastName = patient['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim().isEmpty
        ? 'Unnamed Patient'
        : '$firstName $lastName';
    final email = patient['email']?.toString() ?? 'No email';
    final phone = patient['phone']?.toString() ?? 'No phone';
    final skinType = patient['skinType']?.toString();
    final hasCompletedIntake = skinType != null && skinType.isNotEmpty;

    final initials =
        (firstName.isNotEmpty ? firstName[0] : '') +
        (lastName.isNotEmpty ? lastName[0] : '');

    return Material(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onSelectPatient(patientId),
        hoverColor: AppColors.bgRose.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar, name, status pill.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.bgRose,
                    child: Text(
                      initials.toUpperCase(),
                      style: AppTypography.labelLarge(
                        color: AppColors.roseDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: AppTypography.displaySubtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: AppTypography.bodySmall(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Phone & Contact
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    phone,
                    style: AppTypography.bodySmall(color: AppColors.textSub),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Form Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: hasCompletedIntake
                          ? AppColors.bgSage
                          : AppColors.bgRose,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasCompletedIntake
                              ? Icons.check_circle_outline
                              : Icons.pending_actions,
                          size: 12,
                          color: hasCompletedIntake
                              ? AppColors.sageDark
                              : AppColors.rose,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasCompletedIntake
                              ? 'Intake Complete'
                              : 'Intake Pending',
                          style: AppTypography.labelSmall(
                            color: hasCompletedIntake
                                ? AppColors.sageDark
                                : AppColors.roseDark,
                          ).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Skin Type Badge
                  if (skinType != null && skinType.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgLavender,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Skin: $skinType',
                        style: AppTypography.labelSmall(
                          color: AppColors.lavDark,
                        ).copyWith(fontSize: 10),
                      ),
                    ),
                ],
              ),

              const Spacer(),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Action button row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'ID: ${patientId.length > 8 ? patientId.substring(0, 8) : patientId}...',
                      style: AppTypography.labelSmall(
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
                        style: AppTypography.labelSmall(
                          color: AppColors.rose,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.rose,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_search_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text('No Patients Found', style: AppTypography.displaySubtitle()),
          const SizedBox(height: 6),
          Text(
            _searchController.text.isNotEmpty
                ? 'No registered patients match "${_searchController.text}".'
                : 'There are currently no registered patients in the clinic system.',
            style: AppTypography.bodySmall(color: AppColors.textSub),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                _loadPatients('');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rose,
                side: const BorderSide(color: AppColors.borderRose),
              ),
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.rose, size: 36),
          const SizedBox(height: 12),
          Text(
            _error ?? 'An unexpected error occurred.',
            style: AppTypography.bodySmall(color: AppColors.roseDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _loadPatients(_searchController.text.trim()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
