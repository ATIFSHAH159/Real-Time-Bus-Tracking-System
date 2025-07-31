import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_driver.dart';
import 'driver_details.dart';
import 'edit_driver.dart';
import '../models/driver_model.dart';
import '../models/bus_model.dart';
import '../Services/driver_service.dart';
import '../theme/app_colors.dart';

class DriverManagement extends StatefulWidget {
  const DriverManagement({super.key});

  @override
  _DriverManagementState createState() => _DriverManagementState();
}

class _DriverManagementState extends State<DriverManagement> {
  final DriverService _driverService = DriverService();
  bool _isLoading = false;
  String? _selectedBusId;
  final List<BusModel> _availableBuses = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Drivers'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.gradientPrimary,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Manage Drivers',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddDriver()),
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _driverService.getAllDrivers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Card(
                          color: Colors.white.withOpacity(0.95),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Card(
                          color: Colors.white.withOpacity(0.95),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: AppColors.primary),
                                const SizedBox(height: 16),
                                const Text(
                                  'No drivers found',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        DocumentSnapshot doc = snapshot.data!.docs[index];
                        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                        DriverModel driver = DriverModel.fromJson(data);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white.withOpacity(0.95),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              driver.name ?? 'No Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID: ${driver.id ?? 'No ID'}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                Text(
                                  'Bus: ${driver.busNumberPlate ?? 'Not Assigned'}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.visibility, color: AppColors.primary),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DriverDetails(driverId: doc.id),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: AppColors.accent),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditDriver(driverId: doc.id),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: AppColors.error),
                                  onPressed: () {
                                    _showDeleteConfirmation(doc.id);
                                  },
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DriverDetails(driverId: doc.id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String driverId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Delete Driver",
            style: TextStyle(color: AppColors.primary),
          ),
          content: const Text("Are you sure you want to delete this driver?"),
          actions: [
            TextButton(
              child: Text(
                "Cancel",
                style: TextStyle(color: AppColors.primary),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                "Delete",
                style: TextStyle(color: AppColors.error),
              ),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  await _driverService.deleteDriver(driverId);
                  
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Driver deleted successfully"),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error deleting driver: $e"),
                      backgroundColor: AppColors.error,
                    ),
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }
} 