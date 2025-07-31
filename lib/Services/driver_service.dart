import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/driver_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new driver
  Future<String> addDriver(DriverModel driver, String password) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: driver.email!,
        password: password,
      );
      
      // Set the UID from Auth
      driver.uid = userCredential.user!.uid;
      
      // Save to Firestore
      await _firestore.collection('drivers').doc(driver.uid).set(driver.toJson());
      
      return driver.uid!;
    } catch (e) {
      throw Exception('Failed to add driver: $e');
    }
  }

  // Get a driver by ID
  Future<DriverModel?> getDriver(String driverId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('drivers').doc(driverId).get();
      if (doc.exists) {
        return DriverModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get driver: $e');
    }
  }

  // Update driver details
  Future<void> updateDriver(DriverModel driver) async {
    try {
      await _firestore.collection('drivers').doc(driver.uid).update(driver.toJson());
    } catch (e) {
      throw Exception('Failed to update driver: $e');
    }
  }

  // Delete a driver
  Future<void> deleteDriver(String driverId) async {
    try {
      // Get driver data first to check if auth user needs to be deleted
      DocumentSnapshot driverDoc = await _firestore.collection('drivers').doc(driverId).get();
      if (!driverDoc.exists) {
        throw Exception('Driver not found');
      }
      
      // Get the driver's bus ID before deleting
      Map<String, dynamic> driverData = driverDoc.data() as Map<String, dynamic>;
      String? busId = driverData['busId'];
      
      // Remove driver from the bus in Firestore, but only if the bus doc exists
      if (busId != null && busId.isNotEmpty) {
        print("Removing driver from bus: $busId");
        final busDocRef = _firestore.collection('buses').doc(busId);
        final busDoc = await busDocRef.get();
        if (busDoc.exists) {
          await busDocRef.update({
            'driverId': null
          });
        } else {
          print('Bus document $busId does not exist, skipping update.');
        }
      }
      
      // Delete from firestore
      await _firestore.collection('drivers').doc(driverId).delete();
      
      // Try to delete the auth user if applicable
      try {
        User? currentUser = _auth.currentUser;
        // We need admin SDK to delete other users, which is not available in client apps
        // This code works if the user is deleting themselves
        if (currentUser != null && currentUser.uid == driverId) {
          await currentUser.delete();
        }
      } catch (authError) {
        // Auth deletion might fail, but we still deleted from Firestore
        print('Auth deletion error: $authError');
      }
    } catch (e) {
      throw Exception('Failed to delete driver: $e');
    }
  }

  // Get all drivers
  Stream<QuerySnapshot> getAllDrivers() {
    return _firestore.collection('drivers').snapshots();
  }

  // Get drivers by bus
  Stream<QuerySnapshot> getDriversByBus(String busId) {
    return _firestore
        .collection('drivers')
        .where('busId', isEqualTo: busId)
        .snapshots();
  }
} 