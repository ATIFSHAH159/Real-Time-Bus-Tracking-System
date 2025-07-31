import 'package:bus_tracking_system/Screens/Google_map_Screen.dart';
import 'package:bus_tracking_system/Auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/bus_model.dart';
import '../models/driver_model.dart';
import '../theme/app_colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:bus_tracking_system/Screens/feedbackScreen.dart';
import 'driver_profile.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  _DriverDashboardState createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FeedbackScreen(isDriver: true),
    const DriverProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex], // Display selected screen

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Feedback',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// 🏠 Home Screen with Uber-like driver UI
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  bool _isLoading = true;
  bool _isOnShift = false;
  bool _isLocationSharing = false;
  Timer? _locationTimer;
  final Location _location = Location();
  
  // Driver data
  DriverModel? _driver;
  BusModel? _assignedBus;
  Map<String, dynamic>? _driverData;
  
  // Seat status
  int _seatStatus = 0;
  StreamSubscription? _seatStatusSubscription;
  
  // Upcoming schedules
  String _nextDepartureTime = '';
  String _greetingMessage = '';
  String _nextScheduleMessage = '';
  String _todayDateFormatted = '';
  bool _isWeekend = false;

  @override
  void initState() {
    super.initState();
    _fetchDriverAndBusDetails();
    _checkLocationPermission();
    _checkShiftStatus();
    _calculateNextSchedule();
    _listenToSeatStatus();
  }
  
  @override
  void dispose() {
    _locationTimer?.cancel();
    _seatStatusSubscription?.cancel();
    super.dispose();
  }
  
  // Check if driver location sharing is already active
  Future<void> _checkShiftStatus() async {
    try {
      final driverId = _auth.currentUser?.uid;
      if (driverId != null) {
        // Get location status
        final locationSnapshot = await _database.child('drivers/$driverId/location').once();
        
        // Get shift status
        final shiftSnapshot = await _database.child('drivers/$driverId/onShift').once();
        
        // Process the shift status
        bool isOnShift;
        if (shiftSnapshot.snapshot.value is bool) {
          isOnShift = shiftSnapshot.snapshot.value as bool;
        } else {
          isOnShift = shiftSnapshot.snapshot.exists && 
                      (shiftSnapshot.snapshot.value as bool? ?? false);
        }
        
        // Check location data
        bool isLocationActive = false;
        if (locationSnapshot.snapshot.exists && locationSnapshot.snapshot.value != null) {
          var locationData = Map<String, dynamic>.from(locationSnapshot.snapshot.value as Map);
          isLocationActive = locationData['active'] != false;
        }
        
        print("Driver initial status - OnShift: $isOnShift, Location sharing: $isLocationActive");
        
        setState(() {
          _isLocationSharing = isLocationActive;
          _isOnShift = isOnShift;
        });
        
        // Make sure the location sharing is synchronized with shift status
        if (_isOnShift && !_isLocationSharing) {
          // Driver is on shift but location is not active, start sharing
          _startLocationSharing();
        } else if (!_isOnShift && _isLocationSharing) {
          // Driver is not on shift but location is active, stop sharing
          _stopLocationSharing();
        }
      }
    } catch (e) {
      debugPrint('Error checking shift status: $e');
    }
  }
  
  // Calculate next schedule based on current time
  void _calculateNextSchedule() {
    final now = DateTime.now();
    _todayDateFormatted = DateFormat('EEEE, MMMM d').format(now);
    
    // Check if it's weekend
    _isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    
    if (_isWeekend) {
      _nextScheduleMessage = 'Weekend - No Service Available';
      _greetingMessage = 'Enjoy your weekend!';
      return;
    }
    
    // Get time of day
    final hour = now.hour;
    if (hour < 12) {
      _greetingMessage = 'Good Morning';
      _nextScheduleMessage = 'Morning Route';
    } else if (hour < 17) {
      _greetingMessage = 'Good Afternoon';
      _nextScheduleMessage = 'Evening Route';
    } else {
      _greetingMessage = 'Good Evening';
      _nextScheduleMessage = 'Tomorrow Morning';
    }
  }

  // Listen to seat status changes
  void _listenToSeatStatus() {
    _seatStatusSubscription = _database.child('seatStatus').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _seatStatus = int.tryParse(event.snapshot.value.toString()) ?? 0;
        });
      }
    });
  }

  Future<void> _fetchDriverAndBusDetails() async {
    try {
      final driverId = _auth.currentUser?.uid;
      if (driverId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get driver details
      final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
      if (!driverDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _driver = DriverModel.fromJson(driverDoc.data() as Map<String, dynamic>);
      _driverData = driverDoc.data();
      
      // Get assigned bus details
      if (_driver?.busId != null) {
        final busDoc = await _firestore.collection('buses').doc(_driver!.busId).get();
        if (busDoc.exists) {
          _assignedBus = BusModel.fromJson(busDoc.data() as Map<String, dynamic>);
          
          // Get current seat status
          final seatStatusSnapshot = await _database.child('seatStatus/$driverId').once();
          if (seatStatusSnapshot.snapshot.value != null) {
            _seatStatus = int.tryParse(seatStatusSnapshot.snapshot.value.toString()) ?? 0;
          }
          
          // Set next departure time based on time of day
          final now = DateTime.now();
          final hour = now.hour;
          
          if (_assignedBus?.schedule != null) {
            if (hour < 12) {
              _nextDepartureTime = _assignedBus!.schedule!['morning'] ?? 'Not set';
            } else {
              _nextDepartureTime = _assignedBus!.schedule!['evening'] ?? 'Not set';
            }
          }
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching driver details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _checkLocationPermission() async {
    final location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _showSnackBar("Location services are disabled");
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        _showSnackBar("Location permission is denied");
        return;
      }
    }
  }
  
  // Start/stop driver's shift
  Future<void> _toggleShift() async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) return;

    setState(() {
      _isOnShift = !_isOnShift;
    });
    
    try {
      // Update shift status in database first (important!)
      await _database.child('drivers/$driverId/onShift').set(_isOnShift);
      
      if (_isOnShift) {
        // Immediately update location with active status to prevent delays
        final locationData = await _location.getLocation();
        await _database.child('drivers/$driverId/location').set({
          'latitude': locationData.latitude,
          'longitude': locationData.longitude,
          'timestamp': ServerValue.timestamp,
          'active': true,
        });
        
        // Then start the periodic updates
        _startLocationSharing();
        _showSnackBar("Shift started! Location sharing enabled.");
      } else {
        _stopLocationSharing();
        _showSnackBar("Shift ended! Location sharing disabled.");
      }
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}");
      setState(() {
        _isOnShift = !_isOnShift; // Revert state on error
      });
    }
  }
  
  // Start sharing location
  void _startLocationSharing() {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) return;
    
    // Cancel any existing timer
    _locationTimer?.cancel();
    
    // Set up periodic location updates
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final locationData = await _location.getLocation();
        
        await _database.child('drivers/$driverId/location').set({
          'latitude': locationData.latitude,
          'longitude': locationData.longitude,
          'timestamp': ServerValue.timestamp,
          'active': true,  // Explicitly mark as active
        });
        
        setState(() {
          _isLocationSharing = true;
        });
      } catch (e) {
        debugPrint('Error updating location: $e');
      }
    });
  }
  
  // Stop sharing location
  void _stopLocationSharing() {
    _locationTimer?.cancel();
    final driverId = _auth.currentUser?.uid;
    if (driverId != null) {
      // Keep the last location but mark as inactive
      _database.child('drivers/$driverId/location/active').set(false);
    }
    
    setState(() {
      _isLocationSharing = false;
    });
  }
  
  void _viewFullMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GoogleMapScreen()),
    );
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    
    if (_driver == null || _assignedBus == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              "No bus assigned",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please contact administrator",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDriverAndBusDetails,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  shadowColor: AppColors.shadowMedium,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
              ),
              child: const Text("Refresh"),
            ),
          ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Status Bar with enhanced design
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowMedium,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                        Row(
                          children: [
                            // Profile Image
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(35),
                                child: _driverData?['imageUrl'] != null
                                    ? Image.network(
                                        _driverData!['imageUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.white,
                                            child: Center(
                                              child: Text(
                                                _getInitials(),
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.white,
                                        child: Center(
                                          child: Text(
                                            _getInitials(),
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greetingMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                                    letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                                  _driverData?['name'] ?? "Driver",
                          style: const TextStyle(
                            color: Colors.white,
                                    fontSize: 24,
                            fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isOnShift ? AppColors.success : AppColors.error,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (_isOnShift ? AppColors.success : AppColors.error).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _isOnShift ? "On Shift" : "Off Duty",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Start/Stop Shift Button with enhanced design
                Container(
                  width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_isOnShift ? AppColors.error : AppColors.primary).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                  child: ElevatedButton(
                    onPressed: _toggleShift,
                    style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnShift ? AppColors.error : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                      shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isOnShift ? Icons.stop_circle : Icons.play_circle,
                          size: 24,
                          color: Colors.white,
                        ),
                            const SizedBox(width: 12),
                            const Text(
                              "START SHIFT",
                              style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchDriverAndBusDetails,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Bus Details Card
                        Card(
                          elevation: 8,
                          shadowColor: AppColors.shadowMedium,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientCard,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: AppColors.gradientPrimary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.directions_bus,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Bus ${_assignedBus?.numberPlate ?? ''}",
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Capacity: $_seatStatus/${_assignedBus?.capacity ?? 0} students",
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    "Next Schedule",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.1),
                                          AppColors.accent.withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          _nextScheduleMessage,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _nextDepartureTime,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Route Information Card
                        Card(
                          elevation: 8,
                          shadowColor: AppColors.shadowMedium,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientCard,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: AppColors.gradientDashboard2,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.route,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Text(
                                        "Route Information",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Source
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.trip_origin, color: AppColors.primary, size: 16),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('From', style: TextStyle(color: AppColors.textSecondary)),
                                            Text(
                                              _assignedBus?.source ?? 'Unknown Source',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Route line
                                  Padding(
                                    padding: const EdgeInsets.only(left: 15),
                                    child: SizedBox(
                                      height: 30,
                                      child: Column(
                                        children: List.generate(
                                          3,
                                          (index) => Expanded(
                                            child: Container(
                                              width: 2,
                                              color: index == 1 ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Destination
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.location_on, color: AppColors.primary, size: 16),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('To', style: TextStyle(color: AppColors.textSecondary)),
                                            Text(
                                              _assignedBus?.destination ?? 'Unknown Destination',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // View on Map Button
                                  Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: _viewFullMap,
                                      icon: const Icon(Icons.map, color: Colors.white),
                                      label: const Text(
                                        "VIEW ON MAP",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (_driver == null || _driver!.name == null) return 'D';
    
    List<String> nameParts = _driver!.name!.split(' ');
    if (nameParts.isEmpty) return 'D';
    if (nameParts.length == 1) return nameParts[0][0];
    return nameParts[0][0] + nameParts[1][0];
  }
}
