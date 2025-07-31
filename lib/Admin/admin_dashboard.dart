import 'package:bus_tracking_system/Admin/add_bus.dart';
import 'package:bus_tracking_system/Admin/driver_management.dart';
import 'package:bus_tracking_system/Admin/bus_management.dart';
import 'package:bus_tracking_system/Admin/manage_users.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:bus_tracking_system/models/user_model.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _showRequests = false;
  bool _showFeedback = false;
  String? _adminImageUrl;
  String? _adminName;
  String? _adminEmail;
  Map<String, int> _stats = {
    'buses': 0,
    'drivers': 0,
    'users': 0,
    'feedback': 0,
    'pendingRequests': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchAdminProfile();
  }

  Future<void> _fetchAdminProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            _adminImageUrl = userDoc.data()?['imageUrl'];
            _adminName = userDoc.data()?['name'];
            _adminEmail = userDoc.data()?['email'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching admin profile: $e');
    }
  }

  Future<void> _fetchStats() async {
    try {
      // Fetch buses count
      final busesSnapshot = await FirebaseFirestore.instance.collection('buses').get();
      final driversSnapshot = await FirebaseFirestore.instance.collection('drivers').get();
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final feedbackSnapshot = await FirebaseFirestore.instance.collection('feedbacks').get();
      final pendingRequestsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isApproved', isEqualTo: false)
          .get();

      setState(() {
        _stats = {
          'buses': busesSnapshot.docs.length,
          'drivers': driversSnapshot.docs.length,
          'users': usersSnapshot.docs.length,
          'feedback': feedbackSnapshot.docs.length,
          'pendingRequests': pendingRequestsSnapshot.docs.length,
        };
      });
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _fetchStats,
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _showFeedback
          ? _buildFeedbackList()
          : _showRequests
              ? _buildRequestsList()
              : _buildHomeScreen(),
    );
  }

  Widget _buildHomeScreen() {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                    AppColors.secondary,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.8),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              backgroundImage: _adminImageUrl != null
                                  ? NetworkImage(_adminImageUrl!)
                                  : null,
                              child: _adminImageUrl == null
                                  ? Icon(
                                      Icons.admin_panel_settings,
                                      size: 30,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${_adminName ?? 'Admin'}',
                                  style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                                  'Manage bus tracking system',
                        style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                                    letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Stats Grid
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildStatCard(
                    Icons.directions_bus,
                    'Buses',
                    _stats['buses'].toString(),
                    AppColors.dashboardCard1,
                    gradient: AppColors.gradientDashboard1,
                    onTap: () => _showBusDetails(),
                  ),
                  _buildStatCard(
                    Icons.person_outline,
                    'Drivers',
                    _stats['drivers'].toString(),
                    AppColors.dashboardCard2,
                    gradient: AppColors.gradientDashboard2,
                    onTap: () => _showDriverDetails(),
                  ),
                  _buildStatCard(
                    Icons.people_outline,
                    'Users',
                    _stats['users'].toString(),
                    AppColors.dashboardCard3,
                    gradient: AppColors.gradientDashboard3,
                    onTap: () => _showUserDetails(),
                  ),
                  _buildStatCard(
                    Icons.feedback_outlined,
                    'Feedback',
                    _stats['feedback'].toString(),
                    AppColors.dashboardCard4,
                    gradient: AppColors.gradientDashboard4,
                    onTap: () {
                      setState(() {
                        _showFeedback = true;
                        _showRequests = false;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Pending Requests Card
            if (_stats['pendingRequests']! > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showRequests = true;
                        _showFeedback = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.error.withOpacity(0.1),
                            AppColors.error.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.pending_actions,
                              color: AppColors.error,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_stats['pendingRequests']} Pending Requests',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Click to review student registration requests',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                            Icons.arrow_forward_ios,
                              color: AppColors.error,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Drivers & Assigned Buses Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientCard,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.directions_bus, color: AppColors.primary, size: 28),
                            const SizedBox(width: 10),
                            Text('Drivers & Assigned Buses',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Text('No drivers found.', style: TextStyle(color: AppColors.textSecondary));
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              separatorBuilder: (context, idx) => const Divider(height: 18, color: Colors.black12),
                              itemBuilder: (context, idx) {
                                final driver = snapshot.data!.docs[idx].data() as Map<String, dynamic>;
                                return Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      backgroundImage: driver['imageUrl'] != null ? NetworkImage(driver['imageUrl']) : null,
                                      child: driver['imageUrl'] == null
                                          ? Icon(Icons.person, color: AppColors.primary)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(driver['name'] ?? 'No Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                              const SizedBox(width: 8),
                                              if ((driver['busNumberPlate'] != null && driver['busNumberPlate'].toString().isNotEmpty))
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.info.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'BUS: ${driver['busNumberPlate']}',
                                                    style: TextStyle(
                                                      color: AppColors.info,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text('Phone: ${driver['phoneNo'] ?? 'N/A'}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                          if (driver['busNumberPlate'] == null || driver['busNumberPlate'].toString().isEmpty)
                                            Text('No bus assigned', style: TextStyle(color: AppColors.warning, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    if (driver['busNumber'] != null)
                                      Icon(Icons.verified, color: AppColors.success, size: 20),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Manage Users Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientCard,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, color: AppColors.primary, size: 28),
                            const SizedBox(width: 10),
                            Text('Manage Users',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Text('No users found.', style: TextStyle(color: AppColors.textSecondary));
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              separatorBuilder: (context, idx) => const Divider(height: 18, color: Colors.black12),
                              itemBuilder: (context, idx) {
                                final user = snapshot.data!.docs[idx].data() as Map<String, dynamic>;
                                return Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      backgroundImage: user['imageUrl'] != null ? NetworkImage(user['imageUrl']) : null,
                                      child: user['imageUrl'] == null
                                          ? Icon(Icons.person, color: AppColors.primary)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(user['name'] ?? 'No Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                              const SizedBox(width: 8),
                                              if (user['role'] != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: user['role'] == 'student' ? AppColors.info.withOpacity(0.15) : AppColors.success.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    user['role'].toString().toUpperCase(),
                                                    style: TextStyle(
                                                      color: user['role'] == 'student' ? AppColors.info : AppColors.success,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text('Email: ${user['email'] ?? 'N/A'}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                          Text('Reg. No: ${user['registrationNo'] ?? 'N/A'}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: AppColors.error),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance.collection('users').doc(snapshot.data!.docs[idx].id).delete();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('User deleted successfully')),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Recent Activity Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.history, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildActivityItem(
                              Icons.person_add,
                              'New Student Registration',
                              '2 minutes ago',
                              AppColors.success,
                            ),
                            const Divider(height: 24),
                            _buildActivityItem(
                              Icons.directions_bus,
                              'Bus Route Updated',
                              '15 minutes ago',
                              AppColors.info,
                            ),
                            const Divider(height: 24),
                            _buildActivityItem(
                              Icons.feedback,
                              'New Feedback Received',
                              '1 hour ago',
                              AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                ),
              ),

            // Recent Feedback Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                            Icons.feedback_outlined,
                            color: AppColors.primary,
                          ),
                            ),
                            const SizedBox(width: 12),
                          const Text(
                            'Recent Feedback',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                            TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showFeedback = true;
                                _showRequests = false;
                              });
                            },
                              icon: Icon(
                                Icons.arrow_forward,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              label: Text(
                              'View All',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('feedbacks')
                          .orderBy('timestamp', descending: true)
                          .limit(3)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text('No feedback available'),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var feedback = snapshot.data!.docs[index].data()
                                as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: AppColors.primary.withOpacity(0.1),
                                          backgroundImage: feedback['userImageUrl'] != null
                                              ? NetworkImage(feedback['userImageUrl'])
                                              : null,
                                          child: feedback['userImageUrl'] == null
                                              ? Text(
                                                  feedback['userName']?.substring(0, 1).toUpperCase() ?? 'A',
                                                  style: TextStyle(color: AppColors.primary),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        feedback['userName'] ?? 'Anonymous',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                        '${feedback['rating']} ⭐',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                    feedback['feedback'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                    ),
                                  ),
                                  if (index < snapshot.data!.docs.length - 1)
                                      const Divider(height: 24),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String title,
    String value,
    Color color, {
    required LinearGradient gradient,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                ),
                child: Icon(
                  icon,
                    color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                  style: const TextStyle(
                    fontSize: 24,
                  fontWeight: FontWeight.bold,
                    color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBusDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BusManagement()),
    );
  }

  void _showDriverDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DriverManagement()),
    );
  }

  void _showUserDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('User Details'),
            backgroundColor: AppColors.primary,
            elevation: 0,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('isApproved', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var user = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: user['imageUrl'] != null
                            ? NetworkImage(user['imageUrl'])
                            : null,
                        child: user['imageUrl'] == null
                            ? Text(
                          user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                          style: TextStyle(color: AppColors.primary),
                              )
                            : null,
                      ),
                      title: Text(
                        user['name'] ?? 'No Name',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: ${user['email']}'),
                          Text('Registration No: ${user['registrationNo'] ?? 'N/A'}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: AppColors.error),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(snapshot.data!.docs[index].id)
                              .delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User deleted successfully')),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // **1️⃣ FETCH AND DISPLAY FEEDBACK FROM STUDENTS**
  Widget _buildFeedbackList() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Feedback'),
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
      body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedbacks')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    size: 64,
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No feedback submitted yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
              var feedback = snapshot.data!.docs[index].data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: feedback['userImageUrl'] != null
                                ? NetworkImage(feedback['userImageUrl'])
                                : null,
                            child: feedback['userImageUrl'] == null
                                ? Text(
                              feedback['userName']?.substring(0, 1).toUpperCase() ?? 'A',
                              style: TextStyle(color: AppColors.primary),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                Text(
                                  feedback['userName'] ?? 'Anonymous',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  feedback['userEmail'] ?? 'No Email',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${feedback['rating']}',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        feedback['feedback'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('feedbacks')
                        .doc(snapshot.data!.docs[index].id)
                        .delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Feedback deleted'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // **2️⃣ FETCH AND DISPLAY STUDENT REGISTRATION REQUESTS**
  Widget _buildRequestsList() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Requests'),
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
      body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isApproved', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 64,
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending student requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
              var user = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var userId = snapshot.data!.docs[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: user['imageUrl'] != null
                                ? NetworkImage(user['imageUrl'])
                                : null,
                            child: user['imageUrl'] == null
                                ? Text(
                              user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                              style: TextStyle(color: AppColors.primary),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user['email'] ?? 'No Email',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                            _buildInfoRow(
                              Icons.badge_outlined,
                              'Registration No',
                              user['registrationNo'] ?? 'N/A',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.phone_outlined,
                              'Phone',
                              user['phoneNo'] ?? 'N/A',
                            ),
                           const SizedBox(height: 8),
                           if (user['receiptUrl'] != null && user['receiptUrl'].toString().isNotEmpty)
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   'Receipt:',
                                   style: TextStyle(
                                     color: AppColors.primary,
                                     fontWeight: FontWeight.w600,
                                   ),
                                 ),
                                 const SizedBox(height: 6),
                                 GestureDetector(
                                   onTap: () {
                                     showDialog(
                                       context: context,
                                       builder: (context) => Dialog(
                                         child: InteractiveViewer(
                                           child: Image.network(
                                             user['receiptUrl'],
                                             fit: BoxFit.contain,
                                           ),
                                         ),
                                       ),
                                     );
                                   },
                                   child: Container(
                                     width: 120,
                                     height: 120,
                                     decoration: BoxDecoration(
                                       border: Border.all(color: AppColors.primary, width: 1.5),
                                       borderRadius: BorderRadius.circular(12),
                                     ),
                                     child: ClipRRect(
                                       borderRadius: BorderRadius.circular(12),
                                       child: Image.network(
                                         user['receiptUrl'],
                                         fit: BoxFit.cover,
                                         errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                       ),
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                          TextButton.icon(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                                  .delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Request rejected'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.close,
                              color: AppColors.error,
                            ),
                            label: Text(
                              'Reject',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                                  .update({'isApproved': true});
                        ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Request approved'),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // **3️⃣ ADMIN NAVIGATION DRAWER**
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: _adminImageUrl != null
                              ? NetworkImage(_adminImageUrl!)
                              : null,
                          child: _adminImageUrl == null
                              ? Icon(
                                  Icons.admin_panel_settings,
                                  size: 30,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _adminName ?? 'Admin',
                              style: const TextStyle(
                    color: Colors.white,
                                fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                            const SizedBox(height: 4),
                Text(
                              _adminEmail ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Administrator',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                  ),
                ),
              ],
            ),
          ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDrawerItem(
              icon: Icons.dashboard,
              title: 'Dashboard',
            onTap: () {
              setState(() {
                _showRequests = false;
                _showFeedback = false;
                _fetchStats();
              });
              Navigator.pop(context);
            },
          ),
            _buildDrawerItem(
              icon: Icons.person,
              title: 'Approve Student Requests',
            onTap: () {
              setState(() {
                _showRequests = true;
                _showFeedback = false;
              });
              Navigator.pop(context);
            },
          ),
            _buildDrawerItem(
              icon: Icons.feedback,
              title: 'View Student Feedback',
            onTap: () {
              setState(() {
                _showFeedback = true;
                _showRequests = false;
              });
              Navigator.pop(context);
            },
          ),
            _buildDrawerItem(
              icon: Icons.directions_bus,
              title: 'Manage Buses',
            onTap: () {
                setState(() {
                  _showRequests = false;
                  _showFeedback = false;
                });
              Navigator.pop(context);
              Navigator.push(
                context,
                  MaterialPageRoute(
                    builder: (context) => const BusManagement(),
                    fullscreenDialog: true,
                  ),
              );
            },
          ),
            _buildDrawerItem(
              icon: Icons.person_outline,
              title: 'Manage Drivers',
            onTap: () {
                setState(() {
                  _showRequests = false;
                  _showFeedback = false;
                });
              Navigator.pop(context);
              Navigator.push(
                context,
                  MaterialPageRoute(
                    builder: (context) => const DriverManagement(),
                    fullscreenDialog: true,
                  ),
              );
            },
          ),
            _buildDrawerItem(
              icon: Icons.people,
              title: 'Manage Users',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ManageUsers()),
              );
            },
          ),
            const Divider(height: 32),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              isLogout: true,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isLogout
              ? AppColors.error.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isLogout ? AppColors.error : AppColors.primary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? AppColors.error : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
