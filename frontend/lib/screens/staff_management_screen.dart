import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../network/api_client.dart';

class StaffMember {
  const StaffMember({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.role,
    required this.status,
    required this.specializations,
    required this.yearsOfExperience,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final String gender;
  final String role;
  final String status;
  final List<String> specializations;
  final int? yearsOfExperience;

  String get fullName => '$firstName $lastName'.trim();

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final doctorProfile = json['doctorProfile'];
    final profileMap = doctorProfile is Map<String, dynamic>
        ? doctorProfile
        : <String, dynamic>{};

    final rawSpecializations = profileMap['specializations'];
    final parsedSpecializations = rawSpecializations is List
        ? rawSpecializations.map((entry) => entry.toString()).toList()
        : <String>[];

    return StaffMember(
      userId: (json['id'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      dateOfBirth: DateTime.tryParse((json['dateOfBirth'] ?? '').toString()),
      gender: (json['gender'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      specializations: parsedSpecializations,
      yearsOfExperience: profileMap['yearsOfExperience'] as int?,
    );
  }
}

class _Palette {
  static const rose = Color(0xFFB45472);
  static const bgRose = Color(0xFFFBEAEE);
  static const borderRose = Color(0xFFEFD0D6);
  static const lav = Color(0xFF7354B9);
  static const textMuted = Color(0xFF8B6E73);
}

enum _StaffRole { doctor, receptionist }

enum _StaffFilter { all, doctor, receptionist }

enum _Gender { male, female, other }

enum _AccountStatus { active, invited, deactivated }

enum _DoctorSpecialization {
  dermatology,
  cosmeticDermatology,
  laserTherapy,
  injectables,
  aestheticMedicine,
}

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    super.key,
    required this.apiClient,
    required this.authSession,
  });

  final ApiClient apiClient;
  final AuthSession authSession;

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late Future<List<StaffMember>> _staffFuture;
  _StaffFilter _selectedFilter = _StaffFilter.all;

  @override
  void initState() {
    super.initState();
    _staffFuture = _loadStaff();
  }

  Future<List<StaffMember>> _loadStaff() async {
    if (!widget.authSession.isAuthenticated) {
      throw const AuthException();
    }

    final accessToken = await widget.authSession.validAccessToken();
    if (accessToken == null) {
      throw const AuthException();
    }

    final response = await widget.apiClient.get<dynamic>('/api/admin/accounts');
    final raw = response.data;

    if (raw is! List) {
      throw const FormatException('Invalid staff list payload.');
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .where((member) => member.fullName.isNotEmpty)
        .toList();
  }

  void _refreshStaff() {
    setState(() {
      _staffFuture = _loadStaff();
    });
  }

  void _setFilter(_StaffFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  List<StaffMember> _applyFilter(List<StaffMember> staff) {
    return switch (_selectedFilter) {
      _StaffFilter.all => staff,
      _StaffFilter.doctor =>
        staff.where((member) => member.role == 'DOCTOR').toList(),
      _StaffFilter.receptionist =>
        staff.where((member) => member.role == 'RECEPTIONIST').toList(),
    };
  }

  String _roleLabel(String role) {
    return role == 'RECEPTIONIST' ? 'Receptionist' : 'Doctor';
  }

  String _friendlyDioError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final details = switch (body) {
      Map<String, dynamic>() =>
        (body['message'] ?? body['detail'] ?? body['error'] ?? '').toString(),
      _ => '',
    };

    if (status == 404) {
      return details.isEmpty
          ? 'Request failed with 404. Please check backend route mapping.'
          : 'Request failed with 404: $details';
    }

    if (status == 403) {
      return details.isEmpty
          ? 'Access denied (403). This endpoint requires ADMIN privileges.'
          : 'Access denied (403): $details';
    }

    if (status == 400 || status == 422) {
      return details.isEmpty
          ? 'Validation failed. Please check required fields and enum values.'
          : 'Validation failed: $details';
    }

    if (status != null) {
      return details.isEmpty
          ? 'Request failed with status $status.'
          : 'Request failed with status $status: $details';
    }

    return 'Request failed: ${error.message ?? error.toString()}';
  }

  Future<void> _openFormDialog({
    required _StaffRole role,
    StaffMember? initialStaff,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StaffFormDialog(
        role: role,
        apiClient: widget.apiClient,
        initialStaff: initialStaff,
      ),
    );

    if (saved == true) {
      _refreshStaff();
    }
  }

  Future<void> _deleteStaff(StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${member.fullName}?'),
        content: Text(
          'This will permanently remove the ${_roleLabel(member.role).toLowerCase()} account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.apiClient.delete<dynamic>(
        '/api/admin/accounts/${member.userId}',
      );
      _refreshStaff();
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyDioError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF8),
        title: const Text('Staff Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => _openFormDialog(role: _StaffRole.receptionist),
              icon: const Icon(Icons.add, size: 18, color: _Palette.rose),
              label: const Text('Register Receptionist'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _Palette.rose,
                backgroundColor: _Palette.bgRose,
                side: const BorderSide(color: _Palette.borderRose),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _openFormDialog(role: _StaffRole.doctor),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Register Doctor'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _Palette.lav,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<StaffMember>>(
          future: _staffFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load staff.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            }

            final staff = snapshot.data ?? const <StaffMember>[];
            final visibleStaff = _applyFilter(staff);
            final doctors = staff
                .where((entry) => entry.role == 'DOCTOR')
                .length;
            final receptionists = staff
                .where((entry) => entry.role == 'RECEPTIONIST')
                .length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage clinic staff — doctors and receptionists',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF8B6E73),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _StatTile(
                        title: 'All',
                        value: '${staff.length}',
                        subtitle: 'Show all staff',
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFFB45472),
                        selected: _selectedFilter == _StaffFilter.all,
                        onTap: () => _setFilter(_StaffFilter.all),
                      ),
                      _StatTile(
                        title: 'Doctors',
                        value: '$doctors',
                        subtitle: 'Filter doctors',
                        icon: Icons.medical_services_rounded,
                        color: const Color(0xFF8C6ABF),
                        selected: _selectedFilter == _StaffFilter.doctor,
                        onTap: () => _setFilter(_StaffFilter.doctor),
                      ),
                      _StatTile(
                        title: 'Receptionists',
                        value: '$receptionists',
                        subtitle: 'Filter receptionists',
                        icon: Icons.event_available_rounded,
                        color: const Color(0xFFB18043),
                        selected: _selectedFilter == _StaffFilter.receptionist,
                        onTap: () => _setFilter(_StaffFilter.receptionist),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEFD0D6)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 54,
                          child: Row(
                            children: [
                              Expanded(child: Center(child: Text('All Staff'))),
                            ],
                          ),
                        ),
                        if (visibleStaff.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No staff found for the selected filter.',
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visibleStaff.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = visibleStaff[index];
                              return _StaffRow(
                                item: item,
                                onEdit: () => _openFormDialog(
                                  role: item.role == 'RECEPTIONIST'
                                      ? _StaffRole.receptionist
                                      : _StaffRole.doctor,
                                  initialStaff: item,
                                ),
                                onDelete: () => _deleteStaff(item),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StaffFormDialog extends StatefulWidget {
  const _StaffFormDialog({
    required this.role,
    required this.apiClient,
    this.initialStaff,
  });

  final _StaffRole role;
  final ApiClient apiClient;
  final StaffMember? initialStaff;

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  static const _countryCodes = <String>[
    '+1',
    '+20',
    '+44',
    '+49',
    '+61',
    '+91',
    '+971',
  ];

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _yearsOfExperienceController = TextEditingController();
  final _dateOfBirthController = TextEditingController();

  _Gender? _selectedGender;
  _AccountStatus _selectedStatus = _AccountStatus.active;
  _DoctorSpecialization? _selectedSpecialization;
  DateTime? _selectedDateOfBirth;
  String _selectedCountryCode = _countryCodes.first;
  bool _isSubmitting = false;
  String? _submitError;

  bool get _isDoctor => widget.role == _StaffRole.doctor;
  bool get _isEditing => widget.initialStaff != null;

  @override
  void initState() {
    super.initState();
    final staff = widget.initialStaff;
    if (staff != null) {
      _firstNameController.text = staff.firstName;
      _lastNameController.text = staff.lastName;
      _emailController.text = staff.email;
      _passwordController.text = '';
      _yearsOfExperienceController.text =
          staff.yearsOfExperience?.toString() ?? '';
      _selectedGender = _parseGender(staff.gender);
      _selectedStatus = _parseStatus(staff.status) ?? _AccountStatus.active;
      _selectedSpecialization = staff.specializations.isEmpty
          ? null
          : _parseSpecialization(staff.specializations.first);
      _selectedDateOfBirth = staff.dateOfBirth;
      if (staff.dateOfBirth != null) {
        _dateOfBirthController.text = _formatDate(staff.dateOfBirth!);
      }
      _splitPhone(staff.phone);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileNumberController.dispose();
    _passwordController.dispose();
    _yearsOfExperienceController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final payload = _buildPayload();
      final path = _isEditing
          ? '/api/admin/accounts/${widget.initialStaff!.userId}'
          : '/api/admin/accounts';

      if (_isEditing) {
        await widget.apiClient.put<dynamic>(path, data: payload);
      } else {
        await widget.apiClient.post<dynamic>(path, data: payload);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      setState(() {
        _submitError = _friendlyDioError(error);
      });
    } catch (error) {
      setState(() {
        _submitError = 'Could not save staff member: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isDoctor ? _Palette.lav : _Palette.rose;
    final title = _isEditing
        ? (_isDoctor ? 'Edit Doctor' : 'Edit Receptionist')
        : (_isDoctor ? 'Register New Doctor' : 'Register New Receptionist');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'All fields marked * are required',
                  style: TextStyle(fontSize: 12, color: _Palette.textMuted),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Personal Details', accent),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _textField(
                        controller: _firstNameController,
                        label: 'First Name *',
                        validator: _requiredValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _textField(
                        controller: _lastNameController,
                        label: 'Last Name *',
                        validator: _requiredValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Date of Birth *',
                  controller: _dateOfBirthController,
                  onTap: _pickDateOfBirth,
                  validator: (_) =>
                      _selectedDateOfBirth == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _dropdownField<_Gender>(
                  label: 'Gender *',
                  value: _selectedGender,
                  items: _Gender.values,
                  labelBuilder: _enumLabel,
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Contact & Access', accent),
                const SizedBox(height: 12),
                _textField(
                  controller: _emailController,
                  label: 'Email Address *',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(width: 120, child: _countryCodeField()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _textField(
                        controller: _mobileNumberController,
                        label: 'Mobile Number (9 digits) *',
                        keyboardType: TextInputType.number,
                        validator: _mobileNumberValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _passwordController,
                  label: _isEditing
                      ? 'New Password (optional)'
                      : 'Temporary Password *',
                  obscureText: true,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (_isEditing && trimmed.isEmpty) {
                      return null;
                    }

                    if (trimmed.length < 8) {
                      return 'Minimum 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _dropdownField<_AccountStatus>(
                  label: 'Status *',
                  value: _selectedStatus,
                  items: _AccountStatus.values,
                  labelBuilder: _accountStatusLabel,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Created at and updated at are set by the backend automatically.',
                  style: TextStyle(fontSize: 12, color: _Palette.textMuted),
                ),
                if (_isDoctor) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Professional Details', accent),
                  const SizedBox(height: 12),
                  _dropdownField<_DoctorSpecialization>(
                    label: 'Specialization *',
                    value: _selectedSpecialization,
                    items: _DoctorSpecialization.values,
                    labelBuilder: _enumLabel,
                    onChanged: (value) {
                      setState(() => _selectedSpecialization = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _yearsOfExperienceController,
                    label: 'Years of Experience *',
                    keyboardType: TextInputType.number,
                    validator: _experienceValidator,
                  ),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _submitError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing
                                  ? 'Update Staff Member'
                                  : 'Save Staff Member',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _experienceValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Required';
    }

    final years = int.tryParse(trimmed);
    if (years == null || years < 0) {
      return 'Enter a valid number';
    }

    return null;
  }

  String? _mobileNumberValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Required';
    }

    if (!RegExp(r'^\d{9}$').hasMatch(trimmed)) {
      return 'Enter exactly 9 digits';
    }

    return null;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate =
        _selectedDateOfBirth ?? DateTime(now.year - 25, now.month, now.day);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedDateOfBirth = selected;
      _dateOfBirthController.text = _formatDate(selected);
    });
  }

  Map<String, dynamic> _buildPayload() {
    final password = _passwordController.text.trim();
    final payload = <String, dynamic>{
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': '$_selectedCountryCode${_mobileNumberController.text.trim()}',
      'dateOfBirth': _formatDate(_selectedDateOfBirth!),
      'gender': _selectedGender!.name.toUpperCase(),
      'status': _selectedStatus.name.toUpperCase(),
      'role': widget.role == _StaffRole.doctor ? 'DOCTOR' : 'RECEPTIONIST',
    };

    if (!_isEditing || password.isNotEmpty) {
      payload['password'] = password;
    }

    if (_isDoctor) {
      payload['doctorProfile'] = {
        'specializations': <String>[_doctorSpecializationValue()],
        'yearsOfExperience': int.parse(
          _yearsOfExperienceController.text.trim(),
        ),
      };
    }

    return payload;
  }

  String _doctorSpecializationValue() {
    return switch (_selectedSpecialization!) {
      _DoctorSpecialization.dermatology => 'DERMATOLOGY',
      _DoctorSpecialization.cosmeticDermatology => 'COSMETIC_DERMATOLOGY',
      _DoctorSpecialization.laserTherapy => 'LASER_THERAPY',
      _DoctorSpecialization.injectables => 'INJECTABLES',
      _DoctorSpecialization.aestheticMedicine => 'AESTHETIC_MEDICINE',
    };
  }

  _Gender? _parseGender(String value) {
    return switch (value.toUpperCase()) {
      'MALE' => _Gender.male,
      'FEMALE' => _Gender.female,
      'OTHER' => _Gender.other,
      _ => null,
    };
  }

  _AccountStatus? _parseStatus(String value) {
    return switch (value.toUpperCase()) {
      'ACTIVE' => _AccountStatus.active,
      'INVITED' => _AccountStatus.invited,
      'DEACTIVATED' => _AccountStatus.deactivated,
      _ => null,
    };
  }

  _DoctorSpecialization? _parseSpecialization(String value) {
    return switch (value.toUpperCase()) {
      'DERMATOLOGY' => _DoctorSpecialization.dermatology,
      'COSMETIC_DERMATOLOGY' => _DoctorSpecialization.cosmeticDermatology,
      'LASER_THERAPY' => _DoctorSpecialization.laserTherapy,
      'INJECTABLES' => _DoctorSpecialization.injectables,
      'AESTHETIC_MEDICINE' => _DoctorSpecialization.aestheticMedicine,
      _ => null,
    };
  }

  void _splitPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      return;
    }

    for (final code in _countryCodes) {
      if (trimmed.startsWith(code)) {
        _selectedCountryCode = code;
        _mobileNumberController.text = trimmed.substring(code.length);
        return;
      }
    }

    _mobileNumberController.text = trimmed;
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _enumLabel(Enum value) {
    return value.name
        .replaceAllMapped(
          RegExp(r'(?<!^)([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .split('_')
        .join(' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _accountStatusLabel(_AccountStatus status) {
    return switch (status) {
      _AccountStatus.active => 'Active',
      _AccountStatus.invited => 'Invited',
      _AccountStatus.deactivated => 'Deactivated',
    };
  }

  Widget _countryCodeField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCountryCode,
      items: _countryCodes
          .map(
            (code) => DropdownMenuItem<String>(value: code, child: Text(code)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCountryCode = value);
        }
      },
      decoration: InputDecoration(
        labelText: 'Code',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _friendlyDioError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final details = switch (body) {
      Map<String, dynamic>() =>
        (body['message'] ?? body['detail'] ?? body['error'] ?? '').toString(),
      _ => '',
    };

    if (status == 404) {
      return details.isEmpty
          ? 'Request failed with 404. Please check backend route mapping.'
          : 'Request failed with 404: $details';
    }

    if (status == 403) {
      return details.isEmpty
          ? 'Access denied (403). This endpoint requires ADMIN privileges.'
          : 'Access denied (403): $details';
    }

    if (status == 400 || status == 422) {
      return details.isEmpty
          ? 'Validation failed. Please check required fields and enum values.'
          : 'Validation failed: $details';
    }

    if (status != null) {
      return details.isEmpty
          ? 'Request failed with status $status.'
          : 'Request failed with status $status: $details';
    }

    return 'Request failed: ${error.message ?? error.toString()}';
  }

  Widget _dropdownField<T extends Enum>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items
          .map(
            (entry) => DropdownMenuItem<T>(
              value: entry,
              child: Text(labelBuilder(entry)),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (selected) => selected == null ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

Widget _sectionLabel(String title, Color accent) {
  return Text(
    title,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: accent,
      letterSpacing: 0.3,
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : const Color(0xFFEADDE0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final StaffMember item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFF1EAF9),
            child: Text(
              _initials(item.fullName),
              style: const TextStyle(
                color: Color(0xFF7354B9),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  item.specializations.isEmpty
                      ? _roleLabel(item.role)
                      : item.specializations.join(', '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B6E73),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(item.status).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              _statusLabel(item.status),
              style: TextStyle(fontSize: 11, color: _statusColor(item.status)),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            item.role == 'DOCTOR' && item.yearsOfExperience != null
                ? '${item.yearsOfExperience} yrs'
                : '-',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B6E73)),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    return role == 'RECEPTIONIST' ? 'Receptionist' : 'Doctor';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'ACTIVE' => 'Active',
      'INVITED' => 'Invited',
      'DEACTIVATED' => 'Deactivated',
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'ACTIVE' => const Color(0xFF257A54),
      'INVITED' => const Color(0xFFB18043),
      'DEACTIVATED' => const Color(0xFF8B6E73),
      _ => const Color(0xFF8B6E73),
    };
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isEmpty ? 'DR' : fullName.substring(0, 1).toUpperCase();
  }
}
