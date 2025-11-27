import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'HomeScreen.dart';
import 'AuthGateScreen.dart';
import 'AgeGateScreen.dart';
import 'SignInScreen.dart';
import 'SignUpScreen.dart';
import 'CrearDegustacionScreen.dart';
import 'CrearCervezaScreen.dart';
import 'CrearLocalScreen.dart';
import 'TopDegustaciones.dart';
import 'Galardones.dart';
import 'ActivityFeedScreen.dart';
import 'PerfilAjustes.dart';
import 'FriendsScreen.dart';
import 'BeerDetailScreen.dart';
import 'NotificacionesScreen.dart';
import 'DegustacionesAmigosScreen.dart';
import 'TastingDetailScreen.dart';

final appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    // Home principal
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),

    // Autenticación principal
    GoRoute(path: '/auth', builder: (context, state) => const AuthGateScreen()),

    // Verificación de edad
    GoRoute(
      path: '/auth/agegate',
      builder: (context, state) => const AgeGateScreen(),
    ),

    // Iniciar sesión
    GoRoute(
      path: '/auth/signin',
      builder: (context, state) => const SignInScreen(),
    ),

    // Registro (requiere fecha de nacimiento)
    GoRoute(
      path: '/auth/signup',
      builder: (context, state) {
        final dob = state.extra as DateTime;
        return SignUpScreen(dob: dob);
      },
    ),

    GoRoute(
  path: '/tastings/new',
  builder: (context, state) => const CrearDegustacionScreen(),
),

GoRoute(
  path: '/cerveza/new',
  builder: (context, state) => const CrearCervezaScreen(),
),

GoRoute(
  path: '/local/new',
  builder: (context, state) => const CrearLocalScreen(),
),

    //  Top degustaciones
    GoRoute(
      path: '/tastings/top',
      builder: (context, state) => const TopDegustacionesScreen(),
    ),

    // Perfil + Ajustes
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

    // Amigos
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),

    // Notificaciones
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificacionesScreen(),
    ),

    // Detalle de cerveza (con tastingId)
    GoRoute(
      path: '/beer/detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final beerId = extra['beerId'] as String;
        final tastingId = extra['tastingId'] as String;
        return BeerDetailScreen(beerId: beerId, tastingId: tastingId);
      },
    ),

    // Degustaciones de amigos
    GoRoute(
      path: '/degustaciones_amigos',
      builder: (context, state) => const DegustacionesAmigosScreen(),
    ),

    // Detalle de degustación
    GoRoute(
      path: '/tasting/detail',
      builder: (context, state) {
        final tastingId = state.extra as String;
        return TastingDetailScreen(tastingId: tastingId);
      },
    ),
  ],
);
