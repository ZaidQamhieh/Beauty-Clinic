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
    final Color roleAccent = isDoctor ? AppColors.lavDark : AppColors.gold;
    final Color roleBackground = isDoctor
        ? AppColors.lavPale
        : AppColors.goldPale;

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
                  Text(
                    item.specializations
                        .map(_formatSpecializationLabel)
                        .join(', '),
                    style: TextStyle(fontSize: 12, color: roleAccent),
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
            isDoctor && item.yearsOfExperience != null
                ? '${item.yearsOfExperience} yrs'
                : '-',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
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
