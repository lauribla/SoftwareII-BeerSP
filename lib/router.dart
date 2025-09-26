import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'HomeScreen.dart';
import 'AgeGateScreen.dart';
import 'SignInScreen.dart';
import 'SignUpScreen.dart';

final appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    // Home
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),

    // AgeGate (verificación de edad)
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AgeGateScreen(),
    ),

    // Sign In
    GoRoute(
      path: '/auth/signin',
      builder: (context, state) => const SignInScreen(),
    ),

    // Sign Up con parámetro DOB
    GoRoute(
      path: '/auth/signup',
      builder: (context, state) {
        final dob = state.extra as DateTime?;
        return SignUpScreen(dob: dob);
      },
    ),
  ],
);
