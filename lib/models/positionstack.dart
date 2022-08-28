class PositionstackData {
  List<PositionstackEntry> data;

  PositionstackData({this.data = const []});

  factory PositionstackData.fromJson(Map<String, dynamic> json) {
    PositionstackData gs = PositionstackData(data: []);

    for (var entry in json["data"]) {
      gs.data.add(PositionstackEntry.fromJson(entry));
    }

    return gs;
  }
}

class PositionstackEntry {
  double latitude;
  double longitude;
  String type;
  String name;
  String street;
  String number;
  String postalCode;
  int confidence;
  String region;
  String country;

  PositionstackEntry({
    this.latitude = 0,
    this.longitude = 0,
    this.type = "",
    this.name = "",
    this.street = "",
    this.number = "",
    this.postalCode = "",
    this.confidence = 0,
    this.region = "",
    this.country = "",
  });

  factory PositionstackEntry.fromJson(Map<String, dynamic> json) {
    return PositionstackEntry(
      latitude: json["latitude"],
      longitude: json["longitude"],
      type: json["type"],
      name: json["name"],
      street: json["street"] ?? "",
      number: json["number"] ?? "",
      postalCode: json["postal_code"] ?? "",
      confidence: json["confidence"] ?? -1,
      region: json["region"] ?? "",
      country: json["country"] ?? "",
    );
  }
}
