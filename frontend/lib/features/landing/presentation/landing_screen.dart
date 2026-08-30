import 'package:flutter/material.dart';
import 'dart:async';
import 'package:beauty_clinic_app/auth/role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/yasmine_logo.dart';
import '../../appointments/data/doctor_api.dart';
import '../../appointments/data/doctor_summary.dart';
import '../../appointments/data/treatment.dart';
import '../../appointments/data/treatment_api.dart';

/// Public Landing Page & Services Showcase
class LandingScreen extends StatefulWidget {
  final VoidCallback onBookClick;
  final ValueChanged<String> onViewDoctor;
  final TreatmentApi? treatmentApi;
  final DoctorApi? doctorApi;
  final Future<List<DoctorSummary>>? doctorsFuture;

  const LandingScreen({
    super.key,
    required this.onBookClick,
    required this.onViewDoctor,
    this.treatmentApi,
    this.doctorApi,
    this.doctorsFuture,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final Future<List<Treatment>> _treatments;
  late final Future<List<DoctorSummary>> _doctors;

  @override
  void initState() {
    super.initState();
    _treatments = widget.treatmentApi?.list() ?? Future.value(const []);
    _doctors =
        widget.doctorsFuture ??
        (widget.doctorApi?.list() ?? Future.value(const []));
  }

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
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: widget.onBookClick,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Clinical Treatments & Services',
            style: AppTypography.displayTitle(),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Treatment>>(
            future: _treatments,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
                return const SizedBox(
                  height: 140,
                  child: Center(child: Text('No treatments available.')),
                );
              }
              return _ServicesCarousel(treatments: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text('Meet Our Specialists', style: AppTypography.displayTitle()),
          const SizedBox(height: 24),
          FutureBuilder<List<DoctorSummary>>(
            future: _doctors,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
                return const SizedBox(
                  height: 140,
                  child: Center(child: Text('No specialists available.')),
                );
              }

              final doctors = snapshot.data!;
              return Row(
                children: doctors.map((doctor) {
                  final years = doctor.yearsOfExperience;
                  final experienceText = years == null
                      ? 'Experience available'
                      : '$years Yrs Exp';

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
                          ProfileAvatar(
                            color: AppColors.rose,
                            role: Role.doctor,
                            gender: null,
                            imageUrl: doctor.imageUrl,
                            radius: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            doctor.fullName,
                            style: AppTypography.labelLarge(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctor.specializations.isEmpty
                                ? 'Specialist'
                                : doctor.specializations.join(' • '),
                            style: AppTypography.bodySmall(
                              color: AppColors.rose,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            experienceText,
                            style: AppTypography.labelSmall(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    final reviews = [
      (
        name: 'Maya Khalil',
        rating: 5,
        review:
            'My skin felt brighter after the first visit, and the team explained every step with real care.',
      ),
      (
        name: 'Omar Nasser',
        rating: 5,
        review:
            'The consultation was calm and thorough. I finally have a simple routine that works for me.',
      ),
      (
        name: 'Rania Darwish',
        rating: 4,
        review:
            'A beautifully organised clinic with thoughtful advice and a very comfortable treatment experience.',
      ),
      (
        name: 'Yara Saad',
        rating: 5,
        review:
            'I appreciated the honest guidance and the gentle approach. My follow-up plan was easy to understand.',
      ),
      (
        name: 'Tarek Nabil',
        rating: 4,
        review:
            'From booking to aftercare, everything felt personal, polished, and well looked after.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      color: AppColors.bgLavender,
      child: Column(
        children: [
          Text('Patient Experiences', style: AppTypography.displayTitle()),
          const SizedBox(height: 20),
          _ReviewsCarousel(reviews: reviews),
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

class _ReviewsCarousel extends StatefulWidget {
  const _ReviewsCarousel({required this.reviews});

  final List<({String name, int rating, String review})> reviews;

  @override
  State<_ReviewsCarousel> createState() => _ReviewsCarouselState();
}

class _ReviewsCarouselState extends State<_ReviewsCarousel> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  Duration _displayTime(({String name, int rating, String review}) review) {
    final milliseconds = 5500 + (review.review.length * 32);
    return Duration(milliseconds: milliseconds.clamp(5500, 11000));
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.reviews.length < 2) return;
    _timer = Timer(_displayTime(widget.reviews[_index]), _showNext);
  }

  void _showNext() {
    if (!mounted || widget.reviews.isEmpty) return;
    setState(() => _index = (_index + 1) % widget.reviews.length);
    _restartTimer();
  }

  void _showPrevious() {
    if (widget.reviews.isEmpty) return;
    setState(() {
      _index = (_index - 1 + widget.reviews.length) % widget.reviews.length;
    });
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reviews.isEmpty) return const SizedBox.shrink();
    final review = widget.reviews[_index];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900
            ? 760.0
            : constraints.maxWidth - 92;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _arrowButton(
              tooltip: 'Previous review',
              icon: Icons.chevron_left_rounded,
              onPressed: _showPrevious,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: cardWidth,
                  height: 300,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 550),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _reviewCard(review),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            _arrowButton(
              tooltip: 'Next review',
              icon: Icons.chevron_right_rounded,
              onPressed: _showNext,
            ),
          ],
        );
      },
    );
  }

  Widget _arrowButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.lavDark,
        backgroundColor: AppColors.bgCard,
        side: const BorderSide(color: AppColors.border),
        fixedSize: const Size(48, 48),
      ),
    );
  }

  Widget _reviewCard(({String name, int rating, String review}) review) {
    return Container(
      key: ValueKey(review.name),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(review.name, style: AppTypography.labelLarge()),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                Icon(
                  star <= review.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 21,
                  color: AppColors.gold,
                ),
              const SizedBox(width: 8),
              Text(
                '${review.rating}.0',
                style: AppTypography.labelSmall(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Center(
              child: Text(
                '"${review.review}"',
                textAlign: TextAlign.center,
                style: AppTypography.displaySubtitle(
                  color: AppColors.textSub,
                ).copyWith(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesCarousel extends StatefulWidget {
  const _ServicesCarousel({required this.treatments});

  final List<Treatment> treatments;

  @override
  State<_ServicesCarousel> createState() => _ServicesCarouselState();
}

class _ServicesCarouselState extends State<_ServicesCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 560
            ? constraints.maxWidth * 0.78
            : 260.0;
        const gap = 16.0;
        final cycleWidth = (cardWidth + gap) * widget.treatments.length;
        final repeated = [...widget.treatments, ...widget.treatments];

        return SizedBox(
          height: 300,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Transform.translate(
                offset: Offset(-cycleWidth * _controller.value, 0),
                child: child,
              ),
              child: Row(
                children: [
                  for (final treatment in repeated) ...[
                    SizedBox(
                      width: cardWidth,
                      child: _ServiceCard(treatment: treatment),
                    ),
                    const SizedBox(width: gap),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.treatment});

  final Treatment treatment;

  static const _imageByTreatment = <String, String>{
    'MESOTHERAPY':
        'https://www.promedtraining.uk/wp-content/uploads/2024/04/mesotherapy-treatment-london-banner.jpeg',
    'CHEMICAL_PEEL':
        'https://skinandtox.com/wp-content/uploads/2023/12/Chemical-Peels-service-skin-n-tox-aesthetics-in-meridian-id.jpeg',
    'BOTOX':
        'https://tse2.mm.bing.net/th/id/OIP.icMThpLrMetwsuazEKt1NwHaE6?r=0&rs=1&pid=ImgDetMain&o=7&rm=3',
    'DERMAPLANING':
        'https://www.primebeautyaesthetics.co.uk/wp-content/uploads/2023/06/Dermaplaning-e18c5545-1920w.webp',
    'LASER_HAIR_REMOVAL':
        'https://tse2.mm.bing.net/th/id/OIP.0p0ZifpSOwFOiFsXVYNNXgHaE8?r=0&rs=1&pid=ImgDetMain&o=7&rm=3',
    'LASER':
        'https://tse2.mm.bing.net/th/id/OIP.0p0ZifpSOwFOiFsXVYNNXgHaE8?r=0&rs=1&pid=ImgDetMain&o=7&rm=3',
    'BODY_CONTOURING':
        'https://firebasestorage.googleapis.com/v0/b/mirabeauty-f648b.firebasestorage.app/o/services%2Fnew%2Fundefined%2Fundefined_1769442234039_0.jpeg?alt=media&token=6cad5786-5a66-4970-9a7a-4dfe11aea9f0',
    'HYDRAFACIAL':
        'https://firebasestorage.googleapis.com/v0/b/mirabeauty-f648b.firebasestorage.app/o/services%2Fnew%2Fundefined%2Fundefined_1769442234039_0.jpeg?alt=media&token=6cad5786-5a66-4970-9a7a-4dfe11aea9f0',
    'CONSULTATION':
        'https://firebasestorage.googleapis.com/v0/b/mirabeauty-f648b.firebasestorage.app/o/services%2Fnew%2Fundefined%2Fundefined_1780991788698_0.jpeg?alt=media&token=a27347b1-e434-4982-a020-e0bd02a9f008',
    'MICRONEEDLING':
        'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?auto=format&fit=crop&w=900&q=85',
    'LASER_RESURFACING':
        'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?auto=format&fit=crop&w=900&q=85',
    'IPL_PHOTOFACIAL':
        'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=900&q=85',
    'DERMAL_FILLER':
        'https://images.unsplash.com/photo-1619451334792-150fd785ee74?auto=format&fit=crop&w=900&q=85',
  };

  static const _iconByTreatment = <String, IconData>{
    'HYDRAFACIAL': Icons.water_drop_rounded,
    'CHEMICAL_PEEL': Icons.auto_fix_high_rounded,
    'MICRONEEDLING': Icons.face_retouching_natural_rounded,
    'DERMAPLANING': Icons.cleaning_services_rounded,
    'LASER_HAIR_REMOVAL': Icons.flash_on_rounded,
    'LASER_RESURFACING': Icons.flash_on_rounded,
    'IPL_PHOTOFACIAL': Icons.bolt_rounded,
    'BOTOX': Icons.vaccines_rounded,
    'DERMAL_FILLER': Icons.opacity_rounded,
    'BODY_CONTOURING': Icons.fitness_center_rounded,
    'MESOTHERAPY': Icons.healing_rounded,
    'CONSULTATION': Icons.event_available_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageByTreatment[treatment.name];
    final icon =
        _iconByTreatment[treatment.name] ?? Icons.medical_services_outlined;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: imageUrl == null
                    ? _fallbackImage(icon)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackImage(icon),
                      ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 22, color: AppColors.roseDark),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Text(
              treatment.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelLarge(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackImage(IconData icon) {
    return Container(
      color: AppColors.bgRose,
      alignment: Alignment.center,
      child: Icon(icon, size: 48, color: AppColors.rose),
    );
  }
}
