import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/admin_login.dart';
import 'screens/admin_setup.dart';
import 'screens/create_admin_account.dart';
import 'screens/admin_dashboard.dart';
import 'screens/landing_page.dart';
import 'models/admin_user.dart';
import 'services/firebase_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if Firebase is already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Start Firebase connectivity monitoring
    FirebaseMonitor().startMonitoring();
    debugPrint('✅ Firebase initialized and monitoring started');
  } catch (e) {
    // If Firebase is already initialized, just continue
    debugPrint('Firebase already initialized: $e');
    // Still start monitoring
    FirebaseMonitor().startMonitoring();
  }

  if (kReleaseMode) {
    // Disable debugPrint in release to avoid any logging overhead
    debugPrint = (String? message, {int? wrapWidth}) {};
    runZonedGuarded(
      () {
        runApp(const MyApp());
      },
      (error, stackTrace) {
        // Optionally send errors to crash reporting in release
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) {
          // Suppress prints in release builds
        },
      ),
    );
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin Web',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login':
            (context) => AdminLogin(
              onBackToLanding:
                  () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false),
            ),
        '/setup': (context) => const AdminSetup(),
        '/create-admin': (context) => const CreateAdminAccount(),
      },
      initialRoute: '/',
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showLoginFlow = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in, check if they are an admin
          return FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('admins')
                    .doc(snapshot.data!.uid)
                    .get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                // User is an admin, create admin user object and show dashboard
                final adminData =
                    adminSnapshot.data!.data() as Map<String, dynamic>;
                final adminUser = AdminUser(
                  id: adminData['adminID'] ?? snapshot.data!.uid,
                  username: adminData['adminName'] ?? '',
                  email: adminData['email'] ?? snapshot.data!.email ?? '',
                  role: 'admin',
                  lastLogin: DateTime.now(),
                );
                return AdminDashboardWrapper(adminUser: adminUser);
              } else {
                // User is signed in but not an admin, sign them out
                FirebaseAuth.instance.signOut();
                return const AdminLogin();
              }
            },
          );
        }

        // User is not signed in: show landing first, then login/setup when they tap Login
        if (!_showLoginFlow) {
          return LandingPage(
            onLoginPressed: () => setState(() => _showLoginFlow = true),
          );
        }

        // User tapped Login on landing — check if any admins exist
        return FutureBuilder<QuerySnapshot>(
          future:
              FirebaseFirestore.instance.collection('admins').limit(1).get(),
          builder: (context, adminCheckSnapshot) {
            if (adminCheckSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (adminCheckSnapshot.hasData &&
                adminCheckSnapshot.data!.docs.isEmpty) {
              return const AdminSetup();
            }

            return AdminLogin(
              onBackToLanding: () => setState(() => _showLoginFlow = false),
            );
          },
        );
      },
    );
  }
}
// flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true
//flutter run -d chrome --profile --dart-define=FLUTTER_WEB_USE_SKIA=true