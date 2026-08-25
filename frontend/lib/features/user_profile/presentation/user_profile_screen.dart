import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../auth/role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../data/user_profile_api.dart';

const _doctorSpecializations = <String, String>{
  'DERMATOLOGY': 'Dermatology',
  'COSMETIC_DERMATOLOGY': 'Cosmetic Dermatology',
  'LASER_THERAPY': 'Laser Therapy',
  'INJECTABLES': 'Injectables',
  'AESTHETIC_MEDICINE': 'Aesthetic Medicine',
};

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.role,
    required this.apiClient,
    this.onBack,
  });

  final Role role;
  final ApiClient apiClient;
  final VoidCallback? onBack;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _imageUrlController;
  final TextEditingController _dateOfBirthController = TextEditingController();
  late final TextEditingController _yearsOfExperienceController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late Set<String> _selectedSpecializations;
  bool _editing = false;
  bool _saved = false;
  bool _passwordEditing = false;
  bool _passwordSaved = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _loading = false;
  bool _saving = false;
  bool _changingPassword = false;
  UserProfile? _serverProfile;
  String? _loadError;
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;

  static const _genders = <String, String>{
    'MALE': 'Male',
    'FEMALE': 'Female',
    'OTHER': 'Other',
  };

  Color get _accent => switch (widget.role) {
    Role.doctor => AppColors.lav,
    Role.patient || Role.admin => AppColors.rose,
    Role.receptionist => AppColors.gold,
  };

  String get _roleLabel => switch (widget.role) {
    Role.admin => 'Administrator',
    Role.doctor => 'Doctor',
    Role.patient => 'Patient',
    Role.receptionist => 'Receptionist',
  };

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _imageUrlController = TextEditingController();
    _yearsOfExperienceController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedSpecializations = {};
    _loading = true;
    _loadProfile();
  }

  UserProfileApi get _profileApi => UserProfileApi(widget.apiClient);

  /// True when edits differ from the profile.
  bool get _profileDirty {
    final profile = _serverProfile;
    if (profile == null) return false;

    final years = profile.yearsOfExperience?.toString() ?? '';
    final loadedSpecializations = profile.specializations
        .where(_doctorSpecializations.containsKey)
        .toSet();
    final loadedGender = _genders.containsKey(profile.gender)
        ? profile.gender
        : null;

    return _firstNameController.text != profile.firstName ||
        _lastNameController.text != profile.lastName ||
        _phoneController.text != profile.phone ||
        _emailController.text != profile.email ||
        _yearsOfExperienceController.text != years ||
        _selectedDateOfBirth != profile.dateOfBirth ||
        _selectedGender != loadedGender ||
        !setEquals(_selectedSpecializations, loadedSpecializations);
  }

  /// True once any password field has text.
  bool get _passwordDirty =>
      _currentPasswordController.text.isNotEmpty ||
      _newPasswordController.text.isNotEmpty ||
      _confirmPasswordController.text.isNotEmpty;

  Listenable get _profileFields => Listenable.merge([
    _firstNameController,
    _lastNameController,
    _phoneController,
    _emailController,
    _yearsOfExperienceController,
  ]);

  Listenable get _passwordFields => Listenable.merge([
    _currentPasswordController,
    _newPasswordController,
    _confirmPasswordController,
  ]);

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileApi.me();
      if (!mounted) return;
      _serverProfile = profile;
      _applyProfile(profile);
      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to load your profile from the backend.';
      });
    }
  }

  void _applyProfile(UserProfile profile) {
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _phoneController.text = profile.phone;
    _emailController.text = profile.email;
    _selectedDateOfBirth = profile.dateOfBirth;
    _imageUrlController.text = profile.imageUrl ?? '';
    _dateOfBirthController.text = _formatDate(profile.dateOfBirth);
    _selectedGender = _genders.containsKey(profile.gender)
        ? profile.gender
        : null;
    _yearsOfExperienceController.text =
        profile.yearsOfExperience?.toString() ?? '';
    _selectedSpecializations = profile.specializations
        .where(_doctorSpecializations.containsKey)
        .toSet();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dateOfBirthController.dispose();
    _imageUrlController.dispose();
    _yearsOfExperienceController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'First name, last name, and phone number are required.',
          ),
        ),
      );
      return;
    }
    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth is required.')),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gender is required.')));
      return;
    }
    final yearsOfExperience = int.tryParse(
      _yearsOfExperienceController.text.trim(),
    );
    if (widget.role == Role.doctor && _selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one specialization.')),
      );
      return;
    }
    if (widget.role == Role.doctor &&
        (yearsOfExperience == null || yearsOfExperience < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Years of experience must be a non-negative number.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await _profileApi.update(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        dateOfBirth: _selectedDateOfBirth!,
        gender: _selectedGender!,
        imageUrl: widget.role == Role.patient || widget.role == Role.doctor
            ? _imageUrlController.text
            : null,
        specializations: widget.role == Role.doctor
            ? _selectedSpecializations.toList()
            : null,
        yearsOfExperience: widget.role == Role.doctor
            ? yearsOfExperience
            : null,
      );
      if (!mounted) return;
      _serverProfile = updated;
      _applyProfile(updated);
      setState(() {
        _editing = false;
        _saved = true;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save your profile.')),
      );
    }
  }

  void _cancel() {
    final profile = _serverProfile;
    if (profile == null) {
      return;
    }
    setState(() {
      _applyProfile(profile);
      _selectedSpecializations = profile.specializations
          .where(_doctorSpecializations.containsKey)
          .toSet();
      _editing = false;
    });
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showPasswordError('Complete all password fields.');
      return;
    }
    if (newPassword.length < 8) {
      _showPasswordError('The new password must be at least 8 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      _showPasswordError('The new passwords do not match.');
      return;
    }
    if (currentPassword == newPassword) {
      _showPasswordError('The new password must be different.');
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await _profileApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      setState(() {
        _passwordEditing = false;
        _passwordSaved = true;
        _changingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } on IncorrectCurrentPasswordException catch (error) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      _showPasswordError(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      _showPasswordError('Unable to update your password.');
    }
  }

  void _showPasswordError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _cancelPasswordChange() {
    setState(() {
      _passwordEditing = false;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SkeletonDetail();
    }
    if (_loadError != null) {
      return Center(
        child: Text(
          _loadError!,
          style: AppTypography.bodySmall(color: AppColors.textSub),
        ),
      );
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final name = '$firstName $lastName'.trim();
    final initials = _initialsFor(firstName, lastName);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null)
                TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Dashboard'),
                ),
              const SizedBox(height: 12),
              _buildHero(name, initials),
              if (_passwordSaved) ...[
                const SizedBox(height: 12),
                Text(
                  'Password updated successfully.',
                  style: AppTypography.bodySmall(color: AppColors.gold),
                ),
              ],
              const SizedBox(height: 20),
              _buildSection(
                title: 'Personal information',
                subtitle: 'Only you can edit these details.',
                child: _editing ? _buildEditor() : _buildReadOnly(),
              ),
              if (widget.role == Role.doctor) ...[
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Professional details',
                  subtitle: 'Your clinical specializations and experience.',
                  child: _editing
                      ? _buildDoctorEditor()
                      : _buildDoctorReadOnly(),
                ),
              ],
              const SizedBox(height: 16),
              _buildSection(
                title: 'Account access',
                subtitle: 'Your role and sign-in email are managed securely.',
                child: Column(
                  children: [
                    _infoRow('Role', _roleLabel),
                    _infoRow('Email', _emailController.text),
                    _infoRow(
                      'Status',
                      _serverProfile?.status ?? 'Unknown',
                      valueColor: AppColors.sage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildPasswordSection(),
              if (_passwordSaved) ...[
                const SizedBox(height: 12),
                Text(
                  'Password updated successfully.',
                  style: AppTypography.bodySmall(color: AppColors.gold),
                ),
              ],
              if (_saved) ...[
                const SizedBox(height: 12),
                Text(
                  'Profile changes saved successfully.',
                  style: AppTypography.bodySmall(color: AppColors.sage),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(String name, String initials) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          colors: [_accent.withValues(alpha: .12), AppColors.bgCard],
        ),
      ),
      child: Row(
        children: [
          if (widget.role == Role.patient || widget.role == Role.doctor)
            ProfileAvatar(
              radius: 38,
              color: _accent,
              imageUrl: _imageUrlController.text,
            )
          else
            CircleAvatar(
              radius: 38,
              backgroundColor: _accent.withValues(alpha: .18),
              child: Text(
                initials,
                style: AppTypography.displayTitle(color: _accent),
              ),
            ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.displayTitle()),
                const SizedBox(height: 4),
                Text(
                  widget.role == Role.doctor ? _doctorDetail : _roleLabel,
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
                const SizedBox(height: 10),
                _pill(_roleLabel, _accent),
              ],
            ),
          ),
          if (_editing) ...[
            TextButton(onPressed: _cancel, child: const Text('Cancel')),
            ListenableBuilder(
              listenable: _profileFields,
              builder: (context, _) => FilledButton(
                onPressed: _saving || !_profileDirty ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ] else
            FilledButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit profile'),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelLarge()),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildReadOnly() => Column(
    children: [
      _infoRow('First name', _firstNameController.text),
      _infoRow('Last name', _lastNameController.text),
      _infoRow('Phone number', _phoneController.text),
      _infoRow('Date of birth', _formatDate(_selectedDateOfBirth)),
      _infoRow('Gender', _genders[_selectedGender] ?? 'Not provided'),
    ],
  );

  Widget _buildEditor() => Column(
    children: [
      Row(
        children: [
          Expanded(child: _field('First name *', _firstNameController)),
          const SizedBox(width: 12),
          Expanded(child: _field('Last name *', _lastNameController)),
        ],
      ),
      const SizedBox(height: 12),
      _field(
        'Phone number *',
        _phoneController,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 12),
      _dateOfBirthField(),
      const SizedBox(height: 12),
      _genderField(),
      if (widget.role == Role.patient || widget.role == Role.doctor) ...[
        const SizedBox(height: 12),
        _field(
          'Profile picture URL',
          _imageUrlController,
          keyboardType: TextInputType.url,
        ),
      ],
    ],
  );

  Widget _buildDoctorReadOnly() => Column(
    children: [
      _infoRow('Specializations', _doctorSpecializationLabels),
      _infoRow(
        'Years of experience *',
        '${_yearsOfExperienceController.text} years',
      ),
    ],
  );

  Widget _buildDoctorEditor() => Column(
    children: [
      _buildSpecializationPicker(),
      const SizedBox(height: 12),
      _field(
        'Years of experience',
        _yearsOfExperienceController,
        keyboardType: TextInputType.number,
      ),
    ],
  );

  Widget _buildPasswordSection() {
    return _buildSection(
      title: 'Password',
      subtitle: 'Update your password securely from your own profile.',
      child: _passwordEditing
          ? Column(
              children: [
                _passwordField(
                  'Current password',
                  _currentPasswordController,
                  _showCurrentPassword,
                  () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  'New password',
                  _newPasswordController,
                  _showNewPassword,
                  () => setState(() => _showNewPassword = !_showNewPassword),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  'Confirm new password',
                  _confirmPasswordController,
                  _showConfirmPassword,
                  () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancelPasswordChange,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: _passwordFields,
                      builder: (context, _) => FilledButton.icon(
                        onPressed: _changingPassword || !_passwordDirty
                            ? null
                            : _changePassword,
                        icon: const Icon(Icons.lock_reset_outlined, size: 17),
                        label: _changingPassword
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update password'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use a unique password with at least 8 characters.',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _passwordEditing = true;
                    _passwordSaved = false;
                  }),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Change password'),
                ),
              ],
            ),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    bool visible,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      autofillHints: label == 'Current password'
          ? const [AutofillHints.password]
          : const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecializationPicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Specializations (select at least one) *',
        style: AppTypography.labelMedium(),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _doctorSpecializations.entries.map((entry) {
          final selected = _selectedSpecializations.contains(entry.key);
          return FilterChip(
            label: Text(entry.value),
            selected: selected,
            onSelected: (value) => setState(() {
              if (value) {
                _selectedSpecializations.add(entry.key);
              } else {
                _selectedSpecializations.remove(entry.key);
              }
            }),
            selectedColor: AppColors.lav.withValues(alpha: .2),
            checkmarkColor: AppColors.lavDark,
            labelStyle: TextStyle(
              color: selected ? AppColors.lavDark : AppColors.textSub,
            ),
          );
        }).toList(),
      ),
    ],
  );

  String get _doctorSpecializationLabels => _selectedSpecializations
      .map((value) => _doctorSpecializations[value])
      .whereType<String>()
      .join(' · ');

  String get _doctorDetail =>
      '$_doctorSpecializationLabels · ${_yearsOfExperienceController.text} yrs experience';

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not provided';
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _initialsFor(String firstName, String lastName) {
    if (firstName.isEmpty && lastName.isEmpty) {
      return '?';
    }
    if (firstName.isEmpty) {
      return lastName.substring(0, 1).toUpperCase();
    }
    if (lastName.isEmpty) {
      return firstName.substring(0, 1).toUpperCase();
    }
    return '${firstName.substring(0, 1)}${lastName.substring(0, 1)}'
        .toUpperCase();
  }

  Widget _dateOfBirthField() {
    return TextField(
      controller: _dateOfBirthController,
      readOnly: true,
      onTap: _pickDateOfBirth,
      decoration: const InputDecoration(
        labelText: 'Date of birth *',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.calendar_today_outlined),
      ),
    );
  }

  Widget _genderField() {
    return AppDropdownField<String>(
      initialValue: _selectedGender,
      decoration: const InputDecoration(
        labelText: 'Gender *',
        border: OutlineInputBorder(),
      ),
      items: _genders.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedGender = value),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDateOfBirth = selected;
      _dateOfBirthController.text = _formatDate(selected);
    });
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.rose),
      ),
    ),
  );

  Widget _infoRow(String label, String value, {Color? valueColor}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.hairline)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall(color: AppColors.textMuted)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.labelMedium(
              color: valueColor ?? AppColors.text,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: AppTypography.labelSmall(color: color)),
  );
}
