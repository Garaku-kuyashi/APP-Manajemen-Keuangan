import 'package:go_router/go_router.dart';

import 'pages/auth_page.dart';
import 'pages/email_verification_page.dart';

final authRoutes = <RouteBase>[
  GoRoute(path: '/login', builder: (_, _) => const AuthPage()),
  GoRoute(path: '/register', builder: (_, _) => const AuthPage(register: true)),
  GoRoute(
    path: '/verify-email',
    builder: (_, _) => const EmailVerificationPage(),
  ),
];
