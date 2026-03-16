import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';

class MemberProfileShortcutButton extends StatelessWidget {
  const MemberProfileShortcutButton({
    super.key,
    this.backgroundColor = AppColors.cardDark,
    this.iconColor = AppColors.textPrimary,
    this.borderColor = AppColors.borderLight,
    this.size = 44,
    this.tooltip = 'Profile',
    this.buttonKey,
  });

  final Color backgroundColor;
  final Color iconColor;
  final Color borderColor;
  final double size;
  final String tooltip;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: CircleBorder(side: BorderSide(color: borderColor)),
        child: InkWell(
          key: buttonKey ?? const Key('member-profile-shortcut'),
          customBorder: const CircleBorder(),
          onTap: () => Navigator.pushNamed(context, AppRoutes.memberProfile),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.person_outline_rounded,
              color: iconColor,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
