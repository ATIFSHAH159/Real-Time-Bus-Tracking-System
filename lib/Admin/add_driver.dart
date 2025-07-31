import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/bus_model.dart';
import '../Services/bus_service.dart';
import '../theme/app_colors.dart';
import '../Services/notification_services.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddDriver extends StatefulWidget {
  const AddDriver({super.key});

  @override
  _AddDriverState createState() => _AddDriverState();
}

class _AddDriverState extends State<AddDriver> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Optional driver controllers
  final TextEditingController _optionalIdController = TextEditingController();
  final TextEditingController _optionalNameController = TextEditingController();
  final TextEditingController _optionalPhoneController = TextEditingController();
  final TextEditingController _optionalAddressController = TextEditingController();
  final TextEditingController _optionalEmailController = TextEditingController();
  final TextEditingController _optionalPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BusService _busService = BusService();
  final ImagePicker _picker = ImagePicker();

  String? _selectedBusId;
  bool _isLoading = false;
  List<BusModel> _availableBuses = [];
  File? _selectedImage;
  String? _imageUrl;
  bool _isOptionalDriver = false;
  File? _optionalSelectedImage;
  String? _optionalImageUrl;
  Uint8List? _selectedImageBytes;
  Uint8List? _optionalSelectedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot busesSnapshot = await FirebaseFirestore.instance.collection('buses').get();
      
      // Filter out buses that are already assigned to drivers
      _availableBuses = busesSnapshot.docs
          .map((doc) => BusModel.fromJson(doc.data() as Map<String, dynamic>))
          .where((bus) => 
              // Only include buses that have no primary or optional driver assigned
              bus.primaryDriverId == null && bus.optionalDriverId == null
          )
          .toList();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading buses: ${e.toString()}")),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          if (kIsWeb) {
            pickedFile.readAsBytes().then((value) {
              _selectedImageBytes = value;
              _selectedImage = null; // Not used on web
            });
          } else {
            _selectedImage = File(pickedFile.path);
            _selectedImageBytes = null;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: ${e.toString()}")),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      String fileName = 'driver_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child(fileName);
      
      UploadTask uploadTask = storageRef.putFile(_selectedImage!);
      TaskSnapshot taskSnapshot = await uploadTask;
      
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading image: ${e.toString()}")),
      );
      return null;
    }
  }

  Future<void> _addDriver() async {
    // Validate primary driver fields
    bool isImagePicked = kIsWeb ? _selectedImageBytes != null : _selectedImage != null;

    if (_idController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedBusId == null ||
        !isImagePicked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all primary driver fields and add a photo!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate optional driver fields if toggle is enabled
    if (_isOptionalDriver) {
      bool isOptionalImagePicked = kIsWeb ? _optionalSelectedImageBytes != null : _optionalSelectedImage != null;
      if (_optionalIdController.text.isEmpty ||
          _optionalNameController.text.isEmpty ||
          _optionalPhoneController.text.isEmpty ||
          _optionalAddressController.text.isEmpty ||
          _optionalEmailController.text.isEmpty ||
          _optionalPasswordController.text.isEmpty ||
          !isOptionalImagePicked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please fill all optional driver fields and add a photo!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Email validation for both drivers
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim()) ||
        (_isOptionalDriver && !emailRegex.hasMatch(_optionalEmailController.text.trim()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid email addresses!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Password validation for both drivers
    bool isPrimaryPasswordValid = _validatePassword(_passwordController.text);
    bool isOptionalPasswordValid = !_isOptionalDriver || _validatePassword(_optionalPasswordController.text);

    if (!isPrimaryPasswordValid || !isOptionalPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password must:\n"
            "• Be at least 8 characters long\n"
            "• Contain at least one uppercase letter\n"
            "• Contain at least one lowercase letter\n"
            "• Contain at least one number\n"
            "• Contain at least one special character (!@#\$&*)",
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Phone number validation for both drivers
    if (!RegExp(r'^\d{10,15}$').hasMatch(_phoneController.text.trim()) ||
        (_isOptionalDriver && !RegExp(r'^\d{10,15}$').hasMatch(_optionalPhoneController.text.trim()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid phone numbers (10-15 digits)!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Name validation (only letters and spaces)
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(_nameController.text.trim()) ||
        (_isOptionalDriver && !RegExp(r'^[a-zA-Z\s]+$').hasMatch(_optionalNameController.text.trim()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name should only contain letters and spaces!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ID validation (alphanumeric)
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(_idController.text.trim()) ||
        (_isOptionalDriver && !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(_optionalIdController.text.trim()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ID should only contain letters and numbers!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Address validation (minimum length)
    if (_addressController.text.trim().length < 5 ||
        (_isOptionalDriver && _optionalAddressController.text.trim().length < 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid address (minimum 5 characters)!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload images if selected
      if (_selectedImage != null) {
        _imageUrl = await _uploadImage();
        if (_imageUrl == null) {
          throw Exception("Failed to upload primary driver image");
        }
      }
      if (_isOptionalDriver && _optionalSelectedImage != null) {
        _optionalImageUrl = await _uploadOptionalImage();
        if (_optionalImageUrl == null) {
          throw Exception("Failed to upload optional driver image");
        }
      }

      // Get selected bus details
      BusModel? selectedBus = _availableBuses.firstWhere((bus) => bus.id == _selectedBusId);

      // Create primary driver account
      UserCredential primaryUserCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String primaryUserId = primaryUserCredential.user!.uid;

      // Create optional driver account if enabled
      String? optionalUserId;
      if (_isOptionalDriver) {
        UserCredential optionalUserCredential = await _auth.createUserWithEmailAndPassword(
          email: _optionalEmailController.text.trim(),
          password: _optionalPasswordController.text.trim(),
        );
        optionalUserId = optionalUserCredential.user!.uid;
      }

      // Save primary driver data
      await _firestore.collection('drivers').doc(primaryUserId).set({
        'id': _idController.text.trim(),
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'email': _emailController.text.trim(),   
        'uid': primaryUserId,
        'busId': _selectedBusId,
        'busNumberPlate': selectedBus.numberPlate,
        'busSource': selectedBus.source,
        'busDestination': selectedBus.destination,
        'imageUrl': _imageUrl,
        'isPrimary': true,
        'optionalDriverId': optionalUserId,
      });

      // Save optional driver data if enabled
      if (_isOptionalDriver && optionalUserId != null) {
        await _firestore.collection('drivers').doc(optionalUserId).set({
          'id': _optionalIdController.text.trim(),
          'name': _optionalNameController.text.trim(),
          'phone': _optionalPhoneController.text.trim(),
          'address': _optionalAddressController.text.trim(),
          'email': _optionalEmailController.text.trim(),   
          'uid': optionalUserId,
          'busId': _selectedBusId,
          'busNumberPlate': selectedBus.numberPlate,
          'busSource': selectedBus.source,
          'busDestination': selectedBus.destination,
          'imageUrl': _optionalImageUrl,
          'isPrimary': false,
          'primaryDriverId': primaryUserId,
        });

        // Save FCM token for optional driver
        String optionalToken = await NotificationServices().getDeviceToken();
        await NotificationServices().saveDeviceTokenToDatabase(optionalToken, optionalUserId, 'drivers');
      }
      
      // Save FCM token for primary driver
      String primaryToken = await NotificationServices().getDeviceToken();
      await NotificationServices().saveDeviceTokenToDatabase(primaryToken, primaryUserId, 'drivers');
      
      // Update the bus document with both driver IDs
      if (_selectedBusId != null) {
        await _firestore.collection('buses').doc(_selectedBusId).update({
          'primaryDriverId': primaryUserId,
          'optionalDriverId': optionalUserId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver(s) added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred";
      if (e.code == 'email-already-in-use') {
        message = "Email is already in use!";
      } else if (e.code == 'weak-password') {
        message = "Password should be at least 6 characters!";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<String?> _uploadOptionalImage() async {
    if (_optionalSelectedImage == null) return null;

    try {
      String fileName = 'driver_images/${DateTime.now().millisecondsSinceEpoch}_optional.jpg';
      Reference storageRef = _storage.ref().child(fileName);
      
      UploadTask uploadTask = storageRef.putFile(_optionalSelectedImage!);
      TaskSnapshot taskSnapshot = await uploadTask;
      
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading optional driver image: ${e.toString()}")),
      );
      return null;
    }
  }

  Future<void> _pickOptionalImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          if (kIsWeb) {
            pickedFile.readAsBytes().then((value) {
              _optionalSelectedImageBytes = value;
              _optionalSelectedImage = null; // Not used on web
            });
          } else {
            _optionalSelectedImage = File(pickedFile.path);
            _optionalSelectedImageBytes = null;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking optional driver image: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Driver'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: SafeArea(
          child: _isLoading && _availableBuses.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Optional Driver Toggle
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        color: Colors.white.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Add Optional Driver',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Switch(
                                value: _isOptionalDriver,
                                onChanged: (value) {
                                  setState(() {
                                    _isOptionalDriver = value;
                                  });
                                },
                                activeColor: AppColors.primary,
                                activeTrackColor: AppColors.primary.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Primary Driver Details Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        color: Colors.white.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Primary Driver Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Add Image Upload Widget
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 150,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(75),
                                        border: Border.all(
                                          color: AppColors.primary,
                                          width: 2,
                                        ),
                                      ),
                                      child: kIsWeb
                                          ? (_selectedImageBytes != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(75),
                                                  child: Image.memory(
                                                    _selectedImageBytes!,
                                                    width: 150,
                                                    height: 150,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.person,
                                                  size: 80,
                                                  color: Colors.grey[400],
                                                ))
                                          : (_selectedImage != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(75),
                                                  child: Image.file(
                                                    _selectedImage!,
                                                    width: 150,
                                                    height: 150,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.person,
                                                  size: 80,
                                                  color: Colors.grey[400],
                                                )),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.add_a_photo, color: Colors.white),
                                      label: const Text('Add Photo'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _idController,
                                'Unique ID',
                                Icons.badge,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _nameController,
                                'Name',
                                Icons.person,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _phoneController,
                                'Phone',
                                Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _addressController,
                                'Address',
                                Icons.location_on,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _emailController,
                                'Email',
                                Icons.email,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _passwordController,
                                'Password',
                                Icons.lock,
                                obscureText: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Driver Details Card
                      if (_isOptionalDriver)
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          color: Colors.white.withOpacity(0.95),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Optional Driver Details',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Add Image Upload Widget for Optional Driver
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(75),
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: kIsWeb
                                            ? (_optionalSelectedImageBytes != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(75),
                                                    child: Image.memory(
                                                      _optionalSelectedImageBytes!,
                                                      width: 150,
                                                      height: 150,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: Colors.grey[400],
                                                  ))
                                            : (_optionalSelectedImage != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(75),
                                                    child: Image.file(
                                                      _optionalSelectedImage!,
                                                      width: 150,
                                                      height: 150,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: Colors.grey[400],
                                                  )),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _pickOptionalImage,
                                        icon: const Icon(Icons.add_a_photo),
                                        label: const Text('Add Photo'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  _optionalIdController,
                                  'Unique ID',
                                  Icons.badge,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  _optionalNameController,
                                  'Name',
                                  Icons.person,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  _optionalPhoneController,
                                  'Phone',
                                  Icons.phone,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  _optionalAddressController,
                                  'Address',
                                  Icons.location_on,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  _optionalEmailController,
                                  'Email',
                                  Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  _optionalPasswordController,
                                  'Password',
                                  Icons.lock,
                                  obscureText: true,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bus Selection Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        color: Colors.white.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assign Bus',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              if (_availableBuses.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.shade700),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'No buses available! Please add buses first.',
                                          style: TextStyle(color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Select Bus',
                                    labelStyle: TextStyle(color: AppColors.primary),
                                    prefixIcon: Icon(Icons.directions_bus, color: AppColors.primary),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppColors.primary),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  value: _selectedBusId,
                                  items: _availableBuses.map((bus) {
                                    return DropdownMenuItem<String>(
                                      value: bus.id,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 40,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bus.numberPlate ?? 'No Plate',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '${bus.source ?? 'No Source'} → ${bus.destination ?? 'No Destination'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBusId = value;
                                    });
                                  },
                                  dropdownColor: Colors.white,
                                  isExpanded: true,
                                  style: TextStyle(color: AppColors.primary),
                                  selectedItemBuilder: (BuildContext context) {
                                    return _availableBuses.map<Widget>((BusModel bus) {
                                      return Container(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${bus.numberPlate} (${bus.source} → ${bus.destination})',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addDriver,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Add Driver',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.primary),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5)),
        ),
      ),
    );
  }

  bool _validatePassword(String password) {
    // Check minimum length
    if (password.length < 8) return false;

    // Check for uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;

    // Check for lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) return false;

    // Check for number
    if (!password.contains(RegExp(r'[0-9]'))) return false;

    // Check for special character
    if (!password.contains(RegExp(r'[!@#$&*]'))) return false;

    return true;
  }
}
