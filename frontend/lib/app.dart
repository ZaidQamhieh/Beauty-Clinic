import 'package:flutter/material.dart';
import 'package:beauty_clinic_app/core/theme/app_theme.dart';
import 'package:beauty_clinic_app/core/theme/app_typography.dart';
import 'package:beauty_clinic_app/core/theme/app_colors.dart';
import 'package:beauty_clinic_app/core/widgets/floating_petals.dart';
import 'package:beauty_clinic_app/features/shell/presentation/app_shell.dart';
import 'package:beauty_clinic_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:beauty_clinic_app/features/doctor_profile/presentation/doctor_profile_screen.dart';
import 'package:beauty_clinic_app/features/patient_profile/presentation/patient_profile_screen.dart';
import 'package:beauty_clinic_app/features/landing/presentation/landing_screen.dart';

/// Main Application Entry Widget for Yasmine Beauty Clinic
class BeautyClinicApp extends StatelessWidget {
  const BeautyClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yasmine Beauty & Derma Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainRootController(),
    );
  }
}

/// Root State Controller managing Active Role and Selected Navigation View
class MainRootController extends StatefulWidget {
  const MainRootController({super.key});

  @override
  State<MainRootController> createState() => _MainRootControllerState();
}

class _MainRootControllerState extends State<MainRootController> {
  String _activeRole =
      'admin'; // 'admin' | 'doctor' | 'receptionist' | 'patient'
  String _activeView =
      'dashboard'; // 'dashboard' | 'patient_profile' | 'doctor_profile' | 'landing'

  void _onRoleChanged(String newRole) {
    setState(() {
      _activeRole = newRole;
      if (newRole == 'patient') {
        _activeView = 'patient_profile';
      } else if (newRole == 'doctor') {
        _activeView = 'doctor_profile';
      } else {
        _activeView = 'dashboard';
      }
    });
  }

  void _onViewChanged(String newView) {
    setState(() {
      _activeView = newView;
    });
  }

  void _onViewPatient(String patientName) {
    setState(() {
      _activeView = 'patient_profile';
    });
  }

  void _onViewDoctor(String doctorName) {
    setState(() {
      _activeView = 'doctor_profile';
    });
  }

  void _openBookingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBookingDialog(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      activeRole: _activeRole,
      activeView: _activeView,
      onRoleChanged: _onRoleChanged,
      onViewChanged: _onViewChanged,
      onBookClick: _openBookingModal,
      child: Stack(
        children: [
          const FloatingPetals(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_activeView) {
      case 'dashboard':
      case 'appointments':
      case 'patients':
      case 'doctors':
        return DashboardScreen(
          key: ValueKey('dashboard_$_activeRole'),
          activeRole: _activeRole,
          onViewPatient: _onViewPatient,
          onViewDoctor: _onViewDoctor,
        );
      case 'doctor_profile':
        return DoctorProfileScreen(
          key: const ValueKey('doctor_profile'),
          onBack: () => setState(() => _activeView = 'dashboard'),
          onPatientClick: _onViewPatient,
        );
      case 'patient_profile':
        return PatientProfileScreen(
          key: const ValueKey('patient_profile'),
          onBack: () => setState(() => _activeView = 'dashboard'),
        );
      case 'landing':
      default:
        return LandingScreen(
          key: const ValueKey('landing'),
          onBookClick: _openBookingModal,
          onViewDoctor: _onViewDoctor,
        );
    }
  }

  Widget _buildBookingDialog(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Book an Appointment',
                style: AppTypography.displayTitle(color: AppColors.text),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select treatment and practitioner for your session.',
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.bgRose,
                    child: Icon(Icons.face, color: AppColors.rose),
                  ),
                  title: Text(
                    'HydraFacial Glow Treatment',
                    style: AppTypography.labelLarge(),
                  ),
                  subtitle: Text(
                    '45 min • £120',
                    style: AppTypography.bodySmall(),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.bgLavender,
                    child: Icon(Icons.auto_awesome, color: AppColors.lav),
                  ),
                  title: Text(
                    'Laser Skin Resurfacing',
                    style: AppTypography.labelLarge(),
                  ),
                  subtitle: Text(
                    '60 min • £250',
                    style: AppTypography.bodySmall(),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.bgSage,
                    child: Icon(Icons.spa, color: AppColors.sage),
                  ),
                  title: Text(
                    'Botox & Dermal Fillers Consultation',
                    style: AppTypography.labelLarge(),
                  ),
                  subtitle: Text(
                    '30 min • £80',
                    style: AppTypography.bodySmall(),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
