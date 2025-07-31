import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../theme/app_colors.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart' as ui;
import 'package:flutter/rendering.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  GoogleMapController? _mapController;
  LatLng _driverPosition = const LatLng(34.1558, 73.2194); // Default to Abbottabad
  LatLng _userPosition = const LatLng(34.1558, 73.2194); // Default to Abbottabad
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _isDriverOnline = false;
  String? _busId;
  String? _driverId;
  String? _primaryDriverId;
  String? _optionalDriverId;
  Map<String, dynamic>? _busData;
  
  // Directions UI
  List<DirectionStep> _directionSteps = [];
  bool _showDirectionsPanel = false;
  
  // Bus marker icon
  BitmapDescriptor? _busIcon;
  
  // API key for Google Directions
  final String _apiKey = "AIzaSyAopwURP-RbAZXSJgAP9GazKct9ILADHgc";

  // Variables for tracking driver heading
  double _driverHeading = 0.0;
  LatLng? _previousDriverPosition;

  // Class variables
  String _estimatedArrival = "Calculating...";

  @override
  void initState() {
    super.initState();
    // Load custom marker icon
    _loadBusMarkerIcon();
    // Get user location first, then fetch bus details
    _getCurrentLocation().then((_) {
      // We'll get busId in didChangeDependencies
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get busId from route arguments
    _busId = ModalRoute.of(context)?.settings.arguments as String?;
    if (_busId != null) {
      _fetchBusDetails();
    } else {
      _fetchAnyAvailableBus();
    }
  }
  
  /// **Load Custom Bus Marker Icon**
  Future<void> _loadBusMarkerIcon() async {
    try {
      // Create a custom icon using a simple approach
      final iconData = Icons.directions_bus;
      final iconSize = 70.0;
      
      // Create a custom marker icon
      _busIcon = BitmapDescriptor.fromBytes(
        await _createCustomMarkerIcon(iconData, iconSize),
      );
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error loading bus marker icon: $e");
      if (mounted) {
        setState(() {
          _busIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        });
      }
    }
  }

  /// **Create Custom Marker Icon**
  Future<Uint8List> _createCustomMarkerIcon(IconData iconData, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    final iconStr = String.fromCharCode(iconData.codePoint);
    textPainter.text = TextSpan(
      text: iconStr,
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        color: Colors.blue,
      ),
    );
    
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// **Get User's Current Location**
  Future<void> _getCurrentLocation() async {
    try {
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

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        
        // Also update the initial map camera position
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_userPosition, 15),
          );
        }
      });
      
      print("User position updated: ${_userPosition.latitude}, ${_userPosition.longitude}");
      
      // Update user marker
      _markers.add(
        Marker(
          markerId: const MarkerId("user_location"),
          position: _userPosition,
          infoWindow: const InfoWindow(
            title: "Your Location", 
            snippet: "This is where you are"
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  /// **Fetch Bus Details from Firestore**
  Future<void> _fetchBusDetails() async {
    try {
      DocumentSnapshot busDoc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(_busId)
          .get();
      
      if (busDoc.exists) {
        Map<String, dynamic> busData = busDoc.data() as Map<String, dynamic>;
        
        // Debug print to check data
        print("Bus data: ${busData.toString()}");
        // Use primaryDriverId or optionalDriverId if available, fallback to driverId for legacy support
        String? primaryDriverId = busData['primaryDriverId'];
        String? optionalDriverId = busData['optionalDriverId'];
        String? driverId;
        if (primaryDriverId != null && primaryDriverId.isNotEmpty) {
          driverId = primaryDriverId;
        } else if (optionalDriverId != null && optionalDriverId.isNotEmpty) {
          driverId = optionalDriverId;
        } else {
          driverId = busData['driverId'];
        }
        
        setState(() {
          _busData = busData;
          _driverId = driverId;
          _primaryDriverId = primaryDriverId;
          _optionalDriverId = optionalDriverId;
        });
        
        // If driver is assigned, listen to their location
        if (driverId != null && driverId.isNotEmpty) {
          print("Driver is assigned with ID: $driverId - listening to location");
          _listenToDriverLocation();
        } else {
          print("No driver ID found in bus data");
          _drawBusRoute(); // Just draw the route if no driver assigned
          setState(() {
            _isLoading = false;
            _isDriverOnline = false;
          });
          _showSnackBar("No driver assigned to this bus yet.");
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar("Bus details not found.");
      }
    } catch (e) {
      print("Error in _fetchBusDetails: $e");
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Error fetching bus details: $e");
    }
  }
  
  /// **Fetch Any Available Bus (fallback)**
  Future<void> _fetchAnyAvailableBus() async {
    try {
      QuerySnapshot busQuery = await FirebaseFirestore.instance
          .collection('buses')
          .limit(1)
          .get();
      
      if (busQuery.docs.isNotEmpty) {
        DocumentSnapshot firstBus = busQuery.docs.first;
        Map<String, dynamic> busData = firstBus.data() as Map<String, dynamic>;
        
        // Debug print
        print("Any available bus data: ${busData.toString()}");
        // Use primaryDriverId or optionalDriverId if available, fallback to driverId for legacy support
        String? primaryDriverId = busData['primaryDriverId'];
        String? optionalDriverId = busData['optionalDriverId'];
        String? driverId;
        if (primaryDriverId != null && primaryDriverId.isNotEmpty) {
          driverId = primaryDriverId;
        } else if (optionalDriverId != null && optionalDriverId.isNotEmpty) {
          driverId = optionalDriverId;
        } else {
          driverId = busData['driverId'];
        }
        
        setState(() {
          _busId = firstBus.id;
          _busData = busData;
          _driverId = driverId;
          _primaryDriverId = primaryDriverId;
          _optionalDriverId = optionalDriverId;
        });
        
        if (driverId != null && driverId.isNotEmpty) {
          print("Driver found for available bus: $driverId");
          _listenToDriverLocation();
        } else {
          print("No driver assigned to available bus");
          _drawBusRoute();
          setState(() {
            _isLoading = false;
            _isDriverOnline = false;
          });
          _showSnackBar("No driver is currently assigned to this bus.");
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar("No buses available.");
      }
    } catch (e) {
      print("Error in _fetchAnyAvailableBus: $e");
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Error: $e");
    }
  }

  /// **Listen to Firebase for the Driver's Live Location**
  void _listenToDriverLocation() {
    if ((_primaryDriverId == null || _primaryDriverId!.isEmpty) && (_optionalDriverId == null || _optionalDriverId!.isEmpty) && (_driverId == null || _driverId!.isEmpty)) {
      print("No driver ID available, cannot listen to location");
      _drawBusRoute();
      setState(() {
        _isDriverOnline = false;
        _isLoading = false;
      });
      _showSnackBar("Driver information not available.");
      return;
    }

    // Helper to listen to a specific driver
    void listenToDriver(String driverIdToListen) {
      DatabaseReference driverRef = FirebaseDatabase.instance.ref("drivers/$driverIdToListen");
      driverRef.onValue.listen((DatabaseEvent event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          setState(() {
            _isDriverOnline = false;
            _isLoading = false;
          });
          _drawBusRoute();
          _showSnackBar("Driver data not available. Showing planned route.");
          return;
        }
        try {
          var driverData = Map<String, dynamic>.from(event.snapshot.value as Map);
          bool isOnShift = driverData['onShift'] == true;
          setState(() {
            _isDriverOnline = isOnShift;
            if (!isOnShift) {
              _isLoading = false;
              _drawBusRoute();
              _showSnackBar("Driver is currently off duty. Showing planned route.");
            }
          });
          if (isOnShift) {
            if (driverData.containsKey('location') && driverData['location'] != null) {
              var locationData = Map<String, dynamic>.from(driverData['location'] as Map);
              double latitude = locationData['latitude'] ?? 0.0;
              double longitude = locationData['longitude'] ?? 0.0;
              if (_previousDriverPosition != null) {
                _driverHeading = _calculateHeading(
                  _previousDriverPosition!.latitude, 
                  _previousDriverPosition!.longitude,
                  latitude,
                  longitude
                );
              }
              _previousDriverPosition = LatLng(latitude, longitude);
              setState(() {
                _driverPosition = LatLng(latitude, longitude);
                _updateMapMarker();
                _isLoading = false;
                _isDriverOnline = true;
              });
              if (_mapController != null && !_showDirectionsPanel) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(_driverPosition),
                );
              }
              _getDirectionsToDriver();
            } else if (driverData.containsKey('latitude') && driverData.containsKey('longitude')) {
              double latitude = driverData['latitude'] ?? 0.0;
              double longitude = driverData['longitude'] ?? 0.0;
              if (_previousDriverPosition != null) {
                _driverHeading = _calculateHeading(
                  _previousDriverPosition!.latitude, 
                  _previousDriverPosition!.longitude,
                  latitude,
                  longitude
                );
              }
              _previousDriverPosition = LatLng(latitude, longitude);
              setState(() {
                _driverPosition = LatLng(latitude, longitude);
                _updateMapMarker();
                _isLoading = false;
                _isDriverOnline = true;
              });
              if (_mapController != null && !_showDirectionsPanel) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(_driverPosition),
                );
              }
              _getDirectionsToDriver();
            } else {
              setState(() {
                _isDriverOnline = false;
                _isLoading = false;
              });
              _drawBusRoute();
              _showSnackBar("Driver location not available. Showing planned route.");
            }
          }
        } catch (e) {
          print("Error processing driver data: $e");
          setState(() {
            _isDriverOnline = false;
            _isLoading = false;
          });
          _drawBusRoute();
          _showSnackBar("Error tracking driver: $e. Showing planned route.");
        }
      }, onError: (error) {
        print("Error listening to driver data: $error");
        setState(() {
          _isDriverOnline = false;
          _isLoading = false;
        });
        _drawBusRoute();
        _showSnackBar("Cannot track driver: $error. Showing planned route.");
      });
    }

    // Try primary driver first
    if (_primaryDriverId != null && _primaryDriverId!.isNotEmpty) {
      DatabaseReference primaryRef = FirebaseDatabase.instance.ref("drivers/$_primaryDriverId");
      primaryRef.once().then((event) {
        var data = event.snapshot.value;
        if (data != null && (data as Map)['onShift'] == true) {
          listenToDriver(_primaryDriverId!);
        } else if (_optionalDriverId != null && _optionalDriverId!.isNotEmpty) {
          DatabaseReference optionalRef = FirebaseDatabase.instance.ref("drivers/$_optionalDriverId");
          optionalRef.once().then((event) {
            var optData = event.snapshot.value;
            if (optData != null && (optData as Map)['onShift'] == true) {
              listenToDriver(_optionalDriverId!);
            } else if (_driverId != null && _driverId!.isNotEmpty) {
              listenToDriver(_driverId!);
            } else {
              setState(() {
                _isDriverOnline = false;
                _isLoading = false;
              });
              _drawBusRoute();
              _showSnackBar("No driver is currently on shift. Showing planned route.");
            }
          });
        } else if (_driverId != null && _driverId!.isNotEmpty) {
          listenToDriver(_driverId!);
        } else {
          setState(() {
            _isDriverOnline = false;
            _isLoading = false;
          });
          _drawBusRoute();
          _showSnackBar("No driver is currently on shift. Showing planned route.");
        }
      });
    } else if (_optionalDriverId != null && _optionalDriverId!.isNotEmpty) {
      DatabaseReference optionalRef = FirebaseDatabase.instance.ref("drivers/$_optionalDriverId");
      optionalRef.once().then((event) {
        var optData = event.snapshot.value;
        if (optData != null && (optData as Map)['onShift'] == true) {
          listenToDriver(_optionalDriverId!);
        } else if (_driverId != null && _driverId!.isNotEmpty) {
          listenToDriver(_driverId!);
        } else {
          setState(() {
            _isDriverOnline = false;
            _isLoading = false;
          });
          _drawBusRoute();
          _showSnackBar("No driver is currently on shift. Showing planned route.");
        }
      });
    } else if (_driverId != null && _driverId!.isNotEmpty) {
      listenToDriver(_driverId!);
    } else {
      setState(() {
        _isDriverOnline = false;
        _isLoading = false;
      });
      _drawBusRoute();
      _showSnackBar("No driver is currently on shift. Showing planned route.");
    }
  }
  
  /// **Calculate heading angle between two coordinates**
  double _calculateHeading(double startLat, double startLng, double endLat, double endLng) {
    // If positions are the same, keep previous heading
    if (startLat == endLat && startLng == endLng) {
      return _driverHeading;
    }
    
    double deltaLng = (endLng - startLng) * (pi / 180);
    double lat1 = startLat * (pi / 180);
    double lat2 = endLat * (pi / 180);
    
    double y = sin(deltaLng) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng);
    double bearing = atan2(y, x) * (180 / pi);
    
    // Convert to 0-360 degrees
    double heading = (bearing + 360) % 360;
    return heading;
  }
  
  /// **Draw Bus Route on Map**
  void _drawBusRoute() {
    if (_busData == null) return;
    
    // Extract source and destination locations
    String source = _busData?['source'] ?? '';
    String destination = _busData?['destination'] ?? '';
    List<dynamic> stops = _busData?['stops'] ?? [];
    
    print("Drawing bus route - Source: $source, Destination: $destination, Stops: $stops");
    
    try {
      // Create a list of points for the route
      List<LatLng> routePoints = [];
      List<LatLng> stopPoints = [];
      
      // Try to parse coordinates from source 
      LatLng? sourcePoint = _tryParseCoordinates(source);
      print("Source coordinates parsed: $sourcePoint");
      if (sourcePoint != null) {
        routePoints.add(sourcePoint);
        stopPoints.add(sourcePoint);
        
        // Add source marker
        _markers.add(
          Marker(
            markerId: const MarkerId('source'),
            position: sourcePoint,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Source', snippet: source),
          ),
        );
      } else {
        // If we can't parse coordinates directly, try to geocode the address
        _geocodeAndAddPoint(source, 'source', BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen))
            .then((LatLng? point) {
          if (point != null) {
            stopPoints.add(point);
            _getDirectionsForFullRoute(stopPoints);
          }
        });
      }
      
      // Process stops list - only add valid stops to route
      List<String> validStops = [];
      for (var stop in stops) {
        if (stop is String && stop.isNotEmpty) {
          validStops.add(stop);
        }
      }
      
      print("Valid stops count: ${validStops.length}");
      
      // Add valid stops to route - display them even if we can't extract coordinates
      for (int i = 0; i < validStops.length; i++) {
        String stop = validStops[i];
        
        // Try to extract coordinates if present
        LatLng? stopPoint = _tryParseCoordinates(stop);
        print("Stop $i coordinates parsed: $stopPoint");
        
        if (stopPoint != null) {
          stopPoints.add(stopPoint);
          
          // Add stop marker with the full address text
          _markers.add(
            Marker(
              markerId: MarkerId('stop$i'),
              position: stopPoint,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
              infoWindow: InfoWindow(title: 'Stop ${i+1}', snippet: stop),
            ),
          );
        } else {
          // If we can't parse coordinates, try geocoding
          _geocodeAndAddPoint(stop, 'stop$i', BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow))
              .then((LatLng? point) {
            if (point != null) {
              stopPoints.add(point);
              _getDirectionsForFullRoute(stopPoints);
            }
          });
        }
      }
      
      // Parse coordinates from destination
      LatLng? destPoint = _tryParseCoordinates(destination);
      print("Destination coordinates parsed: $destPoint");
      if (destPoint != null) {
        stopPoints.add(destPoint);
        
        // Add destination marker
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: destPoint,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Destination', snippet: destination),
          ),
        );
        
        // Get directions for the complete bus route
        _getDirectionsForFullRoute(stopPoints);
        
        // Get directions from user's location to the nearest point in the route
        _getOptimalRouteToNearestStop(stopPoints);
      } else {
        // If we can't parse coordinates, try geocoding
        _geocodeAndAddPoint(destination, 'destination', BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed))
            .then((LatLng? point) {
          if (point != null) {
            stopPoints.add(point);
            _getDirectionsForFullRoute(stopPoints);
            // Get directions from user's location to the nearest point in the route
            _getOptimalRouteToNearestStop(stopPoints);
          }
        });
      }
      
      // Calculate center point for initial camera position
      if (_mapController != null && stopPoints.isNotEmpty) {
        double totalLat = 0, totalLng = 0;
        for (var point in stopPoints) {
          totalLat += point.latitude;
          totalLng += point.longitude;
        }
        
        LatLng center = LatLng(
          totalLat / stopPoints.length, 
          totalLng / stopPoints.length
        );
        
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(center, 12),
        );
      }
      
      setState(() {}); // Refresh the map
    } catch (e) {
      print('Error drawing route: $e');
    }
  }
  
  /// **Get Directions for Full Bus Route**
  Future<void> _getDirectionsForFullRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      print("Not enough waypoints to draw route");
      return;
    }
    
    try {
      print("Getting directions for full bus route with ${waypoints.length} waypoints");
      
      // Origin is the first waypoint (source)
      LatLng origin = waypoints.first;
      
      // Destination is the last waypoint
      LatLng destination = waypoints.last;
      
      // Intermediate waypoints (all points except first and last)
      List<LatLng> intermediatePoints = [];
      if (waypoints.length > 2) {
        intermediatePoints = waypoints.sublist(1, waypoints.length - 1);
      }
      
      // Build waypoints string for the API
      String waypointsStr = "";
      for (var point in intermediatePoints) {
        if (waypointsStr.isNotEmpty) waypointsStr += "|";
        waypointsStr += "${point.latitude},${point.longitude}";
      }
      
      // Construct URL with all waypoints
      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}';
      
      // Add waypoints if there are any
      if (waypointsStr.isNotEmpty) {
        url += '&waypoints=$waypointsStr';
      }
      
      // Add API key
      url += '&key=$_apiKey';
      
      print("Requesting directions for bus route");
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          print("Got bus route directions successfully");
          
          // Decode polyline
          List<LatLng> routePoints = _decodePolyline(
            data['routes'][0]['overview_polyline']['points']
          );
          
          // Update bus route polyline
          setState(() {
            _updatePolyline(routePoints, 'bus_route', Colors.blue);
          });
        } else {
          print("Error getting bus route directions: ${data['status']}");
        }
      } else {
        print("HTTP error getting bus route directions: ${response.statusCode}");
      }
    } catch (e) {
      print("Error getting directions for full bus route: $e");
    }
  }
  
  /// **Update Polyline**
  void _updatePolyline(List<LatLng> points, String id, Color color) {
    // Remove existing polyline with this ID
    _polylines.removeWhere((polyline) => polyline.polylineId.value == id);
    
    // Add new polyline if we have at least 2 points
    if (points.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: PolylineId(id),
          points: points,
          color: color,
          width: 5,
        ),
      );
      print("Polyline added with ${points.length} points");
    }
  }
  
  /// **Geocode an address to coordinates**
  Future<LatLng?> _geocodeAndAddPoint(String address, String markerId, BitmapDescriptor icon) async {
    try {
      print("Geocoding address: $address");
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?'
          'address=${Uri.encodeComponent(address)}'
          '&key=$_apiKey',
        ),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final LatLng point = LatLng(location['lat'], location['lng']);
          
          print("Geocoded $address to $point");
          
          // Add marker for this point
          _markers.add(
            Marker(
              markerId: MarkerId(markerId),
              position: point,
              icon: icon,
              infoWindow: InfoWindow(title: markerId.replaceFirst(RegExp(r'\d+$'), ' ${int.parse(markerId.replaceAll(RegExp(r'[^\d]'), '0')) + 1}'), snippet: address),
            ),
          );
          
          return point;
        } else {
          print("Geocoding error: ${data['status']}");
          return null;
        }
      }
      return null;
    } catch (e) {
      print("Error geocoding address: $e");
      return null;
    }
  }
  
  /// **Get Directions from Google Maps API**
  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$_apiKey',
        ),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          // Decode polyline
          List<LatLng> routePoints = _decodePolyline(
            data['routes'][0]['overview_polyline']['points']
          );
          
          // Add student route polyline
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('student_route'),
              points: routePoints,
              color: Colors.green,
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
          
          // Parse steps for directions
          _parseDirectionSteps(data['routes'][0]['legs']);
          
          setState(() {
            _showDirectionsPanel = true;
          });
        }
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }
  
  /// **Get directions from user's location to the nearest stop**
  Future<void> _getOptimalRouteToNearestStop(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) return;
    
    // Find the nearest point from route to the user
    LatLng nearestPoint = routePoints.first;
    double minDistance = double.infinity;
    
    for (LatLng point in routePoints) {
      double distance = Geolocator.distanceBetween(
        _userPosition.latitude, _userPosition.longitude,
        point.latitude, point.longitude
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }
    
    // Get directions to the nearest point
    await _getDirections(_userPosition, nearestPoint);
  }
  
  /// **Get directions to the driver's current location**
  Future<void> _getDirectionsToDriver() async {
    if (_isDriverOnline) {
      await _getDirections(_userPosition, _driverPosition);
    }
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
      
      // Add waypoint
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
      
      // Add individual steps
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
      
      // Add final waypoint
      if (leg == legs.last) {
        String finalDestination = _isDriverOnline ? "Bus Location" : "Nearest Bus Stop";
        _directionSteps.add(
          DirectionStep(
            stepNumber: stepCounter++,
            instruction: "Arrive at $finalDestination",
            distance: "",
            duration: "",
            maneuver: "arrive",
            isWaypoint: true,
          ),
        );
      }
    }
  }
  
  /// **Decode Google Maps Polyline**
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
  
  /// **Try to extract coordinates from a string**
  LatLng? _tryParseCoordinates(String text) {
    // Regex to find coordinate pattern at the beginning or somewhere in the text
    final coordRegex = RegExp(r'(\-?\d+\.?\d*)\s*,\s*(\-?\d+\.?\d*)');
    final plusCodeRegex = RegExp(r'([0-9A-Z]{4,7}\+[0-9A-Z]{2,3})'); // Plus codes like "849VCWC+95"
    
    // First check for standard lat,lng format
    final match = coordRegex.firstMatch(text);
    if (match != null && match.groupCount >= 2) {
      try {
        final lat = double.parse(match.group(1)!);
        final lng = double.parse(match.group(2)!);
        
        // Validate the coordinates are in reasonable range
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          return LatLng(lat, lng);
        }
      } catch (e) {
        print('Error parsing coordinates: $e');
      }
    }
    
    // Also check for Google Maps plus codes which might be in the address
    final plusMatch = plusCodeRegex.firstMatch(text);
    if (plusMatch != null) {
      // Currently we can't convert a plus code to coordinates directly
      // We would need to use the Maps API for that
      print('Found plus code: ${plusMatch.group(0)}');
      // Return null for now - we'd need more complex handling
    }
    
    return null;
  }

  /// **Update Marker on the Map**
  void _updateMapMarker() {
    // Remove any existing driver marker
    _markers.removeWhere((m) => m.markerId.value == "driver_location");
    
    // Use the icon based on availability
    final BitmapDescriptor markerIcon = _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    
    // Add the updated driver marker with custom bus icon if available
    _markers.add(
      Marker(
        markerId: const MarkerId("driver_location"),
        position: _driverPosition,
        infoWindow: InfoWindow(
          title: "Bus ${_busData?['numberPlate'] ?? ''}", 
          snippet: _isDriverOnline 
              ? "Driver is online - Real-time tracking active"
              : "Driver is offline - Showing planned route"
        ),
        icon: markerIcon,
        // Make the bus marker rotate based on heading
        flat: true,
        rotation: _driverHeading,
        anchor: Offset(0.5, 0.5),
        zIndex: 2, // Make bus appear above other markers
      ),
    );
    
    // Also add user's current location marker
    _markers.add(
      Marker(
        markerId: const MarkerId("user_location"),
        position: _userPosition,
        infoWindow: const InfoWindow(
          title: "Your Location", 
          snippet: "This is where you are"
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        zIndex: 1,
      ),
    );
    
    // Update estimated arrival time
    setState(() {
      _estimatedArrival = _calculateEstimatedArrival();
    });
  }
  
  /// **Format driver speed for display**
  String _formatSpeed() {
    // You could calculate actual speed from consecutive position updates
    // For now just return a placeholder
    return "Active";
  }

  /// **Show Snack Bar for Messages**
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// **Calculate estimated arrival time**
  String _calculateEstimatedArrival() {
    if (!_isDriverOnline) return "Driver offline";
    
    try {
      // Calculate distance between driver and user
      double distanceInMeters = Geolocator.distanceBetween(
        _driverPosition.latitude,
        _driverPosition.longitude,
        _userPosition.latitude,
        _userPosition.longitude
      );
      
      // Convert to kilometers
      double distanceInKm = distanceInMeters / 1000;
      
      // Assume average speed of 30 km/h in city
      double estimatedTimeInHours = distanceInKm / 30;
      
      // Convert to minutes
      int estimatedMinutes = (estimatedTimeInHours * 60).round();
      
      if (estimatedMinutes < 1) {
        return "Less than a minute";
      } else if (estimatedMinutes < 60) {
        return "$estimatedMinutes minutes";
      } else {
        int hours = estimatedMinutes ~/ 60;
        int minutes = estimatedMinutes % 60;
        return "$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}";
      }
    } catch (e) {
      return "Unable to calculate";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Track Bus ${_busData?['numberPlate'] ?? ''}"),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showDirectionsPanel ? Icons.directions_off : Icons.directions),
            onPressed: () {
              setState(() {
                _showDirectionsPanel = !_showDirectionsPanel;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _userPosition, zoom: 15),
            onMapCreated: (controller) {
              setState(() {
                _mapController = controller;
                
                // Center on user's location immediately after map is created
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_userPosition, 15),
                );
              });
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Driver status indicator
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isDriverOnline ? Colors.green : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isDriverOnline
                                ? "Driver is online - Real-time tracking active"
                                : "Driver is offline - Showing planned route",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isDriverOnline ? Colors.green.shade700 : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_busData != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.directions_bus, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            "Bus: ${_busData!['numberPlate'] ?? 'Unknown'}",
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.route, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${_busData!['source'] ?? 'Unknown'} → ${_busData!['destination'] ?? 'Unknown'}",
                              style: TextStyle(color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (_isDriverOnline) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              "Updated just now",
                              style: TextStyle(color: AppColors.primary, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              "Driver Location: ${_driverPosition.latitude.toStringAsFixed(6)}, ${_driverPosition.longitude.toStringAsFixed(6)}",
                              style: TextStyle(color: AppColors.primary, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              "Estimated arrival: $_estimatedArrival",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ],
                ),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Directions",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.primary),
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
          await _getCurrentLocation();
          
          if (_isDriverOnline) {
            _getDirectionsToDriver();
          } else {
            _drawBusRoute(); // This will also get directions to nearest stop
          }
          
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
      color: step.isWaypoint ? AppColors.primary.withOpacity(0.1) : null,
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
                color: step.isWaypoint 
                    ? AppColors.primary 
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: step.isWaypoint ? Colors.white : Colors.black87,
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
                      color: AppColors.primary,
                    ),
                  ),
                  if (step.distance.isNotEmpty || step.duration.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${step.distance} ${step.distance.isNotEmpty && step.duration.isNotEmpty ? '· ' : ''}${step.duration}",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary.withOpacity(0.7),
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
