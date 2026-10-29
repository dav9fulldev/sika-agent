import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'sika_pay_ui.dart';

/// Groupe de lignes sous un titre court, comme dans les réglages du téléphone.
class SikaListSection extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const SikaListSection(this.title, this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06));
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ),
        SikaPayCard(
          padding: EdgeInsets.zero,
          // Material propre à la carte : sans lui, l'effet de toucher des lignes est caché par le fond
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) divider, rows[i]],
            ]),
          ),
        ),
      ]),
    );
  }
}

class SikaListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final Color? color;
  const SikaListRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(fontSize: 12.5, color: muted)),
      trailing: trailing != null
          ? Text(trailing!, style: TextStyle(color: muted, fontWeight: FontWeight.w600))
          : (onTap != null && color == null ? Icon(Icons.chevron_right_rounded, color: muted) : null),
      onTap: onTap,
    );
  }
}

class SikaListSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SikaListSwitch({super.key, required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
      value: value,
      activeThumbColor: AppColors.brandPrimary,
      activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
      onChanged: onChanged,
    );
  }
}
