import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../models/bus_model.dart';
import '../Services/driver_service.dart';
import '../Services/bus_service.dart';
import 'edit_driver.dart';
import '../theme/app_colors.dart';

class DriverDetails extends StatefulWidget {
  final String driverId;

  const DriverDetails({super.key, required this.driverId});

  @override
  _DriverDetailsState createState() => _DriverDetailsState();
}

class _DriverDetailsState extends State<DriverDetails> {
  final DriverService _driverService = DriverService();
  final BusService _busService = BusService();
  
  bool _isLoading = true;
  DriverModel? _driver;
  BusModel? _bus;

  @override
  void initState() {
    super.initState();
    _loadDriverDetails();
  }

  Future<void> _loadDriverDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get driver details
      _driver = await _driverService.getDriver(widget.driverId);
      
      if (_driver != null && _driver!.busId != null) {
        // Get associated bus details if bus is assigned
        try {
          _bus = await _busService.getBus(_driver!.busId!);
        } catch (e) {
          print("Error fetching bus data: $e");
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading driver details: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Details'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditDriver(driverId: widget.driverId),
                ),
              ).then((_) => _loadDriverDetails());
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _driver == null
                  ? Center(
                      child: Card(
                        color: Colors.white.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppColors.error),
                              const SizedBox(height: 16),
                              const Text(
                                'Driver not found',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Driver Avatar and Name
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  backgroundImage: _driver!.imageUrl != null
                                      ? NetworkImage(_driver!.imageUrl!)
                                      : null,
                                  child: _driver!.imageUrl == null
                                      ? Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _driver!.name ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Driver ID: ${_driver!.id ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Driver Details Section
                          _buildSectionTitle('Contact Information'),
                          _buildDetailItem('Email', _driver!.email ?? 'N/A', Icons.email),
                          _buildDetailItem('Phone', _driver!.phone ?? 'N/A', Icons.phone),
                          _buildDetailItem('Address', _driver!.address ?? 'N/A', Icons.home),
                          const SizedBox(height: 16),

                          // Bus Assignment Section
                          _buildSectionTitle('Bus Assignment'),
                          if (_bus != null) ...[
                            _buildDetailItem('Bus Number', _bus!.numberPlate ?? 'N/A', Icons.directions_bus),
                            _buildDetailItem('Route', '${_bus!.source ?? 'N/A'} to ${_bus!.destination ?? 'N/A'}', Icons.map),
                            _buildDetailItem('Capacity', '${_bus!.currentCapacity ?? '0'}/${_bus!.capacity ?? '0'} students', Icons.people),
                            
                            if (_bus!.schedule != null) ...[
                              _buildDetailItem('Morning Departure', _bus!.schedule!['morning'] ?? 'N/A', Icons.access_time),
                              _buildDetailItem('Evening Departure', _bus!.schedule!['evening'] ?? 'N/A', Icons.access_time),
                            ]
                          ] else ...[
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.amber.shade100,
                              child: ListTile(
                                leading: Icon(Icons.warning, color: Colors.amber.shade800),
                                title: Text('No bus assigned or bus details not available'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white.withOpacity(0.95),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
        subtitle: Text(value),
      ),
    );
  }
} 