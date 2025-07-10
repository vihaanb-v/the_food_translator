import 'package:flutter/material.dart';

void smoothPush(BuildContext context, Widget page) {
  Navigator.of(context).push(_ultraSmoothPageRoute(page));
}

void smoothReplace(BuildContext context, Widget page) {
  Navigator.of(context).pushReplacement(_ultraSmoothPageRoute(page));
}

PageRouteBuilder _ultraSmoothPageRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 750),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutQuart,
      );

      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0), // ultra subtle slide
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}