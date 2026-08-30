part of 'staff_management_screen.dart';

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
  final Set<_DoctorSpecialization> _selectedSpecializations =
      <_DoctorSpecialization>{};
  DateTime? _selectedDateOfBirth;
  String _selectedCountryCode = countryDialCodes.first;
  bool _isSubmitting = false;
  String? _submitError;
  bool _passwordVisible = false;

  bool get _isDoctor => widget.role == _StaffRole.doctor;
  bool get _isEditing => widget.initialStaff != null;

  late List<Object?> _initialSnapshot;

  // Every editable field, in a stable order.
  List<Object?> _snapshot() => [
    _firstNameController.text,
    _lastNameController.text,
    _emailController.text,
    _mobileNumberController.text,
    _passwordController.text,
    _yearsOfExperienceController.text,
    _dateOfBirthController.text,
    _selectedGender,
    _selectedStatus,
    _selectedDateOfBirth,
    _selectedCountryCode,
    ..._selectedSpecializations.map((s) => s.name).toList()..sort(),
  ];

  bool get _isDirty => !listEquals(_snapshot(), _initialSnapshot);

  Listenable get _textFields => Listenable.merge([
    _firstNameController,
    _lastNameController,
    _emailController,
    _mobileNumberController,
    _passwordController,
    _yearsOfExperienceController,
    _dateOfBirthController,
  ]);

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
      _selectedSpecializations.addAll(
        staff.specializations
            .map(_parseSpecialization)
            .whereType<_DoctorSpecialization>(),
      );
      _selectedDateOfBirth = staff.dateOfBirth;
      if (staff.dateOfBirth != null) {
        _dateOfBirthController.text = _formatDate(staff.dateOfBirth!);
      }
      _splitPhone(staff.phone);
    }
    _initialSnapshot = _snapshot();
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

    if (_isDoctor && _selectedSpecializations.isEmpty) {
      setState(() {
        _submitError = 'Select at least one specialization for a doctor.';
      });
      return;
    }

    final tooMany = _isDoctor
        ? FieldRules.selectionCount(
            _selectedSpecializations.length,
            'specializations',
            max: 20,
          )
        : null;
    if (tooMany != null) {
      setState(() => _submitError = tooMany);
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
    final accent = _isDoctor ? AppColors.lavDark : AppColors.gold;
    final title = _isEditing
        ? (_isDoctor ? 'Edit Doctor' : 'Edit Receptionist')
        : (_isDoctor ? 'Register New Doctor' : 'Register New Receptionist');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.bgCard,
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
                    Text(title, style: AppTypography.displaySubtitle()),
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
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                        validator: (value) =>
                            FieldRules.personName(value, 'First name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _textField(
                        controller: _lastNameController,
                        label: 'Last Name *',
                        validator: (value) =>
                            FieldRules.personName(value, 'Last name'),
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
                      FieldRules.dateOfBirth(_selectedDateOfBirth, minAge: 18),
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
                  validator: FieldRules.email,
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
                  obscureText: !_passwordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                  validator: (value) {
                    // Blank on edit keeps old password.
                    if (_isEditing && (value?.trim().isEmpty ?? true)) {
                      return null;
                    }
                    return FieldRules.password(
                      value,
                      email: _emailController.text,
                      firstName: _firstNameController.text,
                      lastName: _lastNameController.text,
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: _passwordController,
                  builder: (context, _) =>
                      PasswordStrengthMeter(password: _passwordController.text),
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
                if (_isDoctor) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Professional Details', accent),
                  const SizedBox(height: 12),
                  Text('Specializations *', style: AppTypography.labelMedium()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _DoctorSpecialization.values.map((entry) {
                      final selected = _selectedSpecializations.contains(entry);
                      return FilterChip(
                        label: Text(_enumLabel(entry)),
                        selected: selected,
                        onSelected: (isSelected) {
                          setState(() {
                            if (isSelected) {
                              _selectedSpecializations.add(entry);
                            } else {
                              _selectedSpecializations.remove(entry);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_selectedSpecializations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'At least one specialization is required.',
                        style: AppTypography.bodySmall(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
                    ListenableBuilder(
                      listenable: _textFields,
                      builder: (context, _) => ElevatedButton(
                        onPressed: _isSubmitting || !_isDirty ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
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

  String? _experienceValidator(String? value) =>
      FieldRules.yearsOfExperience(value, dateOfBirth: _selectedDateOfBirth);

  String? _mobileNumberValidator(String? value) =>
      FieldRules.phoneDigits(value, length: 9);

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
        'specializations': _selectedSpecializations
            .map(_doctorSpecializationValue)
            .toList(),
        'yearsOfExperience': int.parse(
          _yearsOfExperienceController.text.trim(),
        ),
      };
    }

    return payload;
  }

  String _doctorSpecializationValue(_DoctorSpecialization specialization) {
    return switch (specialization) {
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

    for (final code in countryDialCodes) {
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
      _AccountStatus.deactivated => 'Deactivated',
    };
  }

  Widget _countryCodeField() {
    return AppDropdownField<String>(
      initialValue: _selectedCountryCode,
      labelOf: (code) => code,
      items: countryDialCodes
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    return AppDropdownField<T>(
      initialValue: value,
      hintText: 'Select ${label.toLowerCase()}',
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    Widget? suffixIcon,
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
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

Widget _sectionLabel(String title, Color accent) {
  return Text(
    title,
    style: AppTypography.labelMedium(
      color: accent,
    ).copyWith(letterSpacing: 0.3, fontWeight: FontWeight.w700),
  );
}
