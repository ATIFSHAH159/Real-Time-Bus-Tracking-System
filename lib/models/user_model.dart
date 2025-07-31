import 'package:firebase_auth/firebase_auth.dart';
import 'package:bus_tracking_system/services/notification_services.dart';

class UserModel {
  String? uid;
  String? email;
  String? name;
  String? role;
  String? whoAreYou;
  bool? isApproved;
  String? password;
  String? registrationNo;
  String? phoneNo;
  String? imageUrl; // Profile image
  String? busId; // ID of assigned bus
  String? busNumber; // Number plate of assigned bus
  String? receiptUrl; // Receipt image URL

  UserModel({
    this.uid,
    this.email,
    this.name,
    this.role,
    this.whoAreYou,
    this.isApproved,
    this.password,
    this.registrationNo,
    this.phoneNo,
    this.imageUrl,
    this.busId,
    this.busNumber,
    this.receiptUrl,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        'role': role,
        'whoAreYou': whoAreYou,
        'isApproved': isApproved,
        'password': password,
        'registrationNo': registrationNo,
        'phoneNo': phoneNo,
        'imageUrl': imageUrl,
        'busId': busId,
        'busNumber': busNumber,
        'receiptUrl': receiptUrl,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'],
        email: json['email'],
        name: json['name'],
        role: json['role'],
        whoAreYou: json['whoAreYou'],
        isApproved: json['isApproved'],
        password: json['password'],
        registrationNo: json['registrationNo'],
        phoneNo: json['phoneNo'],
        imageUrl: json['imageUrl'],
        busId: json['busId'],
        busNumber: json['busNumber'],
        receiptUrl: json['receiptUrl'],
      );
}
