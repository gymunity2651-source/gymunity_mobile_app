import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/app_motion.dart';

typedef MotionDestinationBuilder = Widget Function(BuildContext context);

class MotionActionTile extends StatelessWidget {
  const MotionActionTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.destinationBuilder,
    this.onTap,
  }) : assert(
         destinationBuilder != null || onTap != null,
         'Either destinationBuilder or onTap must be provided.',
       );

  final String title;
  final String description;
  final IconData icon;
  final MotionDestinationBuilder? destinationBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final builder = destinationBuilder;
    if (builder == null) {
      return _MotionActionTileSurface(
        title: title,
        description: description,
        icon: icon,
        onTap: onTap!,
      );
    }

    return OpenContainer<void>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: AppMotion.slow,
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: AppColors.background,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      openBuilder: (context, _) => builder(context),
      closedBuilder: (context, openContainer) => _MotionActionTileSurface(
        title: title,
        description: description,
        icon: icon,
        onTap: openContainer,
      ),
    );
  }
}

class _MotionActionTileSurface extends StatefulWidget {
  const _MotionActionTileSurface({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_MotionActionTileSurface> createState() =>
      _MotionActionTileSurfaceState();
}

class _MotionActionTileSurfaceState extends State<_MotionActionTileSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? AppMotion.pressedScale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) {
            if (value != _pressed) {
              setState(() => _pressed = value);
            }
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standardCurve,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(
                color: _pressed
                    ? AppColors.orange.withValues(alpha: 0.46)
                    : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(
                    alpha: _pressed ? 0.28 : 0.18,
                  ),
                  blurRadius: _pressed ? 22 : 14,
                  offset: Offset(0, _pressed ? 10 : 6),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.orange.withValues(alpha: 0.14),
                child: Icon(widget.icon, color: AppColors.orange),
              ),
              title: Text(
                widget.title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                widget.description,
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.arrow_outward_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
