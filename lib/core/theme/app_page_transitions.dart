import 'package:flutter/material.dart';

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const Duration _transitionDuration = Duration(milliseconds: 320);

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        mediaQuery?.disableAnimations ??
        mediaQuery?.accessibleNavigation ??
        false;
    if (reduceMotion) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.035, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
