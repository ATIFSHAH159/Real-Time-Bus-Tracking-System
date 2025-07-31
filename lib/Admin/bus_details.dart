import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../Services/bus_service.dart';
import '../theme/app_colors.dart';

class BusDetails extends StatefulWidget {
  final String busId;

  const BusDetails({super.key, required this.busId});

  @override
  _BusDetailsState createState() => _BusDetailsState();
}

class _BusDetailsState extends State<BusDetails> {
  final BusService _busService = BusService();
  
  bool _isLoading = true;
  BusModel? _bus;

  @override
  void initState() {
    super.initState();
    _loadBusDetails();
  }

  Future<void> _loadBusDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _bus = await _busService.getBus(widget.busId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading bus details: $e")),
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
        title: const Text('Bus Details'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _bus == null
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
                                'Bus not found',
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
                          // Bus Avatar and Number Plate
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Icon(
                                    Icons.directions_bus,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _bus!.numberPlate ?? 'No Plate',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Bus ID: ${_bus!.id ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Bus Details Section
                          _buildSectionTitle('Bus Information'),
                          _buildDetailItem('Capacity', '${_bus!.currentCapacity}/${_bus!.capacity} students', Icons.people),
                          const SizedBox(height: 16),

                          // Route Information Section
                          _buildSectionTitle('Route Information'),
                          _buildDetailItem('Source', _bus!.source ?? 'N/A', Icons.location_on),
                          _buildDetailItem('Destination', _bus!.destination ?? 'N/A', Icons.location_on),
                          const SizedBox(height: 16),

                          // Schedule Section
                          if (_bus!.schedule != null) ...[
                            _buildSectionTitle('Schedule'),
                            _buildDetailItem('Morning Departure', _bus!.schedule!['morning'] ?? 'N/A', Icons.access_time),
                            _buildDetailItem('Evening Departure', _bus!.schedule!['evening'] ?? 'N/A', Icons.access_time),
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