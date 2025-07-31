class DriverModel {
  String? uid;
  String? id;
  String? name;
  String? email;
  String? phone;
  String? address;
  String? busId;
  String? busNumberPlate;
  String? busSource;
  String? busDestination;
  String? imageUrl;
  bool? isPrimary;
  String? optionalDriverId;
  String? primaryDriverId;

  DriverModel({
    this.uid,
    this.id,
    this.name,
    this.email,
    this.phone,
    this.address,
    this.busId,
    this.busNumberPlate,
    this.busSource,
    this.busDestination,
    this.imageUrl,
    this.isPrimary,
    this.optionalDriverId,
    this.primaryDriverId,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'busId': busId,
        'busNumberPlate': busNumberPlate,
        'busSource': busSource,
        'busDestination': busDestination,
        'imageUrl': imageUrl,
        'isPrimary': isPrimary,
        'optionalDriverId': optionalDriverId,
        'primaryDriverId': primaryDriverId,
      };

  factory DriverModel.fromJson(Map<String, dynamic> json) => DriverModel(
        uid: json['uid'],
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        address: json['address'],
        busId: json['busId'],
        busNumberPlate: json['busNumberPlate'],
        busSource: json['busSource'],
        busDestination: json['busDestination'],
        imageUrl: json['imageUrl'],
        isPrimary: json['isPrimary'],
        optionalDriverId: json['optionalDriverId'],
        primaryDriverId: json['primaryDriverId'],
      );
} 