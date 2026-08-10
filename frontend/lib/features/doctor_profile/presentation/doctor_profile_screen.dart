import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_pill.dart';

/// Doctor Profile & Roster View Screen
class DoctorProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<String>? onPatientClick;

  const DoctorProfileScreen({
    super.key,
    this.onBack,
    this.onPatientClick,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedTimeSlot = '10:00 AM';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation Back Bar
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Dashboard'),
              ),
            ),

          // Doctor Header Profile Card
          _buildDoctorHeaderCard(),

          const SizedBox(height: 24),

          // Tabs Navigation
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.rose,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.rose,
            labelStyle: AppTypography.labelMedium(),
            unselectedLabelStyle: AppTypography.labelMedium(),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Schedule & Slots'),
              Tab(text: 'My Patients'),
              Tab(text: 'Reviews & Ratings'),
            ],
          ),

          const SizedBox(height: 20),

          // Tab Content Area
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildScheduleTab(),
                _buildPatientsTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.rose, width: 2),
            ),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.bgRose,
              child: Text(
                'HN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.rose,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. Hana Nasser', style: AppTypography.displayTitle()),
                        Text('Senior Aesthetic Dermatologist · MB BCh, MD', style: AppTypography.bodyMedium(color: AppColors.rose)),
                      ],
                    ),
                    const StatusPill(status: 'Available'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSpecialtyTag('Laser Resurfacing'),
                    _buildSpecialtyTag('Botox & Fillers'),
                    _buildSpecialtyTag('Chemical Peels'),
                    _buildSpecialtyTag('Anti-Aging Therapy'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.gold, size: 18),
                    const SizedBox(width: 4),
                    Text('4.9', style: AppTypography.labelLarge()),
                    Text(' (142 reviews)', style: AppTypography.bodySmall(color: AppColors.textMuted)),
                    const SizedBox(width: 24),
                    const Icon(Icons.history_toggle_off, color: AppColors.lav, size: 18),
                    const SizedBox(width: 4),
                    Text('12+ Yrs Exp', style: AppTypography.labelLarge()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtyTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: AppTypography.labelSmall(color: AppColors.roseDark)),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      children: [
        Row(
          children: const [
            Expanded(child: _InfoTile(title: 'Patients YTD', value: '386', icon: Icons.group)),
            SizedBox(width: 16),
            Expanded(child: _InfoTile(title: 'Avg Rating', value: '4.9 ⭐', icon: Icons.star_outline)),
            SizedBox(width: 16),
            Expanded(child: _InfoTile(title: 'Consultations', value: '1,420', icon: Icons.video_call)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Biography & Qualifications', style: AppTypography.labelLarge()),
        const SizedBox(height: 8),
        Text(
          'Dr. Hana Nasser is a board-certified dermatologist specializing in laser skin rejuvenation, facial aesthetics, and non-invasive anti-aging therapies. With over 12 years of clinical excellence in London and Ramallah.',
          style: AppTypography.bodyMedium(color: AppColors.textSub),
        ),
      ],
    );
  }

  Widget _buildScheduleTab() {
    final slots = ['09:15 AM', '10:00 AM', '10:45 AM', '01:30 PM', '02:15 PM', '03:00 PM'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Time Slots — Thursday 7 Aug', style: AppTypography.labelLarge()),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: slots.map((slot) {
              final isSelected = slot == _selectedTimeSlot;
              return ChoiceChip(
                label: Text(slot),
                selected: isSelected,
                selectedColor: AppColors.rose,
                backgroundColor: AppColors.bgAlt,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _selectedTimeSlot = slot;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Slot $_selectedTimeSlot reserved with Dr. Hana Nasser')),
              );
            },
            child: Text('Book Selected Slot ($_selectedTimeSlot)'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsTab() {
    return ListView(
      children: [
        ListTile(
          leading: const CircleAvatar(backgroundColor: AppColors.bgRose, child: Text('NK', style: TextStyle(color: AppColors.rose))),
          title: Text('Nour Al-Khalil', style: AppTypography.labelLarge()),
          subtitle: Text('Laser Resurfacing · Session 3/5', style: AppTypography.bodySmall()),
          trailing: const StatusPill(status: 'In Room'),
          onTap: () => widget.onPatientClick?.call('Nour Al-Khalil'),
        ),
        const Divider(),
        ListTile(
          leading: const CircleAvatar(backgroundColor: AppColors.bgLavender, child: Text('LM', style: TextStyle(color: AppColors.lav))),
          title: Text('Layla Mansour', style: AppTypography.labelLarge()),
          subtitle: Text('HydroGlow Facial', style: AppTypography.bodySmall()),
          trailing: const StatusPill(status: 'Waiting'),
          onTap: () => widget.onPatientClick?.call('Layla Mansour'),
        ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    return ListView(
      children: const [
        _ReviewItem(
          name: 'Sarah M.',
          rating: 5,
          date: '2 Aug 2026',
          comment: 'Dr. Hana is incredible! My skin feels radiant after the laser session. Highly recommend!',
        ),
        _ReviewItem(
          name: 'Yasmine K.',
          rating: 5,
          date: '28 Jul 2026',
          comment: 'Very professional clinic and gentle treatment. The results are visible immediately.',
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoTile({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.rose, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.displayStat()),
          Text(title, style: AppTypography.bodySmall()),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final String name;
  final int rating;
  final String date;
  final String comment;

  const _ReviewItem({
    required this.name,
    required this.rating,
    required this.date,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: AppTypography.labelLarge()),
              Row(
                children: List.generate(
                  rating,
                  (index) => const Icon(Icons.star, color: AppColors.gold, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(date, style: AppTypography.bodySmall(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(comment, style: AppTypography.bodyMedium(color: AppColors.textSub)),
        ],
      ),
    );
  }
}
