import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../Auth/login_page.dart';

class DriverProfile extends StatefulWidget {
  const DriverProfile({super.key});

  @override
  _DriverProfileState createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchDriverDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        String? imageUrl = _driverData?['imageUrl'];

        // Upload new image if selected
        if (_selectedImage != null) {
          final storageRef = _storage.ref()
              .child('driver_profiles')
              .child('${user.uid}.jpg');
          
          await storageRef.putFile(_selectedImage!);
          imageUrl = await storageRef.getDownloadURL();
        }

        // Update user data in Firestore
        await _firestore.collection('drivers').doc(user.uid).update({
          'name': _nameController.text.trim(),
          if (imageUrl != null) 'imageUrl': imageUrl,
        });

        setState(() {
          _driverData = {
            ..._driverData!,
            'name': _nameController.text.trim(),
            if (imageUrl != null) 'imageUrl': imageUrl,
          };
          _isEditing = false;
          _selectedImage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _fetchDriverDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot driverDoc =
          await _firestore.collection("drivers").doc(user.uid).get();
      if (driverDoc.exists) {
        setState(() {
          _driverData = driverDoc.data() as Map<String, dynamic>?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getInitials() {
    if (_driverData == null || _driverData!['name'] == null) return 'D';
    
    List<String> nameParts = (_driverData!['name'] as String).split(' ');
    if (nameParts.isEmpty) return 'D';
    if (nameParts.length == 1) return nameParts[0][0];
    return nameParts[0][0] + nameParts[1][0];
  }

  void _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _driverData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text(
                        "Profile Not Found",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchDriverDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header with gradient background
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                // Profile Avatar with Edit Button
                                Stack(
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            spreadRadius: 2,
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: _selectedImage != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(60),
                                              child: Image.file(
                                                _selectedImage!,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : _driverData?['imageUrl'] != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(60),
                                                  child: Image.network(
                                                    _driverData!['imageUrl'],
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        color: Colors.white,
                                                        child: Center(
                                                          child: Text(
                                                            _getInitials(),
                                                            style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Center(
                                                  child: Text(
                                                    _getInitials(),
                                                    style: TextStyle(
                                                      fontSize: 40,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                    ),
                                    if (_isEditing)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: _pickImage,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Driver Name with Edit Option
                                if (_isEditing)
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _nameController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Enter your name',
                                        hintStyle: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isEditing = true;
                                        _nameController.text = _driverData?['name'] ?? '';
                                      });
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _driverData?['name'] ?? "Driver",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.edit,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Driver ID badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "ID: ${_driverData?['driverId'] ?? 'N/A'}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Edit/Save Button
                                ElevatedButton.icon(
                                  onPressed: _isUpdating
                                      ? null
                                      : _isEditing
                                          ? _updateProfile
                                          : () {
                                              setState(() {
                                                _isEditing = true;
                                                _nameController.text = _driverData?['name'] ?? '';
                                              });
                                            },
                                  icon: Icon(
                                    _isEditing ? Icons.save : Icons.edit,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    _isUpdating
                                        ? 'Updating...'
                                        : _isEditing
                                            ? 'Save Changes'
                                            : 'Edit Profile',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isEditing ? AppColors.success : AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Personal Information Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Personal Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Info Cards
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  _buildProfileListTile(
                                    Icons.person_outline_rounded,
                                    "Full Name",
                                    _driverData?['name'] ?? "N/A",
                                  ),
                                  const Divider(height: 1),
                                  _buildProfileListTile(
                                    Icons.email_outlined,
                                    "Email Address",
                                    _driverData?['email'] ?? "N/A",
                                  ),
                                  const Divider(height: 1),
                                  _buildProfileListTile(
                                    Icons.badge_outlined,
                                    "Driver ID",
                                    _driverData?['driverId'] ?? "N/A",
                                  ),
                                  const Divider(height: 1),
                                  _buildProfileListTile(
                                    Icons.phone_outlined,
                                    "Phone Number",
                                    _driverData?['phone'] ?? "N/A",
                                  ),
                                  if (_driverData?['address'] != null) ...[
                                    const Divider(height: 1),
                                    _buildProfileListTile(
                                      Icons.home_outlined,
                                      "Address",
                                      _driverData?['address'] ?? "N/A",
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Account Section
                            Text(
                              "Account",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Account Card
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.history, color: AppColors.primary),
                                    ),
                                    title: const Text("Trip History"),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      // Navigate to trip history screen
                                    },
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.lock_outline, color: AppColors.primary),
                                    ),
                                    title: const Text("Change Password"),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      // Navigate to change password screen
                                    },
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.settings_outlined, color: AppColors.primary),
                                    ),
                                    title: const Text("Settings"),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      // Navigate to settings screen
                                    },
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.logout, color: AppColors.error),
                                    ),
                                    title: Text(
                                      "Logout",
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                    trailing: Icon(Icons.chevron_right, color: AppColors.error),
                                    onTap: _logout,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileListTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 