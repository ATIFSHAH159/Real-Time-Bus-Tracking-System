import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add user to Firestore
  Future<void> addUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
  }

  // Get user by UID
  Future<UserModel?> getUser(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Update user approval status (for admin)
  Future<void> updateUserApproval(String uid, bool isApproved) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'isApproved': isApproved});
  }

  // Fetch pending student requests
  Stream<QuerySnapshot> getPendingStudents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('isApproved', isEqualTo: false)
        .snapshots();
  }
}
