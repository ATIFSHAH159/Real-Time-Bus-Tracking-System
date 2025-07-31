import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/bus_model.dart';
import '../Services/bus_service.dart';
import '../theme/app_colors.dart';
import '../Services/Notification_services.dart';

class AddBusScreen extends StatefulWidget {
  final BusModel? bus;

  const AddBusScreen({super.key, this.bus});

  @override
  _AddBusScreenState createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  final TextEditingController _numberPlateController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final List<TextEditingController> _stopControllers = [];
  
  // Schedule controllers
  final TextEditingController _morningDepartureController = TextEditingController();
  final TextEditingController _eveningDepartureController = TextEditingController();

  final BusService _busService = BusService();
  bool _isDrawingRoute = false;
  
  // Google Maps variables
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(34.1558, 73.2194); // Default to Abbottabad
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routeCoordinates = [];
  
  // Marker selection state
  String _selectedMarkerType = 'source'; // 'source', 'destination', or 'stop'
  final List<LatLng> _stopPoints = [];
  
  // String constants
  static const String _apiKey = 'AIzaSyAopwURP-RbAZXSJgAP9GazKct9ILADHgc'; // Your Google Maps API key

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    
    if (widget.bus != null) {
      // Edit mode - populate fields
      _numberPlateController.text = widget.bus!.numberPlate ?? '';
      _capacityController.text = widget.bus!.capacity?.toString() ?? '';
      _sourceController.text = widget.bus!.source ?? '';
      _destinationController.text = widget.bus!.destination ?? '';
      
      // Populate stop controllers from bus stops
      if (widget.bus!.stops != null && widget.bus!.stops!.isNotEmpty) {
        for (String stop in widget.bus!.stops!) {
          final controller = TextEditingController(text: stop);
          _stopControllers.add(controller);
        }
      }
      
      // Set schedule if available
      if (widget.bus!.schedule != null) {
        _morningDepartureController.text = widget.bus!.schedule!['morning'] ?? '';
        _eveningDepartureController.text = widget.bus!.schedule!['evening'] ?? '';
      }
      
      // Attempt to recreate route if source and destination are coordinates
      _tryRecreateRoute();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers to avoid memory leaks
    for (var controller in _stopControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final location = Location();
    
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }
    
    PermissionStatus permissionStatus = await location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return;
      }
    }
    
    LocationData locationData = await location.getLocation();
    if (mounted) {
      setState(() {
        _center = LatLng(locationData.latitude!, locationData.longitude!);
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // Add a marker based on the current selected marker type
  void _addMarker(LatLng position) {
    // Find a proper name/address for this location
    _getAddressFromLatLng(position).then((address) {
      setState(() {
        if (_selectedMarkerType == 'source') {
          // Remove old source marker if it exists
          _markers.removeWhere((marker) => marker.markerId.value == 'source');
          
          _markers.add(
            Marker(
              markerId: const MarkerId('source'),
              position: position,
              infoWindow: InfoWindow(title: 'Source', snippet: address),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
          _sourceController.text = address;
          
          // Automatically switch to destination after selecting source
          _selectedMarkerType = 'destination';
        } else if (_selectedMarkerType == 'destination') {
          // Remove old destination marker if it exists
          _markers.removeWhere((marker) => marker.markerId.value == 'destination');
          
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: position,
              infoWindow: InfoWindow(title: 'Destination', snippet: address),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
          _destinationController.text = address;
          
          // Automatically switch to stop after selecting destination
          _selectedMarkerType = 'stop';
        } else if (_selectedMarkerType == 'stop') {
          // Add a new stop marker
          int stopIndex = _stopPoints.length;
          _stopPoints.add(position);
          
          _markers.add(
            Marker(
              markerId: MarkerId('stop$stopIndex'),
              position: position,
              infoWindow: InfoWindow(title: 'Stop ${stopIndex + 1}', snippet: address),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            ),
          );
          
          // Create a new controller for this stop
          final stopController = TextEditingController(text: address);
          _stopControllers.add(stopController);
        }
        
        // If we have source and destination, try to plot the route
        if (_sourceMarker != null && _destinationMarker != null) {
          _calculateRoute();
        }
      });
    });
  }
  
  // Helper to get the source marker
  Marker? get _sourceMarker {
    try {
      return _markers.firstWhere((marker) => marker.markerId.value == 'source');
    } catch (e) {
      return null;
    }
  }
  
  // Helper to get the destination marker
  Marker? get _destinationMarker {
    try {
      return _markers.firstWhere((marker) => marker.markerId.value == 'destination');
    } catch (e) {
      return null;
    }
  }
  
  // Get stop markers in order
  List<Marker> get _stopMarkers {
    return _markers.where((marker) => 
      marker.markerId.value.startsWith('stop')).toList()
      ..sort((a, b) => int.parse(a.markerId.value.substring(4))
        .compareTo(int.parse(b.markerId.value.substring(4))));
  }
  
  // Clear all markers and routes
  void _clearRoute() {
    setState(() {
      _markers.clear();
      _polylines.clear();
      _routeCoordinates.clear();
      _stopPoints.clear();
      _sourceController.clear();
      _destinationController.clear();
      
      // Dispose existing controllers
      for (var controller in _stopControllers) {
        controller.dispose();
      }
      _stopControllers.clear();
      
      _selectedMarkerType = 'source';
    });
  }
  
  // Get address from coordinates using Google's Geocoding API
  Future<String> _getAddressFromLatLng(LatLng position) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      return "${position.latitude}, ${position.longitude}";
    }
    
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_apiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    
    return "${position.latitude}, ${position.longitude}";
  }
  
  // Draw a simple route when API key not available or API call fails
  void _drawSimpleRoute() {
    if (_sourceMarker == null || _destinationMarker == null) return;
    
    setState(() {
      _polylines.clear();
      List<LatLng> points = [_sourceMarker!.position];
      
      // Add stop points in order
      for (var marker in _stopMarkers) {
        points.add(marker.position);
      }
      
      points.add(_destinationMarker!.position);
      
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          visible: true,
          points: points,
          width: 4,
          color: Colors.blue,
        ),
      );
    });
  }
  
  // Draw the route from calculated coordinates
  void _drawRouteFromCoordinates() {
    setState(() {
      _polylines.clear();
      if (_routeCoordinates.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            visible: true,
            points: _routeCoordinates,
            width: 4,
            color: Colors.blue,
          ),
        );
      }
    });
  }
  
  // Decode a polyline string into coordinates
  void _decodePolyline(String encoded) {
    int index = 0;
    int len = encoded.length;
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

      LatLng point = LatLng(lat / 1E5, lng / 1E5);
      _routeCoordinates.add(point);
    }
  }

  Future<void> _saveBus() async {
    if (_numberPlateController.text.isEmpty ||
        _capacityController.text.isEmpty ||
        _sourceController.text.isEmpty ||
        _destinationController.text.isEmpty ||
        _morningDepartureController.text.isEmpty ||
        _eveningDepartureController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields!")),
      );
      return;
    }

    try {
      // Create schedule map
      Map<String, String> schedule = {
        'morning': _morningDepartureController.text,
        'evening': _eveningDepartureController.text,
      };

      // Get stops from controllers, filtering out empty ones
      List<String> stops = _stopControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      BusModel bus = BusModel(
        id: widget.bus?.id,
        numberPlate: _numberPlateController.text,
        capacity: int.tryParse(_capacityController.text) ?? 0,
        currentCapacity: widget.bus?.currentCapacity ?? 0,
        source: _sourceController.text,
        destination: _destinationController.text,
        stops: stops,
        schedule: schedule,
        assignedStudents: widget.bus?.assignedStudents ?? [],
        driverId: widget.bus?.driverId,
      );

      if (widget.bus == null) {
        // Add new bus
        await _busService.addBus(bus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bus added successfully!")),
        );
        // Send notification to all users and drivers
        print('Calling notifyAllUsers for bus add');
        await NotificationServices().notifyAllUsers(
          "New Bus Added",
          "A new bus has been added to the system busnumber: ${bus.numberPlate}",
          {"type": "bus_add", "busId": bus.numberPlate ?? ""}
        );
      } else {
        // Update existing bus
        await _busService.updateBus(bus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bus updated successfully!")),
        );
        // Send notification to all users and drivers
        print('Calling notifyAllUsers for bus update');
        await NotificationServices().notifyAllUsers(
          "Bus Route Updated",
          "A bus route has been updated by the admin. bus number plate: ${bus.numberPlate}",
          {"type": "bus_update", "busId": bus.numberPlate ?? ""}
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  // Try to recreate route if coordinates are stored
  void _tryRecreateRoute() {
    if (widget.bus?.source == null || widget.bus?.destination == null) return;
    
    // Check if source is in coordinate format (lat, lng)
    final sourceCoordinates = _extractCoordinates(widget.bus!.source!);
    final destCoordinates = _extractCoordinates(widget.bus!.destination!);
    
    if (sourceCoordinates != null && destCoordinates != null) {
      // Add source marker
      _addMarkerFromCoordinates(sourceCoordinates, 'source', 'Source');
      
      // Add destination marker
      _addMarkerFromCoordinates(destCoordinates, 'destination', 'Destination');
      
      // Add stop markers if available
      if (widget.bus!.stops != null && widget.bus!.stops!.isNotEmpty) {
        for (int i = 0; i < widget.bus!.stops!.length; i++) {
          final stopCoordinates = _extractCoordinates(widget.bus!.stops![i]);
          if (stopCoordinates != null) {
            _addMarkerFromCoordinates(stopCoordinates, 'stop$i', 'Stop ${i+1}');
            _stopPoints.add(stopCoordinates);
          }
        }
      }
      
      // Calculate route
      _calculateRoute();
    }
  }
  
  // Helper to add marker directly from coordinates
  void _addMarkerFromCoordinates(LatLng coordinates, String id, String title) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(id),
          position: coordinates,
          infoWindow: InfoWindow(title: title),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            id == 'source' 
              ? BitmapDescriptor.hueGreen 
              : id == 'destination' 
                ? BitmapDescriptor.hueRed 
                : BitmapDescriptor.hueYellow
          ),
        ),
      );
    });
  }
  
  // Extract coordinates from string like "lat, lng" or address
  LatLng? _extractCoordinates(String text) {
    final RegExp coordRegex = RegExp(r'(\-?\d+(\.\d+)?),\s*(\-?\d+(\.\d+)?)');
    final match = coordRegex.firstMatch(text);
    
    if (match != null) {
      try {
        final lat = double.parse(match.group(1)!);
        final lng = double.parse(match.group(3)!);
        return LatLng(lat, lng);
      } catch (e) {
        print('Error parsing coordinates: $e');
      }
    }
    
    return null;
  }

  // Calculate route using Google's Directions API
  Future<void> _calculateRoute() async {
    if (_sourceMarker == null || _destinationMarker == null) {
      return;
    }
    
    setState(() {
      _isDrawingRoute = true;
    });
    
    try {
      // If no API key or default key, show warning and use simple route
      if (_apiKey.isEmpty || _apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please configure a valid Google Maps API key to show actual routes',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        _drawSimpleRoute();
        setState(() {
          _isDrawingRoute = false;
        });
        return;
      }
      
      // Build waypoints string for the stops
      String waypointsStr = '';
      if (_stopMarkers.isNotEmpty) {
        waypointsStr = '&waypoints=optimize:true';
        for (var marker in _stopMarkers) {
          waypointsStr += '|${marker.position.latitude},${marker.position.longitude}';
        }
      }
      
      // Encode the URL parameters properly
      final origin = '${_sourceMarker!.position.latitude},${_sourceMarker!.position.longitude}';
      final destination = '${_destinationMarker!.position.latitude},${_destinationMarker!.position.longitude}';
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${Uri.encodeComponent(origin)}'
        '&destination=${Uri.encodeComponent(destination)}'
        '$waypointsStr'
        '&key=$_apiKey'
      );
      
      print('Requesting directions from: $url'); // Debug print
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('The request timed out');
        },
      );
      
      print('Response status code: ${response.statusCode}'); // Debug print
      print('Response body: ${response.body}'); // Debug print
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          _routeCoordinates.clear();
          
          // Process each route
          for (var route in data['routes']) {
            // Process each leg of the route
            for (var leg in route['legs']) {
              // Process each step of the leg
              for (var step in leg['steps']) {
                // Decode the polyline points for this step
                _decodePolyline(step['polyline']['points']);
              }
            }
          }
          
          // Draw the route with the decoded coordinates
          _drawRouteFromCoordinates();
          
          // Fit map to show the entire route
          _fitMapToRoute();
        } else {
          print('Directions API error: ${data['status']}');
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error getting route: ${data['status']}. Using straight line route.',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          // Fall back to simple route if API returns an error
          _drawSimpleRoute();
        }
      } else {
        print('Error getting directions: ${response.statusCode}');
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error connecting to Google Maps. Using straight line route.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        // Fall back to simple route if API call fails
        _drawSimpleRoute();
      }
    } on TimeoutException {
      print('Request timed out');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request timed out. Using straight line route.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      _drawSimpleRoute();
    } catch (e) {
      print('Error calculating route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error calculating route: $e. Using straight line route.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      _drawSimpleRoute();
    } finally {
      setState(() {
        _isDrawingRoute = false;
      });
    }
  }

  // Fit map to show the entire route
  void _fitMapToRoute() {
    if (_mapController == null || _routeCoordinates.isEmpty) return;
    
    // Create bounds that include all route points
    double minLat = _routeCoordinates.first.latitude;
    double maxLat = _routeCoordinates.first.latitude;
    double minLng = _routeCoordinates.first.longitude;
    double maxLng = _routeCoordinates.first.longitude;
    
    for (var point in _routeCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    
    // Add padding to the bounds
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );
    
    // Animate camera to show the entire route
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bus == null ? 'Add Bus' : 'Edit Bus'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAccent,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // API Key Notice
                if (_apiKey.isEmpty || _apiKey == 'YOUR_GOOGLE_MAPS_API_KEY')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            const Text(
                              'Missing Google Maps API Key',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Routes will be displayed as straight lines. To show actual roads, please add your Google Maps API key in the code.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                
                // Bus Details Card
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
                          'Bus Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _numberPlateController,
                          'Number Plate',
                          Icons.directions_bus,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _capacityController,
                          'Capacity',
                          Icons.people,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Route Details Card
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
                          'Route Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _sourceController,
                          'Source',
                          Icons.location_on,
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _destinationController,
                          'Destination',
                          Icons.location_on,
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Stops',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // List of stop fields
                        ..._stopControllers.asMap().entries.map((entry) {
                          int index = entry.key;
                          var controller = entry.value;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller,
                                    'Stop ${index + 1}',
                                    Icons.place,
                                    readOnly: true,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: AppColors.error),
                                  onPressed: () {
                                    setState(() {
                                      _stopControllers.removeAt(index);
                                      if (index < _stopPoints.length) {
                                        _stopPoints.removeAt(index);
                                      }
                                      _markers.removeWhere((marker) => marker.markerId.value == 'stop$index');
                                      
                                      for (int i = index; i < _stopPoints.length; i++) {
                                        _markers.removeWhere((marker) => marker.markerId.value == 'stop${i+1}');
                                        _markers.add(
                                          Marker(
                                            markerId: MarkerId('stop$i'),
                                            position: _stopPoints[i],
                                            infoWindow: InfoWindow(title: 'Stop ${i + 1}', snippet: _stopControllers[i].text),
                                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                                          ),
                                        );
                                      }
                                      
                                      if (_sourceMarker != null && _destinationMarker != null) {
                                        _calculateRoute();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        
                        // Add Stop button
                        if (_selectedMarkerType == 'stop')
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add_location),
                              label: const Text('Tap map to add a stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent.withOpacity(0.2),
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Map Card
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
                          'Route Map',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 350,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              GoogleMap(
                                onMapCreated: _onMapCreated,
                                initialCameraPosition: CameraPosition(
                                  target: _center,
                                  zoom: 13,
                                ),
                                markers: _markers,
                                polylines: _polylines,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: true,
                                onTap: (LatLng position) {
                                  _addMarker(position);
                                },
                              ),
                              if (_isDrawingRoute)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: FloatingActionButton(
                                  onPressed: _clearRoute,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.refresh, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap on the map to add source, destination, and stops.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Schedule Card
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
                          'Bus Schedule',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                _morningDepartureController,
                                'Morning Time',
                                Icons.access_time,
                                readOnly: true,
                                onTap: () async {
                                  TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (pickedTime != null) {
                                    _morningDepartureController.text = pickedTime.format(context);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                _eveningDepartureController,
                                'Evening Time',
                                Icons.access_time,
                                readOnly: true,
                                onTap: () async {
                                  TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (pickedTime != null) {
                                    _eveningDepartureController.text = pickedTime.format(context);
                                  }
                                },
                              ),
                            ),
                          ],
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
                    onPressed: _saveBus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: Text(
                      widget.bus == null ? 'Add Bus' : 'Update Bus',
                      style: const TextStyle(
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
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      onTap: onTap,
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