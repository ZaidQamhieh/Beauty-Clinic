import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/yasmine_logo.dart';

/// Public Landing Page & Services Showcase
class LandingScreen extends StatelessWidget {
  final VoidCallback onBookClick;
  final ValueChanged<String> onViewDoctor;

  const LandingScreen({
    super.key,
    required this.onBookClick,
    required this.onViewDoctor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section
          _buildHeroSection(context),

          const SizedBox(height: 48),

          // Services & Treatments Showcase
          _buildServicesSection(context),

          const SizedBox(height: 48),

          // Doctors Showcase
          _buildDoctorsSection(context),

          const SizedBox(height: 48),

          // Testimonials Showcase
          _buildTestimonialsSection(context),

          const SizedBox(height: 48),

          // Footer
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: const BoxDecoration(
        color: AppColors.bgRose,
        border: Border(bottom: BorderSide(color: AppColors.borderRose)),
      ),
      child: Column(
        children: [
          const YasmineLogo(size: 64),
          const SizedBox(height: 20),
          Text(
            'YASMINE DERMA CLINIC',
            style: AppTypography.labelSmall(
              color: AppColors.rose,
            ).copyWith(letterSpacing: 2.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Reinventing Radiance & Advanced Aesthetic Care',
            style: AppTypography.displayHero(color: AppColors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Text(
              'Personalized dermatological treatments, laser skin resurfacing, and luxury clinical facial therapies guided by leading specialists.',
              style: AppTypography.bodyLarge(color: AppColors.textSub),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onBookClick,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            label: Text(
              'Book Your Consultation',
              style: AppTypography.labelLarge(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    final services = [
      {
        'title': 'HydraFacial Glow',
        'desc':
            'Deep cleansing, gentle exfoliation, and intense hydration serum infusion.',
        'price': '£120',
        'time': '45 min',
        'icon': Icons.spa_outlined,
        'color': AppColors.rose,
      },
      {
        'title': 'Laser Skin Resurfacing',
        'desc':
            'Target pigmentation, fine lines, and acne scars with precision laser.',
        'price': '£250',
        'time': '60 min',
        'icon': Icons.auto_awesome,
        'color': AppColors.lav,
      },
      {
        'title': 'Botox & Dermal Fillers',
        'desc':
            'Natural facial contouring and wrinkle smoothing consultations.',
        'price': '£180',
        'time': '30 min',
        'icon': Icons.face_retouching_natural,
        'color': AppColors.gold,
      },
      {
        'title': 'Medical Chemical Peel',
        'desc':
            'Cellular renewal and texture refining for dull or congested skin.',
        'price': '£140',
        'time': '40 min',
        'icon': Icons.clean_hands_outlined,
        'color': AppColors.sage,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Clinical Treatments & Services',
            style: AppTypography.displayTitle(),
          ),
          const SizedBox(height: 8),
          Text(
            'Curated by board-certified aesthetic dermatologists',
            style: AppTypography.bodySmall(),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final int count = constraints.maxWidth > 800
                  ? 4
                  : (constraints.maxWidth > 500 ? 2 : 1);
              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth > 800 ? 1.0 : 1.3,
                children: services.map((s) => _buildServiceCard(s)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> s) {
    final Color color = s['color'] as Color;
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(s['icon'] as IconData, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(s['title'] as String, style: AppTypography.labelLarge()),
          const SizedBox(height: 6),
          Text(
            s['desc'] as String,
            style: AppTypography.bodySmall(color: AppColors.textSub),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s['price'] as String,
                style: AppTypography.displayTitle().copyWith(fontSize: 18),
              ),
              Text(
                s['time'] as String,
                style: AppTypography.labelSmall(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsSection(BuildContext context) {
    final doctors = [
      {
        'name': 'Dr. Hana Nasser',
        'role': 'Senior Dermatologist',
        'exp': '12 Yrs Exp',
      },
      {
        'name': 'Dr. Reem Khalil',
        'role': 'Aesthetic Specialist',
        'exp': '9 Yrs Exp',
      },
      {
        'name': 'Dr. Sana Al-Farsi',
        'role': 'Laser Specialist',
        'exp': '11 Yrs Exp',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text('Meet Our Specialists', style: AppTypography.displayTitle()),
          const SizedBox(height: 8),
          Text(
            'Expert care tailored to your unique skin profile',
            style: AppTypography.bodySmall(),
          ),
          const SizedBox(height: 24),
          Row(
            children: doctors.map((d) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.bgRose,
                        child: Text(
                          d['name']!
                              .split(' ')
                              .take(2)
                              .map((w) => w[0])
                              .join(''),
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.rose,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(d['name']!, style: AppTypography.labelLarge()),
                      Text(
                        d['role']!,
                        style: AppTypography.bodySmall(color: AppColors.rose),
                      ),
                      Text(
                        d['exp']!,
                        style: AppTypography.labelSmall(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => onViewDoctor(d['name']!),
                        child: const Text('View Profile'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      color: AppColors.bgLavender,
      child: Column(
        children: [
          Text('Patient Experiences', style: AppTypography.displayTitle()),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              '"The skin transformation I experienced at Yasmine Derma Clinic was beyond my expectations. Dr. Hana and the team truly care about long-term skin health."',
              style: AppTypography.displaySubtitle().copyWith(
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '— Nour Al-Khalil (Patient)',
            style: AppTypography.labelSmall(color: AppColors.lavDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      color: AppColors.bgSidebar,
      child: Column(
        children: [
          const YasmineLogo(size: 40, isDarkBackground: true),
          const SizedBox(height: 12),
          Text(
            'YASMINE BEAUTY & DERMA CLINIC',
            style: AppTypography.labelMedium(color: AppColors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Ramallah · West Bank | Hours: Mon – Sat 09:00 – 19:00',
            style: AppTypography.bodySmall(color: AppColors.textSide),
          ),
          const SizedBox(height: 16),
          Text(
            '© 2026 Yasmine Derma Clinic. All rights reserved.',
            style: AppTypography.labelSmall(color: AppColors.textSideMuted),
          ),
        ],
      ),
    );
  }
}
