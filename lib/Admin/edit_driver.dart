import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/bus_model.dart';
import '../models/driver_model.dart';
import '../Services/driver_service.dart';
import '../Services/bus_service.dart';
import '../theme/app_colors.dart';

class EditDriver extends StatefulWidget {
  final String driverId;

  const EditDriver({super.key, required this.driverId});

  @override
  _EditDriverState createState() => _EditDriverState();
}

class _EditDriverState extends State<EditDriver> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final DriverService _driverService = DriverService();
  final BusService _busService = BusService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedBusId;
  List<BusModel> _availableBuses = [];
  DriverModel? _driver;
  File? _selectedImage;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadDriverAndBuses();
  }

  Future<void> _loadDriverAndBuses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load driver details
      _driver = await _driverService.getDriver(widget.driverId);
      
      if (_driver != null) {
        // Set the text controllers with driver data
        _idController.text = _driver!.id ?? '';
        _nameController.text = _driver!.name ?? '';
        _phoneController.text = _driver!.phone ?? '';
        _addressController.text = _driver!.address ?? '';
        _emailController.text = _driver!.email ?? '';
        _imageUrl = _driver!.imageUrl;
        
        // Set selected bus
        _selectedBusId = _driver!.busId;
      }

      // Load available buses
      QuerySnapshot busesSnapshot = await FirebaseFirestore.instance.collection('buses').get();
      
      // Create map to ensure unique bus IDs
      Map<String, BusModel> busMap = {};
      for (var doc in busesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Use document ID if bus ID is missing
        String busId = data['id'] ?? doc.id;
        data['id'] = busId; // Ensure ID is set
        
        BusModel bus = BusModel.fromJson(data);
        // Only include unassigned buses or the bus currently assigned to this driver
        if (bus.driverId == null || bus.driverId == _driver?.uid) {
          busMap[busId] = bus;
        }
      }
      
      _availableBuses = busMap.values.toList();
      
      // Validate selected bus ID
      if (_selectedBusId != null) {
        bool busExists = _availableBuses.any((bus) => bus.id == _selectedBusId);
        if (!busExists && _availableBuses.isNotEmpty) {
          // If selected bus doesn't exist in the list, reset to first bus
          _selectedBusId = _availableBuses.first.id;
        } else if (!busExists) {
          // If no buses available, clear selection
          _selectedBusId = null;
        }
      }
      
    } catch (e) {
      print("Error loading data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading data: $e")),
      );
    } finally {
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
          _selectedImage = File(pickedFile.path);
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

  Future<void> _updateDriver() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _idController.text.isEmpty ||
        _selectedBusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    // Phone number validation
    if (!RegExp(r'^\d{10,15}$').hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number (10-15 digits)")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload new image if selected
      if (_selectedImage != null) {
        _imageUrl = await _uploadImage();
      }

      // Get current driver's data to check if bus assignment has changed
      String? previousBusId = _driver?.busId;
      
      // Check if the selected bus is already assigned to another driver
      if (_selectedBusId != previousBusId) {
        DocumentSnapshot busDoc = await FirebaseFirestore.instance
            .collection('buses')
            .doc(_selectedBusId)
            .get();

        if (busDoc.exists) {
          Map<String, dynamic> busData = busDoc.data() as Map<String, dynamic>;
          if (busData['driverId'] != null && busData['driverId'] != _driver?.uid) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("This bus is already assigned to another driver!")),
            );
            setState(() {
              _isSaving = false;
            });
            return;
          }
        }
      }

      // Get selected bus details
      BusModel selectedBus = _availableBuses.firstWhere((bus) => bus.id == _selectedBusId);

      // Update driver model
      _driver!.id = _idController.text;
      _driver!.name = _nameController.text;
      _driver!.phone = _phoneController.text;
      _driver!.address = _addressController.text;
      _driver!.busId = _selectedBusId;
      _driver!.busNumberPlate = selectedBus.numberPlate;
      _driver!.busSource = selectedBus.source;
      _driver!.busDestination = selectedBus.destination;
      _driver!.imageUrl = _imageUrl;

      // Save driver to database
      await _driverService.updateDriver(_driver!);
      
      // Update bus to set the driverId field
      if (_selectedBusId != null) {
        // If the bus assignment has changed, update both old and new buses
        if (previousBusId != null && previousBusId != _selectedBusId) {
          // Remove driver from previous bus
          await FirebaseFirestore.instance
              .collection('buses')
              .doc(previousBusId)
              .update({'driverId': null});
        }
        
        // Update new bus with driverId
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(_selectedBusId)
            .update({'driverId': _driver!.uid});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver updated successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      print("Error updating driver: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating driver: $e")),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Driver'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver Image and Details Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        color: Colors.white.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Profile Image
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
                                      child: _selectedImage != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(75),
                                              child: Image.file(
                                                _selectedImage!,
                                                width: 150,
                                                height: 150,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : _imageUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(75),
                                                  child: Image.network(
                                                    _imageUrl!,
                                                    width: 150,
                                                    height: 150,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Icon(
                                                        Icons.person,
                                                        size: 80,
                                                        color: Colors.grey[400],
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.person,
                                                  size: 80,
                                                  color: Colors.grey[400],
                                                ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.add_a_photo, color: Colors.white),
                                      label: const Text('Change Photo'),
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
                                readOnly: true,
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
                                Icons.home,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                _emailController,
                                'Email',
                                Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                readOnly: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bus Selection Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        color: Colors.white.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
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
                                DropdownButtonFormField<String?>(
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
                                  value: _availableBuses.any((bus) => bus.id == _selectedBusId) ? _selectedBusId : null,
                                  items: _availableBuses.map((bus) {
                                    return DropdownMenuItem<String?>(
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

                      // Update Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _updateDriver,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Update Driver',
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
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
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
} 