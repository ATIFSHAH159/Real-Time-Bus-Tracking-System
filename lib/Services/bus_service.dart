import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';

class BusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new bus
  Future<String> addBus(BusModel bus) async {
    DocumentReference docRef = await _firestore.collection('buses').add(bus.toJson());
    await _firestore.collection('buses').doc(docRef.id).update({'id': docRef.id});
    return docRef.id;
  }

  // Update an existing bus
  Future<void> updateBus(BusModel bus) async {
    await _firestore.collection('buses').doc(bus.id).update(bus.toJson());
  }

  // Delete a bus
  Future<void> deleteBus(String busId) async {
    await _firestore.collection('buses').doc(busId).delete();
  }

  // Get a single bus by ID
  Future<BusModel?> getBus(String busId) async {
    DocumentSnapshot doc = await _firestore.collection('buses').doc(busId).get();
    if (doc.exists) {
      return BusModel.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Get all buses
  Stream<QuerySnapshot> getAllBuses() {
    return _firestore.collection('buses').snapshots();
  }

  // Assign a student to a bus
  Future<void> assignStudentToBus(String busId, String studentId) async {
    // Get the current bus
    BusModel? bus = await getBus(busId);
    if (bus != null) {
      // Check if the bus has capacity
      if (bus.currentCapacity! < bus.capacity!) {
        List<String> assignedStudents = bus.assignedStudents ?? [];
        if (!assignedStudents.contains(studentId)) {
          assignedStudents.add(studentId);
          // Update the bus with the new student and increment capacity
          await _firestore.collection('buses').doc(busId).update({
            'assignedStudents': assignedStudents,
            'currentCapacity': FieldValue.increment(1)
          });
        }
      } else {
        throw Exception('Bus is at full capacity');
      }
    }
  }

  // Remove a student from a bus
  Future<void> removeStudentFromBus(String busId, String studentId) async {
    BusModel? bus = await getBus(busId);
    if (bus != null) {
      List<String> assignedStudents = bus.assignedStudents ?? [];
      if (assignedStudents.contains(studentId)) {
        assignedStudents.remove(studentId);
        // Update the bus with the student removed and decrement capacity
        await _firestore.collection('buses').doc(busId).update({
          'assignedStudents': assignedStudents,
          'currentCapacity': FieldValue.increment(-1)
        });
      }
    }
  }

  // Get all buses with available capacity
  Stream<QuerySnapshot> getAvailableBuses() {
    return _firestore.collection('buses')
        .snapshots();
    // Note: We'll filter in the UI since we can't directly compare two fields in Firestore
  }
} 