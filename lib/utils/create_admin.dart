import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Utility script to create the first admin account
/// Run this once to set up your initial admin user
/// 
/// Usage: Call createFirstAdmin() with email and password
Future<void> createFirstAdmin({
  required String email,
  required String password,
  required String adminName,
}) async {
  try {
    // Initialize Firebase if not already initialized
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Firebase may already be initialized
      print('Firebase already initialized or error: $e');
    }

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    print('Creating admin account...');
    print('Email: $email');
    print('Name: $adminName');

    // Step 1: Create the user in Firebase Authentication
    UserCredential userCredential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;
    print('✅ User created in Firebase Auth with UID: $uid');

    // Step 2: Create the admin document in Firestore
    await firestore.collection('admins').doc(uid).set({
      'adminID': uid,
      'adminName': adminName,
      'email': email,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'notificationPrefs': {
        'email': true, // Enable email notifications by default
      },
    });

    print('✅ Admin document created in Firestore');
    print('✅ Admin account setup complete!');
    print('\nYou can now login with:');
    print('  Email: $email');
    print('  Password: [your password]');

    // Sign out the user (they'll need to login through the app)
    await auth.signOut();
    print('\n✅ Signed out. Please login through the admin portal.');
  } catch (e) {
    print('❌ Error creating admin: $e');
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          print('This email is already registered. You can login directly.');
          break;
        case 'weak-password':
          print('Password is too weak. Please use a stronger password.');
          break;
        case 'invalid-email':
          print('Invalid email address.');
          break;
        default:
          print('Auth error: ${e.message}');
      }
    }
    rethrow;
  }
}

