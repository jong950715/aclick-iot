class EventRecord {
  final DateTime datetime;
  final String lat;
  final String lng;

  EventRecord({required this.datetime, required this.lat, required this.lng});

  Map<String, dynamic> toJson() {
    return {'datetime': datetime.millisecondsSinceEpoch ~/ 1000, 'lat': lat, 'lng': lng};
  }

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      datetime: DateTime.fromMillisecondsSinceEpoch(json['datetime'] * 1000),
      lat: json['lat'],
      lng: json['lng'],
    );
  }
}
