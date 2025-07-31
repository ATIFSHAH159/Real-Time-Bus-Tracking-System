import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bus_model.dart';
import '../theme/app_colors.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  GoogleMapController? _mapController;
  LatLng _userPosition = const LatLng(37.7749, -122.4194); // Default position
  bool _isLoading = true;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  late String _userId;
  Stream<Position>? positionStream;
  
  // Bus details
  BusModel? _busDetails;
  List<LatLng> _routePoints = [];
  
  // Directions UI
  List<DirectionStep> _directionSteps = [];
  bool _showDirectionsPanel = false;
  
  // API key for Google Directions
  // Note: In production, this should be secured properly and not hardcoded
  final String _apiKey = "AIzaSyAopwURP-RbAZXSJgAP9GazKct9ILADHgc"; 

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Request location permissions first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permissions are permanently denied.");
        return;
      }

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Load bus data after getting location
      await _loadBusData();
      
      // Start location updates
      _startListeningToLocation();
    } catch (e) {
      print("Error initializing map: $e");
      _showSnackBar("Error initializing map: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// **Load Bus Data from Firestore**
  Future<void> _loadBusData() async {
    try {
      // Check if user is a driver
      DocumentSnapshot driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_userId)
          .get();
      
      String? busId;
      
      if (driverDoc.exists && driverDoc.data() != null) {
        // User is a driver
        Map<String, dynamic> driverData = driverDoc.data() as Map<String, dynamic>;
        busId = driverData['busId'];
        print("Found driver with busId: $busId");
      } else {
        // Check if user is a student
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(_userId)
            .get();
            
        if (studentDoc.exists && studentDoc.data() != null) {
          Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
          busId = studentData['busId'];
          print("Found student with busId: $busId");
        }
      }
      
      if (busId != null) {
        DocumentSnapshot busDoc = await FirebaseFirestore.instance
            .collection('buses')
            .doc(busId)
            .get();
            
        if (busDoc.exists && busDoc.data() != null) {
          _busDetails = BusModel.fromJson(busDoc.data() as Map<String, dynamic>);
          print("Bus details loaded: source=${_busDetails!.source}, destination=${_busDetails!.destination}, stops=${_busDetails!.stops}");
          
          // Get current location and then create the route
          Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          _userPosition = LatLng(position.latitude, position.longitude);
          print("Current position: ${_userPosition.latitude}, ${_userPosition.longitude}");
          
          await _createRoute();
        } else {
          print("Bus document not found or is empty for busId: $busId");
          _showSnackBar("Bus data not found. Please contact administrator.");
        }
      } else {
        print("No busId found for user: $_userId");
        _showSnackBar("No bus assigned. Please contact administrator.");
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading bus data: $e");
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Error loading route details: $e");
    }
  }

  /// **Create a Route with All Stops**
  Future<void> _createRoute() async {
    try {
      if (_busDetails == null) return;
      
      print("Creating route for bus: ${_busDetails!.numberPlate}");
      
      // Convert all stops to LatLng
      List<LatLng> waypoints = [];
      
      // First, geocode the source location
      print("Geocoding source: ${_busDetails!.source}");
      LatLng? sourceLatLng = await _geocodeAddress(_busDetails!.source!);
      if (sourceLatLng != null) {
        print("Source coordinates: ${sourceLatLng.latitude}, ${sourceLatLng.longitude}");
      } else {
        print("Failed to geocode source: ${_busDetails!.source}");
      }
      
      // Then geocode all stops
      if (_busDetails!.stops != null && _busDetails!.stops!.isNotEmpty) {
        print("Geocoding ${_busDetails!.stops!.length} stops");
        for (String stop in _busDetails!.stops!) {
          print("Geocoding stop: $stop");
          LatLng? stopLatLng = await _geocodeAddress(stop);
          if (stopLatLng != null) {
            print("Stop coordinates: ${stopLatLng.latitude}, ${stopLatLng.longitude}");
            waypoints.add(stopLatLng);
          } else {
            print("Failed to geocode stop: $stop");
          }
        }
      } else {
        print("No stops found in bus details");
      }
      
      // Finally, geocode the destination
      print("Geocoding destination: ${_busDetails!.destination}");
      LatLng? destinationLatLng = await _geocodeAddress(_busDetails!.destination!);
      if (destinationLatLng != null) {
        print("Destination coordinates: ${destinationLatLng.latitude}, ${destinationLatLng.longitude}");
      } else {
        print("Failed to geocode destination: ${_busDetails!.destination}");
      }
      
      // Create markers
      _addMarkers(sourceLatLng, waypoints, destinationLatLng);
      print("Added ${_markers.length} markers to map");
      
      // Create route through all points
      print("Getting directions from current location to destination through waypoints");
      await _getDirections(_userPosition, sourceLatLng, waypoints, destinationLatLng);
      
    } catch (e) {
      print("Error creating route: $e");
      _showSnackBar("Error creating route: $e");
    }
  }
  
  /// **Geocode an Address to LatLng**
  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey',
        ),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Geocoding response status: ${data['status']} for address: $address");
        
        if (data['status'] == 'OK') {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          print("Geocoding failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}");
        }
      } else {
        print("Geocoding HTTP error: ${response.statusCode} for address: $address");
      }
      return null;
    } catch (e) {
      print("Error geocoding address '$address': $e");
      return null;
    }
  }
  
  /// **Add Markers for Source, Stops, and Destination**
  void _addMarkers(LatLng? source, List<LatLng> stops, LatLng? destination) {
    _markers.clear();
    
    // Current location marker
    _markers.add(
      Marker(
        markerId: const MarkerId("current_location"),
        position: _userPosition,
        infoWindow: const InfoWindow(title: "Your Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
    
    // Source marker
    if (source != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("source"),
          position: source,
          infoWindow: InfoWindow(title: "Source: ${_busDetails!.source}"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    
    // Stop markers
    for (int i = 0; i < stops.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId("stop_$i"),
          position: stops[i],
          infoWindow: InfoWindow(title: "Stop: ${_busDetails!.stops![i]}"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        ),
      );
    }
    
    // Destination marker
    if (destination != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("destination"),
          position: destination,
          infoWindow: InfoWindow(title: "Destination: ${_busDetails!.destination}"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  /// **Get Directions and Draw Route**
  Future<void> _getDirections(
      LatLng origin, LatLng? source, List<LatLng> stops, LatLng? destination) async {
    try {
      if (source == null || destination == null) {
        print("Cannot get directions: source or destination is null");
        return;
      }
      
      // Build waypoints string
      String waypointsStr = "";
      
      // First add source as a waypoint
      waypointsStr += "via:${source.latitude},${source.longitude}";
      
      // Then add all stops
      for (LatLng stop in stops) {
        waypointsStr += "|via:${stop.latitude},${stop.longitude}";
      }
      
      print("Requesting directions with ${stops.length + 1} waypoints");
      final requestUrl = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&waypoints=$waypointsStr'
          '&key=$_apiKey';
      print("Directions API URL: ${requestUrl.substring(0, requestUrl.indexOf('key=') + 5)}...");
      
      final response = await http.get(Uri.parse(requestUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print("Directions API response status: ${data['status']}");
        if (data['status'] == 'OK') {
          // Decode polyline
          print("Route found with ${data['routes'][0]['legs'].length} legs");
          _routePoints = _decodePolyline(data['routes'][0]['overview_polyline']['points']);
          print("Decoded ${_routePoints.length} points for the route");
          
          // Create polyline
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId("route"),
              points: _routePoints,
              color: Colors.blue,
              width: 5,
            ),
          );
          
          // Parse direction steps
          _parseDirectionSteps(data['routes'][0]['legs']);
          
          // Update UI
          setState(() {
            _showDirectionsPanel = true;
          });
          
          // Fit map to show all markers
          _fitMapToRoute();
        } else {
          print("Directions API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}");
          _showSnackBar("Could not find route: ${data['status']}");
        }
      } else {
        print("Directions API HTTP error: ${response.statusCode}");
        _showSnackBar("Error connecting to directions service");
      }
    } catch (e) {
      print("Error getting directions: $e");
      _showSnackBar("Error getting directions: $e");
    }
  }
  
  /// **Decode Google Polyline**
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    
    while (index < len) {
      int b, shift = 0, result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      double latitude = lat / 1E5;
      double longitude = lng / 1E5;
      
      points.add(LatLng(latitude, longitude));
    }
    
    return points;
  }
  
  /// **Parse Direction Steps from API Response**
  void _parseDirectionSteps(List<dynamic> legs) {
    _directionSteps = [];
    
    int stepCounter = 1;
    for (var leg in legs) {
      String startAddress = leg['start_address'];
      String endAddress = leg['end_address'];
      
      // Add start point
      if (_directionSteps.isEmpty) {
        _directionSteps.add(
          DirectionStep(
            stepNumber: stepCounter++,
            instruction: "Start from your current location",
            distance: "",
            duration: "",
            maneuver: "start",
            isWaypoint: true,
          ),
        );
      }
      
      // Add waypoint (source, stops, or destination)
      _directionSteps.add(
        DirectionStep(
          stepNumber: stepCounter++,
          instruction: "Head to $startAddress",
          distance: "",
          duration: "",
          maneuver: "waypoint",
          isWaypoint: true,
        ),
      );
      
      // Add individual steps between waypoints
      for (var step in leg['steps']) {
        String instruction = step['html_instructions'];
        // Remove HTML tags
        instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), ' ');
        instruction = instruction.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        String distance = step['distance']['text'];
        String duration = step['duration']['text'];
        String maneuver = step['maneuver'] ?? "straight";
        
        _directionSteps.add(
          DirectionStep(
            stepNumber: stepCounter++,
            instruction: instruction,
            distance: distance,
            duration: duration,
            maneuver: maneuver,
            isWaypoint: false,
          ),
        );
      }
      
      // Add final waypoint for this leg
      if (leg == legs.last) {
        _directionSteps.add(
          DirectionStep(
            stepNumber: stepCounter++,
            instruction: "Arrive at $endAddress",
            distance: "",
            duration: "",
            maneuver: "arrive",
            isWaypoint: true,
          ),
        );
      }
    }
    
    print("Parsed ${_directionSteps.length} direction steps");
  }
  
  /// **Get Icon for Maneuver Type**
  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'turn-right':
      case 'right':
        return Icons.turn_right;
      case 'turn-left':
      case 'left':
        return Icons.turn_left;
      case 'roundabout-right':
      case 'roundabout-left':
        return Icons.roundabout_right;
      case 'uturn-right':
      case 'uturn-left':
        return Icons.u_turn_right;
      case 'fork-right':
      case 'fork-left':
        return Icons.fork_right;
      case 'merge':
        return Icons.merge_type;
      case 'straight':
        return Icons.arrow_upward;
      case 'start':
        return Icons.my_location;
      case 'waypoint':
        return Icons.location_on;
      case 'arrive':
        return Icons.flag;
      default:
        return Icons.arrow_forward;
    }
  }
  
  /// **Fit Map to Show All Route Points**
  void _fitMapToRoute() {
    if (_mapController == null) return;
    
    if (_routePoints.isNotEmpty) {
      // Create bounds
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;
      
      for (LatLng point in _routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      
      // Add padding to bounds
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.05, minLng - 0.05),
        northeast: LatLng(maxLat + 0.05, maxLng + 0.05),
      );
      
      // Animate camera to include all
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  /// **Request Permissions & Start Location Updates**
  Future<void> _startListeningToLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location service is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("Location services are disabled.");
      return;
    }

    // Check & request permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar("Location permissions are permanently denied.");
      return;
    }

    // Get initial position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _userPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });

    // Start streaming location updates
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update when movement is at least 10 meters
      ),
    );

    positionStream!.listen((Position position) {
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        
        // Update user marker
        _markers.removeWhere((marker) => marker.markerId.value == "current_location");
        _markers.add(
          Marker(
            markerId: const MarkerId("current_location"),
            position: _userPosition,
            infoWindow: const InfoWindow(title: "Your Location"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });
    });
  }

  /// **Show Snack Bar for Messages**
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bus Route',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.gradientPrimary,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Map
          _isLoading
              ? Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientAccent,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _userPosition, zoom: 15),
                  onMapCreated: (controller) {
                    setState(() {
                      _mapController = controller;
                      _isLoading = false;
                    });
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(_userPosition, 15),
                    );
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true,
                  zoomGesturesEnabled: true,
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.gradientAccent,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          
          // Directions Panel
          if (_showDirectionsPanel && _directionSteps.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowMedium,
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Directions",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _showDirectionsPanel = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Direction steps list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _directionSteps.length,
                        itemBuilder: (context, index) {
                          final step = _directionSteps[index];
                          return DirectionStepCard(
                            step: step,
                            icon: _getManeuverIcon(step.maneuver),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          setState(() {
            _userPosition = LatLng(position.latitude, position.longitude);
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_userPosition),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}

/// Direction Step Model
class DirectionStep {
  final int stepNumber;
  final String instruction;
  final String distance;
  final String duration;
  final String maneuver;
  final bool isWaypoint;
  
  DirectionStep({
    required this.stepNumber,
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuver,
    required this.isWaypoint,
  });
}

/// Direction Step Card Widget
class DirectionStepCard extends StatelessWidget {
  final DirectionStep step;
  final IconData icon;
  
  const DirectionStepCard({
    super.key,
    required this.step,
    required this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: step.isWaypoint ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: step.isWaypoint ? AppColors.primary.withOpacity(0.1) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Direction icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: step.isWaypoint 
                    ? AppColors.gradientPrimary 
                    : LinearGradient(
                        colors: [Colors.grey.shade200, Colors.grey.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: step.isWaypoint 
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: step.isWaypoint ? Colors.white : AppColors.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            
            // Direction text and details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.instruction,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (step.distance.isNotEmpty || step.duration.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${step.distance} ${step.distance.isNotEmpty && step.duration.isNotEmpty ? '· ' : ''}${step.duration}",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
