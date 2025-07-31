import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io'; // Required for File type for image upload
import 'package:firebase_storage/firebase_storage.dart'; // Required for image upload

import '../models/user_model.dart'; // Assuming you have a UserModel for signup

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // For image upload

  // Sign in with email and password and return user details with role/approval
  Future<Map<String, dynamic>> signInWithRole(String email, String password, String selectedRole) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        if (selectedRole == "driver") {
          DocumentSnapshot driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
          if (driverDoc.exists) {
            return {'user': user, 'role': 'driver', 'isApproved': true, 'errorMessage': null};
          } else {
            await _auth.signOut(); // Sign out if driver record not found
            return {'user': null, 'role': null, 'isApproved': false, 'errorMessage': "Driver record not found!"};
          }
        } else { // Admin or Student
          DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            String role = userDoc['role'];
            bool isApproved = userDoc['isApproved'] ?? false;

            if (role == selectedRole) {
              if (role == 'student' && !isApproved) {
                await _auth.signOut(); // Sign out if student not approved
                return {'user': null, 'role': null, 'isApproved': false, 'errorMessage': "Access denied! Your account is not approved yet."};
              }
              return {'user': user, 'role': role, 'isApproved': isApproved, 'errorMessage': null};
            } else {
              await _auth.signOut(); // Sign out if role mismatch
              return {'user': null, 'role': null, 'isApproved': false, 'errorMessage': "Invalid role selected!"};
            }
          } else {
            await _auth.signOut(); // Sign out if user record not found
            return {'user': null, 'role': null, 'isApproved': false, 'errorMessage': "User not found. Please sign up first."};
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      return {'user': null, 'role': null, 'isApproved': false, 'errorMessage': e.message ?? "Login failed. Please try again."};
    } catch (e) {
      print("SignInWithRole error: $e");
      return {'user': null, 'role': null, 'isApproved': false, 'errorMessage': "An unexpected error occurred: $e"};
    }
    return {'user': null, 'role': null, 'isApproved': false, 'errorMessage': "Login failed."};
  }

  // Register a new user and save their data to Firestore
  Future<User?> registerUser({
    required String email,
    required String password,
    required String name,
    required String registrationNo,
    required String phoneNo,
    required String role,
    File? imageFile,
    String? whoAreYou,
    File? receiptImageFile,
  }) async {
    try {
      // 1. Create Firebase Auth user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        String? imageUrl;
        String? receiptUrl;
        // 2. Upload image if provided
        if (imageFile != null) {
          final storageRef = _storage.ref()
              .child('user_images')
              .child('${user.uid}.jpg'); // Use UID for unique image name
          await storageRef.putFile(imageFile);
          imageUrl = await storageRef.getDownloadURL();
        }
        // Upload receipt image if provided
        if (receiptImageFile != null) {
          final receiptRef = _storage.ref()
              .child('user_receipts')
              .child('${user.uid}.jpg');
          await receiptRef.putFile(receiptImageFile);
          receiptUrl = await receiptRef.getDownloadURL();
        }

        // 3. Create UserModel and save to Firestore
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          role: role,
          whoAreYou: whoAreYou,
          isApproved: false, // New users are generally not approved by default
          password: password, // Store hashed password if needed, but Firebase handles auth
          registrationNo: registrationNo,
          phoneNo: phoneNo,
          busId: null,
          busNumber: null,
          imageUrl: imageUrl,
          receiptUrl: receiptUrl,
        );
        await _firestore.collection('users').doc(user.uid).set(newUser.toJson());
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw e; // Re-throw to be caught by the UI layer
    } catch (e) {
      print("Register user error: $e");
      throw Exception("Failed to register user: $e"); // Generic exception
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e; // Re-throw to be caught by the UI layer
    } catch (e) {
      print("Reset password error: $e");
      throw Exception("Failed to send reset link: $e");
    }
  }
}
