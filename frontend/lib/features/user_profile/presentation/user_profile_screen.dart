import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../auth/role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/password_strength_meter.dart';
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
    this.onProfileUpdated,
  });

  final Role role;
  final ApiClient apiClient;
  final VoidCallback? onBack;
  final Future<void> Function()? onProfileUpdated;

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

  static const _phonePrefixes = <String>['059', '056'];
  String _phonePrefix = _phonePrefixes.first;

  /// Prefix plus the seven local digits.
  String get _composedPhone => '$_phonePrefix${_phoneController.text.trim()}';

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

  Color get _accentDark => switch (widget.role) {
    Role.doctor => AppColors.lavDark,
    Role.patient || Role.admin => AppColors.roseDark,
    Role.receptionist => AppColors.gold,
  };

  Color get _accentPale => switch (widget.role) {
    Role.doctor => AppColors.lavPale,
    Role.patient || Role.admin => AppColors.rosePale,
    Role.receptionist => AppColors.goldPale,
  };

  String get _roleLabel => switch (widget.role) {
    Role.admin => 'Administrator',
    Role.doctor => 'Doctor',
    Role.patient => 'Patient',
    Role.receptionist => 'Receptionist',
  };

  String get _pageTitle => switch (widget.role) {
    Role.admin => 'Administrator profile',
    Role.doctor => 'Doctor profile',
    Role.patient => 'Patient profile',
    Role.receptionist => 'Receptionist profile',
  };

  bool get _hasPhoto =>
      widget.role == Role.patient || widget.role == Role.doctor;

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
        _composedPhone != profile.phone ||
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
    _imageUrlController,
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
    _applyPhone(profile.phone);
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
    if (_phoneController.text.trim().length != 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A phone number is 7 digits after the prefix.'),
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
        phone: _composedPhone,
        dateOfBirth: _selectedDateOfBirth!,
        gender: _selectedGender!,
        imageUrl: _hasPhoto ? _imageUrlController.text : null,
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
      await widget.onProfileUpdated?.call();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 780
            ? 2
            : 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(),
              const SizedBox(height: 16),
              _buildHero(name, initials),
              const SizedBox(height: 16),
              _buildDetailsCard(columns),
            ],
          ),
        );
      },
    );
  }

  /// Sections under one card, ruled headers.
  Widget _buildDetailsCard(int columns) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ruleHeader(
            _editing ? 'EDITABLE DETAILS' : 'MY DETAILS',
            hint: _editing ? 'Nothing saves until you press Save' : null,
          ),
          const SizedBox(height: 14),
          _grid(_detailCells(), columns),
          if (widget.role == Role.doctor) ...[
            const SizedBox(height: 24),
            _ruleHeader(
              'SPECIALIZATIONS',
              hint: '${_selectedSpecializations.length} active',
            ),
            const SizedBox(height: 14),
            if (_editing)
              _buildSpecializationPicker()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _doctorSpecializations.entries
                    .map(
                      (entry) => _specializationChip(
                        entry.value,
                        _selectedSpecializations.contains(entry.key),
                      ),
                    )
                    .toList(),
              ),
          ],
          const SizedBox(height: 24),
          _ruleHeader('SIGN-IN', hint: 'Email is set by the clinic'),
          const SizedBox(height: 14),
          _buildSignInSection(columns),
        ],
      ),
    );
  }

  /// Prefix dropdown, then seven digits.
  Widget _phoneRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: AppDropdownField<String>(
            initialValue: _phonePrefix,
            decoration: const InputDecoration(
              labelText: 'Prefix',
              border: OutlineInputBorder(),
            ),
            items: _phonePrefixes
                .map(
                  (prefix) => DropdownMenuItem<String>(
                    value: prefix,
                    child: Text(prefix),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _phonePrefix = value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.number,
            maxLength: 7,
            decoration: InputDecoration(
              labelText: 'Phone number *',
              counterText: '',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _accent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Splits a stored number by prefix.
  void _applyPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    for (final prefix in _phonePrefixes) {
      if (digits.startsWith(prefix)) {
        _phonePrefix = prefix;
        _phoneController.text = digits.substring(prefix.length);
        return;
      }
    }
    _phoneController.text = digits.length > 7
        ? digits.substring(digits.length - 7)
        : digits;
  }

  Widget _ruleHeader(String label, {String? hint}) {
    return Row(
      children: [
        Text(label, style: AppTypography.labelSmall()),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: AppColors.hairline)),
        if (hint != null) ...[
          const SizedBox(width: 12),
          Text(
            hint,
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  /// Fields the hero strip omits.
  List<Widget> _detailCells() {
    return [
      if (_editing) ...[
        _field('First name *', _firstNameController),
        _field('Last name *', _lastNameController),
        _phoneRow(),
        _dateOfBirthField(),
        _genderField(),
        if (widget.role == Role.doctor)
          _field(
            'Years of experience *',
            _yearsOfExperienceController,
            keyboardType: TextInputType.number,
          ),
        if (_hasPhoto)
          _field(
            'Profile picture URL',
            _imageUrlController,
            keyboardType: TextInputType.url,
          ),
      ] else ...[
        _readCell('First name', _firstNameController.text),
        _readCell('Last name', _lastNameController.text),
        _readCell('Phone number', _composedPhone),
        if (_hasPhoto)
          _readCell(
            'Profile picture',
            _imageUrlController.text.trim().isEmpty ? 'Not set' : 'Set',
          ),
      ],
    ];
  }

  Widget _buildSignInSection(int columns) {
    if (_passwordEditing) {
      return _buildPasswordEditor();
    }
    return _grid([
      _readCell('Email', _emailController.text, locked: true),
      _readCell(
        'Password',
        _passwordSaved ? 'Updated just now' : 'At least 8 characters',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() {
            _passwordEditing = true;
            _passwordSaved = false;
          }),
          icon: const Icon(Icons.lock_reset_outlined, size: 17),
          label: const Text('Change password'),
        ),
      ),
    ], columns);
  }

  /// Even columns, wrapping on narrow widths.
  Widget _grid(List<Widget> cells, int columns) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 24.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final cell in cells) SizedBox(width: width, child: cell),
          ],
        );
      },
    );
  }

  Widget _readCell(String label, String value, {bool locked = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.bodySmall(color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                value.isEmpty ? 'Not provided' : value,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium(
                  color: locked ? AppColors.textSub : AppColors.text,
                ),
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.lock_outline,
                size: 13,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_pageTitle, style: AppTypography.displayTitle()),
              const SizedBox(height: 3),
              Text(
                'Everything on your account, on one screen.',
                style: AppTypography.bodySmall(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        _buildSaveState(),
      ],
    );
  }

  Widget _buildSaveState() {
    return ListenableBuilder(
      listenable: _profileFields,
      builder: (context, _) {
        final dirty = _profileDirty;
        if (dirty) {
          return _pill('Unsaved changes', AppColors.gold);
        }
        if (_saved) {
          return _pill('All changes saved', AppColors.sageDark);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHero(String name, String initials) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final avatar = _buildHeroAvatar(initials);
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const SizedBox(width: 20),
                        Expanded(child: _buildIdentity(name)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildHeroActions(),
                  ],
                );
              }
              return Row(
                children: [
                  avatar,
                  const SizedBox(width: 20),
                  Expanded(child: _buildIdentity(name)),
                  const SizedBox(width: 20),
                  _buildHeroActions(),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 16),
          _buildMetaStrip(),
        ],
      ),
    );
  }

  Widget _buildHeroAvatar(String initials) {
    if (_hasPhoto) {
      return ProfileAvatar(
        radius: 44,
        color: _accent,
        imageUrl: _imageUrlController.text,
      );
    }
    return CircleAvatar(
      radius: 44,
      backgroundColor: _accent.withValues(alpha: .18),
      child: Text(
        initials,
        style: AppTypography.displayTitle(color: _accentDark),
      ),
    );
  }

  Widget _buildIdentity(String name) {
    final status = _serverProfile?.status ?? 'ACTIVE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
          Text(name, style: AppTypography.displaySubtitle()),
          const SizedBox(height: 4),
          Text(
            '$_roleLabel · ${_emailController.text}',
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(_statusLabel(status), AppColors.sageDark),
            if (widget.role == Role.doctor && !_editing)
              _pill(_doctorSummary, _accentDark),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroActions() {
    if (!_editing) {
      return FilledButton.icon(
        onPressed: () => setState(() {
          _editing = true;
          _saved = false;
        }),
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text('Edit profile'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        const SizedBox(width: 8),
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
                : const Text('Save changes'),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaStrip() {
    final tiles = <Widget>[
      _metaTile(
        Icons.calendar_today_outlined,
        'Date of birth',
        _formatDate(_selectedDateOfBirth),
      ),
      _metaTile(
        Icons.person_outline,
        'Gender',
        _genders[_selectedGender] ?? 'Not provided',
      ),
      if (widget.role == Role.doctor)
        _metaTile(
          Icons.workspace_premium_outlined,
          'Experience',
          _yearsOfExperienceController.text.isEmpty
              ? 'Not provided'
              : '${_yearsOfExperienceController.text} years',
        )
      else
        _metaTile(Icons.badge_outlined, 'Role', _roleLabel),
      _metaTile(
        Icons.verified_user_outlined,
        'Account',
        _statusLabel(_serverProfile?.status ?? 'ACTIVE'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (!wide) {
          return Column(
            children: [
              for (final tile in tiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: tile,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                Container(width: 1, height: 34, color: AppColors.hairline),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 16),
                  child: tiles[i],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _metaTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _accentPale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: _accentDark),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall(color: AppColors.textMuted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _specializationChip(String label, bool selected) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: selected ? _accentPale : AppColors.bgCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: selected ? _accent : AppColors.border),
    ),
    child: Text(
      label,
      style: AppTypography.labelSmall(
        color: selected ? _accentDark : AppColors.textMuted,
      ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
    ),
  );

  Widget _buildPasswordEditor() {
    return Column(
      children: [
        _passwordField(
          'Current password',
          _currentPasswordController,
          _showCurrentPassword,
          () => setState(() => _showCurrentPassword = !_showCurrentPassword),
        ),
        const SizedBox(height: 12),
        _passwordField(
          'New password',
          _newPasswordController,
          _showNewPassword,
          () => setState(() => _showNewPassword = !_showNewPassword),
        ),
        ListenableBuilder(
          listenable: _newPasswordController,
          builder: (context, _) =>
              PasswordStrengthMeter(password: _newPasswordController.text),
        ),
        const SizedBox(height: 12),
        _passwordField(
          'Confirm new password',
          _confirmPasswordController,
          _showConfirmPassword,
          () => setState(() => _showConfirmPassword = !_showConfirmPassword),
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
              builder: (context, _) => FilledButton(
                onPressed: _changingPassword || !_passwordDirty
                    ? null
                    : _changePassword,
                child: _changingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ),
          ],
        ),
      ],
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
        'Select at least one *',
        style: AppTypography.bodySmall(color: AppColors.textMuted),
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
            selectedColor: _accent.withValues(alpha: .2),
            checkmarkColor: _accentDark,
            labelStyle: TextStyle(
              color: selected ? _accentDark : AppColors.textSub,
            ),
          );
        }).toList(),
      ),
    ],
  );

  String get _doctorSummary {
    final labels = _selectedSpecializations
        .map((value) => _doctorSpecializations[value])
        .whereType<String>()
        .join(' · ');
    return labels.isEmpty ? 'No specializations' : labels;
  }

  String _statusLabel(String status) {
    final lower = status.toLowerCase().replaceAll('_', ' ');
    if (lower.isEmpty) return 'Unknown';
    return lower[0].toUpperCase() + lower.substring(1);
  }

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
    final stored =
        _selectedDateOfBirth ?? DateTime(now.year - 25, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      // A future date would break it.
      initialDate: stored.isAfter(now) ? now : stored,
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
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _accent),
      ),
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
