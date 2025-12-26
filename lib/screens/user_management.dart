import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:cloud_functions/cloud_functions.dart';
import '../shared/davao_del_norte_locations.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({super.key});

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _selectedUserId;

  // Cache for filtered users
  List<Map<String, dynamic>>? _cachedFilteredUsers;
  String _lastSearchQuery = '';
  String _lastFilter = '';

  // Debounce timer for search
  Timer? _searchDebounce;

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildLoadingDialog(String message) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await UserStore.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
        // Clear cache when loading new data
        _cachedFilteredUsers = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateExpertDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateExpertDialog(),
    ).then((success) {
      // Reload users after dialog closes (only if account was created successfully)
      if (success == true) {
        _loadUsers();
      }
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    // Use cached result if search query and filter haven't changed
    if (_cachedFilteredUsers != null &&
        _lastSearchQuery == _searchQuery &&
        _lastFilter == _selectedFilter) {
      return _cachedFilteredUsers!;
    }

    // Update cache markers
    _lastSearchQuery = _searchQuery;
    _lastFilter = _selectedFilter;

    // Perform filtering
    final filtered =
        _users.where((user) {
            final query = _searchQuery.toLowerCase();
            final matchesSearch =
                user['name'].toLowerCase().contains(query) ||
                user['email'].toLowerCase().contains(query) ||
                user['role'].toLowerCase().contains(query);

            // Handle different filter types
            bool matchesFilter = false;
            if (_selectedFilter == 'All') {
              matchesFilter = true;
            } else if (_selectedFilter == 'Active') {
              // Filter by status
              matchesFilter =
                  user['status'].toLowerCase() == _selectedFilter.toLowerCase();
            } else if (_selectedFilter == 'Expert' ||
                _selectedFilter == 'Farmer' ||
                _selectedFilter == 'Machine Learning Expert' ||
                _selectedFilter == 'Head Veterinarian') {
              // Filter by role
              final filterRole = _selectedFilter.toLowerCase().replaceAll(
                ' ',
                '_',
              );
              matchesFilter = user['role'].toLowerCase() == filterRole;
            }

            return matchesSearch && matchesFilter;
          }).toList()
          ..sort((a, b) => a['name'].compareTo(b['name']));

    // Cache the result
    _cachedFilteredUsers = filtered;
    return filtered;
  }

  void _showViewDialog(Map<String, dynamic> user) {
    final String profileImageUrl =
        (user['profileImage'] as String? ?? '').trim();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 60,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'View User Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 12),
                      // Profile Image
                      Center(
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage:
                              profileImageUrl.isNotEmpty
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                          child:
                              profileImageUrl.isEmpty
                                  ? const Icon(Icons.person, size: 35)
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // User Details (Read-only)
                      _buildReadOnlyField('Name', user['name'] ?? '—'),
                      const SizedBox(height: 8),
                      _buildReadOnlyField('Email', user['email'] ?? '—'),
                      const SizedBox(height: 8),
                      _buildReadOnlyField('Phone Number', user['phone'] ?? '—'),
                      const SizedBox(height: 8),
                      _buildReadOnlyField('Address', user['address'] ?? '—'),
                      const SizedBox(height: 8),
                      _buildReadOnlyField(
                        'Role',
                        _formatRoleName(user['role'] ?? '—'),
                      ),
                      const SizedBox(height: 8),
                      _buildReadOnlyField('Status', user['status'] ?? '—'),
                      const SizedBox(height: 8),
                      _buildReadOnlyField(
                        'Registered',
                        user['registeredAt'] ?? '—',
                      ),
                      const SizedBox(height: 8),
                      _buildReadOnlyField(
                        'Accepted',
                        user['acceptedAt'] ?? '—',
                      ),
                      const SizedBox(height: 16),
                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D7204),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  void _showEditDialog(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    final addressController = TextEditingController(
      text: user['address'] ?? '',
    );
    final formKey = GlobalKey<FormState>();
    String selectedRole = user['role'];
    final String profileImageUrl =
        (user['profileImage'] as String? ?? '').trim();
    final String currentUserId = user['id'] ?? '';

    // Create a list of all possible roles, including the current user's role
    // Note: 'farmer' is excluded as farmers cannot be edited
    final allRoles = ['expert', 'machine_learning_expert', 'head_veterinarian'];
    // Add current role if it's not in the list (but exclude 'farmer')
    if (!allRoles.contains(selectedRole) &&
        selectedRole.toLowerCase() != 'farmer') {
      allRoles.add(selectedRole);
    }

    // Check if a head veterinarian already exists (excluding current user)
    final users = await UserStore.getUsers();
    final hasOtherHeadVet = users.any(
      (u) =>
          (u['role'] as String).toLowerCase() == 'head_veterinarian' &&
          (u['id'] as String) != currentUserId,
    );

    // Remove head_veterinarian from dropdown if one already exists and current user is not the head vet
    if (hasOtherHeadVet && selectedRole.toLowerCase() != 'head_veterinarian') {
      allRoles.remove('head_veterinarian');
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap:
                                  profileImageUrl.isNotEmpty
                                      ? () => _showImagePreview(profileImageUrl)
                                      : null,
                              child: Tooltip(
                                message:
                                    profileImageUrl.isNotEmpty
                                        ? 'Click to enlarge'
                                        : 'No profile photo',
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage:
                                      profileImageUrl.isNotEmpty
                                          ? NetworkImage(profileImageUrl)
                                              as ImageProvider<Object>?
                                          : null,
                                  child:
                                      profileImageUrl.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            color: Colors.grey,
                                          )
                                          : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit User',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    user['name'],
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Form(
                        key: formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                hintText: 'Enter full name',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Name is required'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'name@example.com',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) return 'Email is required';
                                final emailRegex = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                );
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '09123456789 or +639123456789',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                                helperText: 'Philippine mobile number format',
                              ),
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) {
                                  return 'Phone number is required';
                                }

                                // Remove any spaces or dashes
                                final cleanedValue = value.replaceAll(
                                  RegExp(r'[\s\-]'),
                                  '',
                                );

                                // Check if contains only numbers, + and spaces/dashes
                                if (!RegExp(r'^[\d\+\s\-]+$').hasMatch(value)) {
                                  return 'Phone number can only contain numbers';
                                }

                                // Philippine phone number formats:
                                // 09XXXXXXXXX (11 digits starting with 09)
                                // +639XXXXXXXXX (13 characters starting with +639)
                                // 639XXXXXXXXX (12 digits starting with 639)

                                if (cleanedValue.startsWith('+639')) {
                                  if (cleanedValue.length != 13) {
                                    return 'Format: +639XXXXXXXXX (13 digits)';
                                  }
                                } else if (cleanedValue.startsWith('639')) {
                                  if (cleanedValue.length != 12) {
                                    return 'Format: 639XXXXXXXXX (12 digits)';
                                  }
                                } else if (cleanedValue.startsWith('09')) {
                                  if (cleanedValue.length != 11) {
                                    return 'Format: 09XXXXXXXXX (11 digits)';
                                  }
                                } else {
                                  return 'Must start with 09, 639, or +639';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: addressController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                                hintText: 'Street, City, etc.',
                                prefixIcon: Icon(Icons.home_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                                prefixIcon: Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  allRoles
                                      .map(
                                        (role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(_formatRoleName(role)),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) => selectedRole = value!,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }

                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('Confirm changes'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Name: ' + nameController.text.trim(),
                                        ),
                                        Text(
                                          'Email: ' +
                                              emailController.text.trim(),
                                        ),
                                        if (phoneController.text
                                            .trim()
                                            .isNotEmpty)
                                          Text(
                                            'Phone: ' +
                                                phoneController.text.trim(),
                                          ),
                                        if (addressController.text
                                            .trim()
                                            .isNotEmpty)
                                          Text(
                                            'Address: ' +
                                                addressController.text.trim(),
                                          ),
                                        Text(
                                          'Role: ' +
                                              _formatRoleName(selectedRole),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(true),
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirm != true) return;

                            // Capture context and user info before async operations
                            final dialogContext = context;
                            final userName = user['name'] as String;
                            final userId = user['id'] as String;
                            final nameValue = nameController.text.trim();
                            final emailValue = emailController.text.trim();
                            final phoneValue = phoneController.text.trim();
                            final addressValue = addressController.text.trim();

                            // Show loading dialog
                            showDialog(
                              context: dialogContext,
                              barrierDismissible: false,
                              builder:
                                  (ctx) => _buildLoadingDialog('Saving...'),
                            );

                            try {
                              final success =
                                  await UserStore.updateUser(userId, {
                                    'name': nameValue,
                                    'email': emailValue,
                                    'phone': phoneValue,
                                    'address': addressValue,
                                    'role': selectedRole,
                                  });

                              // Close loading dialog
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.of(dialogContext).pop();
                              }

                              // Close edit dialog
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.of(dialogContext).pop();
                              }

                              if (success) {
                                // Log activity (don't await before showing dialog)
                                cf.FirebaseFirestore.instance
                                    .collection('activities')
                                    .add({
                                      'action': 'Updated user data',
                                      'user': nameValue,
                                      'type': 'update',
                                      'color': Colors.blue.value,
                                      'icon': Icons.edit.codePoint,
                                      'timestamp':
                                          cf.FieldValue.serverTimestamp(),
                                    });

                                // Show success dialog BEFORE reloading users
                                if (mounted) {
                                  await showDialog(
                                    context: dialogContext,
                                    barrierDismissible: false,
                                    builder:
                                        (ctx) => AlertDialog(
                                          title: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 28,
                                              ),
                                              SizedBox(width: 12),
                                              Text('Success'),
                                            ],
                                          ),
                                          content: Text(
                                            '$userName has been updated successfully!',
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              onPressed:
                                                  () => Navigator.of(ctx).pop(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                  );
                                }

                                // Reload users AFTER dialog is dismissed
                                _loadUsers();
                              } else {
                                // Show error dialog
                                if (mounted) {
                                  showDialog(
                                    context: dialogContext,
                                    builder:
                                        (ctx) => AlertDialog(
                                          title: Row(
                                            children: [
                                              Icon(
                                                Icons.error,
                                                color: Colors.red,
                                                size: 28,
                                              ),
                                              SizedBox(width: 12),
                                              Text('Error'),
                                            ],
                                          ),
                                          content: const Text(
                                            'Failed to update user. Please try again.',
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              onPressed:
                                                  () => Navigator.of(ctx).pop(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                  );
                                }
                              }
                            } catch (e) {
                              // Close any open dialogs
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.of(dialogContext).pop();
                              }

                              // Show error dialog
                              if (mounted) {
                                showDialog(
                                  context: dialogContext,
                                  builder:
                                      (ctx) => AlertDialog(
                                        title: Row(
                                          children: [
                                            Icon(
                                              Icons.error,
                                              color: Colors.red,
                                              size: 28,
                                            ),
                                            SizedBox(width: 12),
                                            Text('Error'),
                                          ],
                                        ),
                                        content: Text(
                                          'Error updating user: $e',
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            onPressed:
                                                () => Navigator.of(ctx).pop(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                );
                              }
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showCreateExpertDialog(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Create Expert Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D7204),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _loadUsers,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search... (name, email, or role)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    // Cancel previous timer
                    if (_searchDebounce?.isActive ?? false) {
                      _searchDebounce!.cancel();
                    }
                    // Start new timer
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        setState(() {
                          _searchQuery = value;
                          _cachedFilteredUsers = null;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedFilter,
                items:
                    [
                          'All',
                          'Active',
                          'Expert',
                          'Farmer',
                          'Machine Learning Expert',
                          'Head Veterinarian',
                        ]
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value ?? 'All';
                    _cachedFilteredUsers = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                // Control the ripple/splash animation duration
                                splashFactory: InkRipple.splashFactory,
                              ),
                              child: DataTable(
                                showCheckboxColumn: false,
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Phone Number')),
                                  DataColumn(label: Text('Address')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Registered')),
                                  DataColumn(label: Text('Accepted')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows:
                                    _filteredUsers
                                        .map(
                                          (user) => DataRow(
                                            selected:
                                                _selectedUserId == user['id'],
                                            onSelectChanged: (selected) {
                                              setState(() {
                                                _selectedUserId =
                                                    _selectedUserId ==
                                                            user['id']
                                                        ? null
                                                        : user['id'];
                                              });
                                            },
                                            color:
                                                WidgetStateProperty.resolveWith<
                                                  Color?
                                                >((states) {
                                                  if (states.contains(
                                                    WidgetState.selected,
                                                  )) {
                                                    return const Color(
                                                      0x2D2A9D32,
                                                    ); // brand green 18% opacity
                                                  }
                                                  if (states.contains(
                                                    WidgetState.hovered,
                                                  )) {
                                                    return const Color(
                                                      0x142A9D32,
                                                    ); // brand green 8% opacity
                                                  }
                                                  return null;
                                                }),
                                            cells: [
                                              DataCell(
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor:
                                                          Colors.grey.shade200,
                                                      backgroundImage:
                                                          (user['profileImage'] !=
                                                                      null &&
                                                                  (user['profileImage']
                                                                          as String)
                                                                      .trim()
                                                                      .isNotEmpty)
                                                              ? NetworkImage(
                                                                    (user['profileImage']
                                                                            as String)
                                                                        .trim(),
                                                                  )
                                                                  as ImageProvider<
                                                                    Object
                                                                  >?
                                                              : null,
                                                      child:
                                                          (user['profileImage'] ==
                                                                      null ||
                                                                  (user['profileImage']
                                                                          as String)
                                                                      .trim()
                                                                      .isEmpty)
                                                              ? const Icon(
                                                                Icons.person,
                                                                size: 16,
                                                                color:
                                                                    Colors.grey,
                                                              )
                                                              : null,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(user['name']),
                                                  ],
                                                ),
                                              ),
                                              DataCell(Text(user['email'])),
                                              DataCell(
                                                Text(user['phone'] ?? ''),
                                              ),
                                              DataCell(
                                                Text(user['address'] ?? ''),
                                              ),
                                              DataCell(
                                                Text(
                                                  user['status'].toUpperCase(),
                                                  style: TextStyle(
                                                    color: _getStatusColor(
                                                      user['status'],
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  _formatRoleName(user['role']),
                                                  style: TextStyle(
                                                    color: _getRoleColor(
                                                      user['role'],
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(user['registeredAt']),
                                              ),
                                              DataCell(
                                                Text(user['acceptedAt'] ?? '—'),
                                              ),
                                              DataCell(
                                                Builder(
                                                  builder: (context) {
                                                    final userRole =
                                                        (user['role']
                                                                    as String? ??
                                                                '')
                                                            .toLowerCase();
                                                    final isExpert =
                                                        userRole == 'expert' ||
                                                        userRole ==
                                                            'head_veterinarian' ||
                                                        userRole ==
                                                            'machine_learning_expert';
                                                    final isFarmer =
                                                        userRole == 'farmer';

                                                    return Row(
                                                      children: [
                                                        if (isExpert)
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.edit,
                                                            ),
                                                            tooltip:
                                                                'Edit User',
                                                            onPressed:
                                                                () =>
                                                                    _showEditDialog(
                                                                      user,
                                                                    ),
                                                          ),
                                                        if (isFarmer)
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.visibility,
                                                            ),
                                                            tooltip:
                                                                'View User Details',
                                                            onPressed:
                                                                () =>
                                                                    _showViewDialog(
                                                                      user,
                                                                    ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Format role name for display (replace underscores with spaces, uppercase)
  String _formatRoleName(String role) {
    return role.replaceAll('_', ' ').toUpperCase();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'expert':
        return const Color.fromARGB(255, 31, 3, 133); // violet
      case 'farmer':
        return const Color.fromARGB(255, 255, 0, 0); // red
      case 'machine_learning_expert':
        return const Color(0xFF9C27B0); // purple
      case 'head_veterinarian':
        return const Color(0xFF2196F3); // blue
      default:
        return Colors.grey;
    }
  }
}

// Dialog for creating expert accounts
class CreateExpertDialog extends StatefulWidget {
  const CreateExpertDialog({Key? key}) : super(key: key);

  @override
  State<CreateExpertDialog> createState() => _CreateExpertDialogState();
}

class _CreateExpertDialogState extends State<CreateExpertDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();

  String? _selectedRole;
  String? _selectedProvinceName;
  String? _selectedCityName;
  String? _selectedCityCode;
  String? _selectedBarangayName;

  List<Map<String, String>> _cities = [];
  List<Map<String, String>> _barangays = [];

  bool _isLoading = false;
  bool _isLoadingLocations = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _checkingHeadVet = false;

  // Available roles for expert accounts
  final List<Map<String, String>> _availableRoles = [
    {'value': 'expert', 'label': 'Expert'},
    {'value': 'head_veterinarian', 'label': 'Head Veterinarian'},
    {'value': 'machine_learning_expert', 'label': 'Machine Learning Expert'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _checkExistingHeadVet();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      await DavaoDelNorteLocations.load();
      final province = DavaoDelNorteLocations.getProvince();
      if (province != null) {
        setState(() {
          _selectedProvinceName =
              province['name']?.toString() ?? 'Davao del Norte';
        });
        _loadCitiesForProvince();
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to load location data. Please ensure davao_del_norte_locations.json exists in assets.';
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _loadCitiesForProvince() async {
    setState(() {
      _cities = [];
      _barangays = [];
      _selectedCityCode = null;
      _selectedCityName = null;
      _selectedBarangayName = null;
    });

    final cities = DavaoDelNorteLocations.getCities();
    setState(() {
      _cities =
          cities
              .map<Map<String, String>>(
                (c) => {
                  'code': c['code']?.toString() ?? '',
                  'name': c['name']?.toString() ?? '',
                },
              )
              .toList();
      _isLoadingLocations = false;
    });
  }

  Future<void> _loadBarangaysForCity(String cityCode) async {
    setState(() {
      _barangays = [];
      _selectedBarangayName = null;
    });

    final barangays = DavaoDelNorteLocations.getBarangaysForCity(cityCode);
    setState(() {
      _barangays =
          barangays
              .map<Map<String, String>>(
                (b) => {
                  'code': b['code']?.toString() ?? '',
                  'name': b['name']?.toString() ?? '',
                },
              )
              .toList();
    });
  }

  Future<void> _checkExistingHeadVet() async {
    setState(() => _checkingHeadVet = true);
    try {
      final users = await UserStore.getUsers();
      final hasHeadVet = users.any(
        (user) => (user['role'] as String).toLowerCase() == 'head_veterinarian',
      );

      if (hasHeadVet && mounted) {
        // Remove head_veterinarian from available roles if one already exists
        setState(() {
          _availableRoles.removeWhere(
            (role) => role['value'] == 'head_veterinarian',
          );
        });
      }
    } catch (e) {
      // Error checking, but continue anyway
    } finally {
      if (mounted) {
        setState(() => _checkingHeadVet = false);
      }
    }
  }

  Future<void> _createExpertAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (_selectedRole == null) {
      setState(() {
        _errorMessage = 'Please select a role';
      });
      return;
    }

    if (_selectedCityName == null || _selectedBarangayName == null) {
      setState(() {
        _errorMessage = 'Please select city and barangay';
      });
      return;
    }

    // Double-check head vet limit
    if (_selectedRole == 'head_veterinarian') {
      final users = await UserStore.getUsers();
      final hasHeadVet = users.any(
        (user) => (user['role'] as String).toLowerCase() == 'head_veterinarian',
      );
      if (hasHeadVet) {
        setState(() {
          _errorMessage = 'Only one Head Veterinarian account is allowed';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Build address string
      final street = _streetController.text.trim();
      final address =
          street.isEmpty
              ? '$_selectedBarangayName, $_selectedCityName, $_selectedProvinceName'
              : '$street, $_selectedBarangayName, $_selectedCityName, $_selectedProvinceName';

      // Use Cloud Function to create user (prevents admin logout)
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createUserAccount');

      await callable.call({
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'fullName': _nameController.text.trim(),
        'role': _selectedRole,
        'phoneNumber': _phoneController.text.trim(),
        'street': street,
        'province': _selectedProvinceName ?? 'Davao del Norte',
        'cityMunicipality': _selectedCityName ?? '',
        'barangay': _selectedBarangayName ?? '',
        'address': address,
      });

      if (mounted) {
        Navigator.of(context).pop(true); // Pass true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_availableRoles.firstWhere((r) => r['value'] == _selectedRole)['label']} account created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      String errorMsg = 'Failed to create account';
      switch (e.code) {
        case 'already-exists':
          errorMsg = 'This email is already registered';
          break;
        case 'invalid-argument':
          errorMsg = e.message ?? 'Invalid input data';
          break;
        case 'permission-denied':
          errorMsg = 'You do not have permission to create users';
          break;
        default:
          errorMsg = e.message ?? 'Failed to create account';
      }
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
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
    _streetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7204),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_add, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Create Expert Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child:
                      _isLoadingLocations || _checkingHeadVet
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              // Name field
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name *',
                                  hintText: 'Enter expert full name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Name must be at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Email field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email *',
                                  hintText: 'Enter email address',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Phone Number field
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number *',
                                  hintText: '09123456789 or +639123456789',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Phone number is required';
                                  }
                                  // Remove any spaces or dashes
                                  final cleaned = value.replaceAll(
                                    RegExp(r'[\s\-]'),
                                    '',
                                  );
                                  // Check if it contains only numbers and optional + at start
                                  if (!RegExp(
                                    r'^\+?[0-9]+$',
                                  ).hasMatch(cleaned)) {
                                    return 'Phone number can only contain numbers';
                                  }
                                  // Check minimum length (at least 10 digits)
                                  final digitsOnly = cleaned.replaceAll(
                                    RegExp(r'\+'),
                                    '',
                                  );
                                  if (digitsOnly.length < 10) {
                                    return 'Phone number must be at least 10 digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Password field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password *',
                                  hintText: 'Enter password (min 6 characters)',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Confirm Password field
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password *',
                                  hintText: 'Re-enter password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Role selection
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Role *',
                                  prefixIcon: Icon(Icons.work_outline),
                                  border: OutlineInputBorder(),
                                ),
                                hint: const Text('Select role'),
                                items:
                                    _availableRoles.map((role) {
                                      return DropdownMenuItem<String>(
                                        value: role['value'],
                                        child: Text(role['label']!),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a role';
                                  }
                                  return null;
                                },
                              ),
                              if (_availableRoles.isEmpty ||
                                  !_availableRoles.any(
                                    (r) => r['value'] == 'head_veterinarian',
                                  )) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.orange[700],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Note: Only one Head Veterinarian account is allowed. One already exists.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              // Address section
                              const Text(
                                'Address Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Province (read-only, always Davao del Norte)
                              TextFormField(
                                initialValue:
                                    _selectedProvinceName ?? 'Davao del Norte',
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Province',
                                  prefixIcon: Icon(Icons.map_outlined),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // City/Municipality
                              DropdownButtonFormField<String>(
                                value: _selectedCityCode,
                                decoration: const InputDecoration(
                                  labelText: 'City/Municipality *',
                                  prefixIcon: Icon(Icons.location_city),
                                  border: OutlineInputBorder(),
                                ),
                                hint: const Text('Select city/municipality'),
                                items:
                                    _cities.map((city) {
                                      return DropdownMenuItem<String>(
                                        value: city['code'],
                                        child: Text(city['name']!),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCityCode = value;
                                    _selectedCityName =
                                        _cities.firstWhere(
                                          (c) => c['code'] == value,
                                        )['name'];
                                    _selectedBarangayName = null;
                                  });
                                  if (value != null) {
                                    _loadBarangaysForCity(value);
                                  }
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a city/municipality';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Barangay
                              DropdownButtonFormField<String>(
                                value: _selectedBarangayName,
                                decoration: const InputDecoration(
                                  labelText: 'Barangay *',
                                  prefixIcon: Icon(Icons.location_on),
                                  border: OutlineInputBorder(),
                                ),
                                hint: Text(
                                  _selectedCityCode == null
                                      ? 'Select city first'
                                      : 'Select barangay',
                                ),
                                items:
                                    _barangays.map((barangay) {
                                      return DropdownMenuItem<String>(
                                        value: barangay['name'],
                                        child: Text(barangay['name']!),
                                      );
                                    }).toList(),
                                onChanged:
                                    _selectedCityCode == null
                                        ? null
                                        : (value) {
                                          setState(() {
                                            _selectedBarangayName = value;
                                          });
                                        },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a barangay';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Street/Purok (optional)
                              TextFormField(
                                controller: _streetController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Street/Purok/House No. (Optional)',
                                  hintText:
                                      'Enter street, purok, or house number',
                                  prefixIcon: Icon(Icons.home_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed:
                                        _isLoading
                                            ? null
                                            : () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed:
                                        _isLoading
                                            ? null
                                            : _createExpertAccount,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2D7204),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    child:
                                        _isLoading
                                            ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : const Text('Create Account'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
