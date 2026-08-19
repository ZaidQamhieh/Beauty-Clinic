part of 'staff_management_screen.dart';

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
    final bool isDoctor = item.role == 'DOCTOR';
    final Color roleAccent = isDoctor ? AppColors.lavDark : AppColors.roseDark;
    final Color roleBackground = isDoctor
        ? AppColors.lavPale
        : AppColors.rosePale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: roleBackground,
            child: Text(
              _initials(item.fullName),
              style: TextStyle(color: roleAccent, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.fullName, style: AppTypography.labelLarge()),
                const SizedBox(height: 6),
                if (isDoctor && item.specializations.isNotEmpty)
                  _buildSpecializationChips(
                    item.specializations,
                    roleAccent,
                    roleBackground,
                  )
                else
                  Text(
                    _roleLabel(item.role),
                    style: TextStyle(fontSize: 12, color: roleAccent),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: roleBackground,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              _roleLabel(item.role),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: roleAccent,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
      'ACTIVE' => AppColors.sageDark,
      'INVITED' => AppColors.gold,
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

  Widget _buildSpecializationChips(
    List<String> specializations,
    Color roleAccent,
    Color roleBackground,
  ) {
    const int maxVisible = 2;
    final visible = specializations.take(maxVisible).toList();
    final hiddenCount = specializations.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final specialization in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: roleBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: roleAccent.withValues(alpha: 0.28)),
            ),
            child: Text(
              _formatSpecializationLabel(specialization),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: roleAccent,
              ),
            ),
          ),
        if (hiddenCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '+$hiddenCount more',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSub,
              ),
            ),
          ),
      ],
    );
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
