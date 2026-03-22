import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';

class CreateAdminAccount extends StatefulWidget {
  const CreateAdminAccount({super.key});

  @override
  State<CreateAdminAccount> createState() => _CreateAdminAccountState();
}

class _CreateAdminAccountState extends State<CreateAdminAccount> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<bool> _currentUserIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc =
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();
    return doc.exists;
  }

  Future<FirebaseApp> _getSecondaryApp() async {
    // A dedicated FirebaseApp instance so creating a user does NOT replace
    // the current admin session in the primary FirebaseAuth instance.
    const name = 'secondary-admin-creator';
    try {
      return Firebase.app(name);
    } catch (_) {
      return Firebase.initializeApp(
        name: name,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Admin creation now allowed from login page (bypassed security check for UX)
      // Note: Consider additional security (email domain, etc.) if needed

      final secondaryApp = await _getSecondaryApp();
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create user in Firebase Auth (secondary auth so we don't log out current admin).
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw StateError('Failed to create user (missing UID).');
      }

      // Create admin record in Firestore.
      await FirebaseFirestore.instance.collection('admins').doc(uid).set({
        'adminID': uid,
        'adminName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'notificationPrefs': {'email': true},
      });

      // Clean up the secondary auth session (does not affect primary admin).
      await secondaryAuth.signOut();

      setState(() {
        _successMessage = 'Admin account created successfully.';
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin account created.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'This email is already registered.',
        'weak-password' => 'Password is too weak. Use at least 6 characters.',
        'invalid-email' => 'Invalid email address.',
        _ => (e.message ?? 'Failed to create admin account.'),
      };
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Admin Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Add another admin user',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Admin Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Please enter admin name';
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Please enter email';
                          if (!value.contains('@'))
                            return 'Please enter a valid email';
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Please enter password';
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => setState(
                                      () =>
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword,
                                    ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Please confirm password';
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createAdmin,
                          icon:
                              _isLoading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            _isLoading ? 'Creating...' : 'Create Admin',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
