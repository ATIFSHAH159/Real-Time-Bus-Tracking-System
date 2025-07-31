import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../Screens/Student_Map_Screen.dart';
import '../Screens/feedbackScreen.dart';
import '../theme/app_colors.dart';
import 'student_profile.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FeedbackScreen(isDriver: false),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  List<Map<String, dynamic>> _buses = [];
  Map<String, Map<String, dynamic>> _busSeatStatus = {};
  Map<String, StreamSubscription> _seatStatusSubscriptions = {};
  int _seatStatus = 0;
  StreamSubscription? _seatStatusSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadBuses();
    _listenToSeatStatus();
  }
  
  @override
  void dispose() {
    _seatStatusSubscription?.cancel();
    _seatStatusSubscriptions.values.forEach((subscription) => subscription.cancel());
    super.dispose();
  }

  void _listenToBusSeatStatus(String busId) {
    if (_seatStatusSubscriptions.containsKey(busId)) return;

    final subscription = _database
        .child('seatStatus')
        .child(busId)
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _busSeatStatus[busId] = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });

    _seatStatusSubscriptions[busId] = subscription;
  }

  int _getOccupiedSeatsCount(String busId) {
    final seatStatus = _busSeatStatus[busId];
    if (seatStatus == null) return 0;
    return seatStatus.values.where((seat) => seat == true).length;
  }
  
  Future<void> _loadBuses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      QuerySnapshot busesSnapshot = await _firestore.collection('buses').get();
      
      setState(() {
        _buses = busesSnapshot.docs
            .map((doc) => {
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id,
                })
            .toList();
        _isLoading = false;
      });

      for (var bus in _buses) {
        _listenToBusSeatStatus(bus['id']);
      }
    } catch (e) {
      print('Error loading buses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenToSeatStatus() {
    _seatStatusSubscription = _database.child('seatStatus').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _seatStatus = int.tryParse(event.snapshot.value.toString()) ?? 0;
        });
      }
    });
  }

  void _openBusDetail(Map<String, dynamic> bus) async {
    DataSnapshot snapshot = await _database.child('seatStatus').get();
    int seatStatus = int.tryParse(snapshot.value?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bus['numberPlate'] ?? 'Unknown Bus',
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '$seatStatus/${bus['capacity'] ?? 0} seats',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Route Information', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              _buildRouteCard(bus),
              const SizedBox(height: 20),
              const Text('Schedule', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              _buildScheduleInfo(bus),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => StudentMapScreen(),
                      settings: RouteSettings(arguments: bus['id']),
                    )
                  );
                },
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: const Text('Track This Bus', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRouteCard(Map<String, dynamic> bus) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.trip_origin, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('From', style: TextStyle(color: Colors.grey)),
                      Text(
                        bus['source'] ?? 'Unknown Source',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_on, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('To', style: TextStyle(color: Colors.grey)),
                      Text(
                        bus['destination'] ?? 'Unknown Destination',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (bus['stops'] != null && (bus['stops'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              ExpansionTile(
                title: const Text('Stops'),
                initiallyExpanded: true,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (bus['stops'] as List)
                      .where((stop) => stop is String && stop.isNotEmpty)
                      .length,
                    itemBuilder: (context, index) {
                      final validStops = (bus['stops'] as List)
                        .where((stop) => stop is String && stop.isNotEmpty)
                        .toList();
                        
                      if (index < validStops.length) {
                        final stopText = validStops[index].toString();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.accent.withOpacity(0.1),
                            child: Text('${index + 1}', style: TextStyle(color: AppColors.primary)),
                          ),
                          title: Text(
                            stopText, 
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          dense: true,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildScheduleInfo(Map<String, dynamic> bus) {
    Map<String, dynamic>? schedule = bus['schedule'] as Map<String, dynamic>?;
    
    if (schedule == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No schedule available'),
        ),
      );
    }
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildScheduleRow(Icons.wb_sunny, 'Morning Departure', schedule['morning'] ?? 'Not Available'),
            const Divider(),
            _buildScheduleRow(Icons.nights_stay, 'Evening Departure', schedule['evening'] ?? 'Not Available'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScheduleRow(IconData icon, String title, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.gradientAccent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Available Buses'),
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
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buses.isEmpty
                ? Center(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_bus,
                              size: 64,
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No buses available right now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadBuses,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBuses,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _buses.length,
                      itemBuilder: (context, index) {
                        final bus = _buses[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _openBusDetail(bus),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.directions_bus,
                                            color: AppColors.primary,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                bus['numberPlate'] ?? 'Unknown Bus',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${bus['source'] ?? 'Unknown'} to ${bus['destination'] ?? 'Unknown'}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$_seatStatus/${bus['capacity'] ?? 0}',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              ((bus['schedule'] ?? {})['morning'] ?? 'N/A'),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppColors.primary.withOpacity(0.3),
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'View Details',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => StudentMapScreen(),
                                                  settings: RouteSettings(arguments: bus['id']),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.location_on, size: 16, color: Colors.white),
                                            label: const Text('Track', style: TextStyle(color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
