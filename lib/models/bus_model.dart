class BusModel {
  String? id;
  String? numberPlate;
  int? capacity;
  int? currentCapacity;
  String? source;
  String? destination;
  List<String>? stops;
  Map<String, String>? schedule;
  List<String>? assignedStudents;
  String? driverId;
  String? primaryDriverId;
  String? optionalDriverId;

  BusModel({
    this.id,
    this.numberPlate,
    this.capacity,
    this.currentCapacity = 0,
    this.source,
    this.destination,
    this.stops,
    this.schedule,
    this.assignedStudents = const [],
    this.driverId,
    this.primaryDriverId,
    this.optionalDriverId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'numberPlate': numberPlate,
        'capacity': capacity,
        'currentCapacity': currentCapacity,
        'source': source,
        'destination': destination,
        'stops': stops,
        'schedule': schedule,
        'assignedStudents': assignedStudents,
        'driverId': driverId,
        'primaryDriverId': primaryDriverId,
        'optionalDriverId': optionalDriverId,
      };

  factory BusModel.fromJson(Map<String, dynamic> json) => BusModel(
        id: json['id'],
        numberPlate: json['numberPlate'],
        capacity: json['capacity'],
        currentCapacity: json['currentCapacity'] ?? 0,
        source: json['source'],
        destination: json['destination'],
        stops: json['stops'] != null ? List<String>.from(json['stops']) : [],
        schedule: json['schedule'] != null ? Map<String, String>.from(json['schedule']) : {},
        assignedStudents: json['assignedStudents'] != null ? List<String>.from(json['assignedStudents']) : [],
        driverId: json['driverId'],
        primaryDriverId: json['primaryDriverId'],
        optionalDriverId: json['optionalDriverId'],
      );
} 