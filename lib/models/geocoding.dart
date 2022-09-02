class GeocodingData {
  List<GeocodingEntry> data;

  GeocodingData({this.data = const []});

  factory GeocodingData.fromMapboxJson(Map<String, dynamic> json) {
    GeocodingData gs = GeocodingData(data: []);

    for (var entry in json["features"]) {
      gs.data.add(GeocodingEntry.fromMapboxJson(entry));
    }

    return gs;
  }

  factory GeocodingData.fromPositionstackJson(Map<String, dynamic> json) {
    GeocodingData gs = GeocodingData(data: []);

    for (var entry in json["data"]) {
      gs.data.add(GeocodingEntry.fromPositionstackJson(entry));
    }

    return gs;
  }
}

class GeocodingEntry {
  double latitude;
  double longitude;
  String type;
  String name;
  String street;
  String number;
  String postalCode;
  double confidence;
  String region;
  String place;

  GeocodingEntry({
    this.latitude = 0,
    this.longitude = 0,
    this.type = "",
    this.name = "",
    this.street = "",
    this.number = "",
    this.postalCode = "",
    this.confidence = 0,
    this.region = "",
    this.place = "",
  });

  factory GeocodingEntry.fromPositionstackJson(Map<String, dynamic> json) {
    return GeocodingEntry(
      latitude: json["latitude"],
      longitude: json["longitude"],
      type: json["type"],
      name: json["name"],
      street: json["street"] ?? "",
      number: json["number"] ?? "",
      postalCode: json["postal_code"] ?? "",
      confidence: double.parse(json["confidence"].toString()),
      place: json["region"] ?? "",
      region: json["region"] ?? "",
    );
  }

  factory GeocodingEntry.fromMapboxJson(Map<String, dynamic> json) {
    String postalCode = "", place = "", region = "";
    for (var entry in json["context"]) {
      if (entry["id"] is String && entry["id"].contains("postcode")) {
        postalCode = entry["text"];
      } else if (entry["id"] is String && entry["id"].contains("place")) {
        place = entry["text"];
      } else if (entry["id"] is String && entry["id"].contains("region")) {
        region = entry["text"];
      }
    }

    String type = json["place_type"][0];
    String name = json["text"];

    if (type == "address" && json["address"] != null) {
      name += " ${json["address"]}";
    }

    return GeocodingEntry(
      latitude: json["center"][1],
      longitude: json["center"][0],
      type: type,
      name: name,
      street: json["text"] ?? "",
      number: json["address"] ?? "",
      postalCode: postalCode,
      confidence: double.parse(json["relevance"].toString()),
      place: place,
      region: region,
    );
  }

  String placeAndCode() {
    String fin = place != "" ? place : region;

    if (postalCode != "") {
      fin += ", $postalCode";
    }
    return fin;
  }
}
