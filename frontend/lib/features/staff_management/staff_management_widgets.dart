part of 'staff_management_screen.dart';

const double _colExperience = 84;
const double _colRole = 100;
const double _colStatus = 96;
const double _colActions = 88;
const double _colGap = 16;

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : AppColors.border),
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
            Text(value, style: AppTypography.displayStat()),
            Text(title, style: AppTypography.labelMedium()),
            Text(subtitle, style: AppTypography.labelSmall(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Column labels above the staff rows.
class _StaffColumnHeader extends StatelessWidget {
  const _StaffColumnHeader({
    required this.experienceAscending,
    required this.onToggleExperienceSort,
  });

  final bool? experienceAscending;
  final VoidCallback onToggleExperienceSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Expanded(flex: 3, child: _ColumnLabel('Name')),
          const SizedBox(width: _colGap),
          const Expanded(flex: 2, child: _ColumnLabel('Specializations')),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _colExperience,
            child: InkWell(
              onTap: onToggleExperienceSort,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const _ColumnLabel('Years'),
                  const SizedBox(width: 3),
                  Icon(
                    experienceAscending == null
                        ? Icons.unfold_more_rounded
                        : experienceAscending!
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 13,
                    color: experienceAscending == null
                        ? AppColors.textMuted
                        : AppColors.roseDark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: _colGap),
          const SizedBox(width: _colRole, child: _ColumnLabel('Role')),
          const SizedBox(width: _colStatus, child: _ColumnLabel('Status')),
          const SizedBox(width: _colActions),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelSmall(
        color: AppColors.textMuted,
      ).copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.7),
    );
  }
}

class _SpecializationChip extends StatelessWidget {
  const _SpecializationChip(this.label, {this.tooltip});

  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(color: AppColors.textSub),
      ),
    );

    if (tooltip == null) {
      return chip;
    }

    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 200),
      child: MouseRegion(cursor: SystemMouseCursors.help, child: chip),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.onOpenDoctor,
  });

  final StaffMember item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenDoctor;

  @override
  Widget build(BuildContext context) {
    final bool isDoctor = item.role == 'DOCTOR';
    final Color roleAccent = isDoctor ? AppColors.lavDark : AppColors.gold;
    final Color roleBackground = isDoctor
        ? AppColors.lavPale
        : AppColors.goldPale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: onOpenDoctor,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: roleBackground,
                    child: Text(
                      _initials(item.fullName),
                      style: TextStyle(
                        color: roleAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.fullName, style: AppTypography.labelLarge()),
                        const SizedBox(height: 4),
                        Text(
                          item.email,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: _colGap),
          Expanded(flex: 2, child: _buildSpecializations(isDoctor)),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _colExperience,
            child: Text(
              isDoctor && item.yearsOfExperience != null
                  ? '${item.yearsOfExperience} yrs'
                  : '—',
              textAlign: TextAlign.right,
              style: AppTypography.labelSmall(
                color: AppColors.textSub,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _colRole,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _pill(
                _roleLabel(item.role),
                roleBackground,
                roleAccent,
              ),
            ),
          ),
          SizedBox(
            width: _colStatus,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _pill(
                _statusLabel(item.status),
                _statusColor(item.status).withValues(alpha: 0.16),
                _statusColor(item.status),
              ),
            ),
          ),
          SizedBox(
            width: _colActions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Two chips, then a counter.
  Widget _buildSpecializations(bool isDoctor) {
    if (!isDoctor || item.specializations.isEmpty) {
      return Text(
        '—',
        style: AppTypography.labelSmall(color: AppColors.textMuted),
      );
    }

    final labels = item.specializations.map(_formatSpecializationLabel).toList();
    final visible = labels.take(2).toList();
    final hidden = labels.skip(visible.length).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...visible.map((label) => _SpecializationChip(label, tooltip: label)),
        if (hidden.isNotEmpty)
          _SpecializationChip(
            '+${hidden.length}',
            tooltip: hidden.join('\n'),
          ),
      ],
    );
  }

  Widget _pill(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    return role == 'RECEPTIONIST' ? 'Receptionist' : 'Doctor';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'ACTIVE' => 'Active',
      'DEACTIVATED' => 'Deactivated',
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'ACTIVE' => AppColors.sageDark,
      'DEACTIVATED' => AppColors.textMuted,
      _ => AppColors.textMuted,
    };
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isEmpty ? 'DR' : fullName.substring(0, 1).toUpperCase();
  }

  String _formatSpecializationLabel(String raw) {
    return raw
        .toLowerCase()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
