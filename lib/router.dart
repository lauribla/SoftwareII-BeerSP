import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'HomeScreen.dart';
import 'AuthGateScreen.dart';
import 'AgeGateScreen.dart';
import 'SignInScreen.dart';
import 'SignUpScreen.dart';
import 'CrearCerveza.dart';
import 'TopDegustaciones.dart';
import 'Galardones.dart';
import 'ActivityFeedScreen.dart';
import 'PerfilAjustes.dart';
import 'FriendsScreen.dart'; // 👈 nuevo import

final appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    // Home
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),

    // Pantalla inicial de autenticación
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthGateScreen(),
    ),

    // AgeGate → registro
    GoRoute(
      path: '/auth/agegate',
      builder: (context, state) => const AgeGateScreen(),
    ),

    // Sign In
    GoRoute(
      path: '/auth/signin',
      builder: (context, state) => const SignInScreen(),
    ),

    // Sign Up → requiere DOB
    GoRoute(
      path: '/auth/signup',
      builder: (context, state) {
        final dob = state.extra as DateTime;
        return SignUpScreen(dob: dob);
      },
    ),

    // Nueva degustación
    GoRoute(
      path: '/tastings/new',
      builder: (context, state) => const CrearCervezaScreen(),
    ),

    // Top degustaciones
    GoRoute(
      path: '/tastings/top',
      builder: (context, state) => const TopDegustacionesScreen(),
    ),

    // Perfil / Ajustes
    GoRoute(
      path: '/profile',
      builder: (context, state) => const PerfilAjustesScreen(),
    ),

    // Galardones
    GoRoute(
      path: '/badges',
      builder: (context, state) => const GalardonesScreen(),
    ),

    // Actividad
    GoRoute(
      path: '/activities',
      builder: (context, state) => const ActivityFeedScreen(),
    ),

    // 👥 Amigos
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
  ],
);
