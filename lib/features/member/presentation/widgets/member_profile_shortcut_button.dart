import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../user/presentation/widgets/profile_avatar.dart';

class MemberProfileShortcutButton extends ConsumerWidget
    implements PreferredSizeWidget {
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final hasAvatar = profile?.avatarPath?.trim().isNotEmpty == true;

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
            child: hasAvatar
                ? Padding(
                    padding: const EdgeInsets.all(2),
                    child: ProfileAvatar(
                      size: size - 4,
                      avatarPath: profile?.avatarPath,
                      fullName: profile?.fullName,
                    ),
                  )
                : Icon(
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
