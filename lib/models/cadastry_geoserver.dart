import "package:latlong2/latlong.dart";
import "package:proj4dart/proj4dart.dart";

class CadastryData {
  List<CadastryFeature> features;

  CadastryData({this.features = const []});

  factory CadastryData.fromJson(List<dynamic> json) {
    CadastryData gs = CadastryData(features: []);

    for (var feat in json) {
      gs.features.add(CadastryFeature.fromJson(feat));
    }

    return gs;
  }
}

class CadastryFeature {
  String id;
  String geometryName;
  List<LatLng> geometry;
  CadastryProperties properties;

  CadastryFeature({
    this.id = "",
    this.geometryName = "",
    this.geometry = const [],
    this.properties = const CadastryProperties(),
  });

  factory CadastryFeature.fromJson(Map<String, dynamic> json) {
    return CadastryFeature(
      id: json["id"],
      geometryName: json["geometry_name"],
      geometry: parseCoords(json["geometry"]["coordinates"][0]),
      properties: CadastryProperties.fromJson(json["properties"]),
    );
  }
}

class CadastryProperties {
  final int cesticaId;
  final String broj;
  final String podbroj;
  final int katastarskaOpcinaId;
  final String brojCestice; // broj/podbroj
  final int povrsinaAtributna;
  final String opisnaAdresa;
  final DateTime? datum;
  final int maticniBrojKo;

  const CadastryProperties({
    this.cesticaId = -1,
    this.broj = "",
    this.podbroj = "",
    this.katastarskaOpcinaId = -1,
    this.brojCestice = "",
    this.povrsinaAtributna = -1,
    this.opisnaAdresa = "",
    this.datum,
    this.maticniBrojKo = -1,
  });

  factory CadastryProperties.fromJson(Map<String, dynamic> json) {
    return CadastryProperties(
      cesticaId: json["CESTICA_ID"],
      broj: json["BROJ"],
      podbroj: json["PODBROJ"] ?? "-1",
      katastarskaOpcinaId: json["KATASTARSKA_OPCINA_ID"],
      brojCestice: json["BROJ_CESTICE"],
      povrsinaAtributna: json["POVRSINA_ATRIBUTNA"],
      opisnaAdresa: json["OPISNA_ADRESA"],
      datum: DateTime.parse(json["DATUM"]),
      maticniBrojKo: json["MATICNI_BROJ_KO"],
    );
  }
}

List<LatLng> parseCoords(List<dynamic> coords) {
  List<LatLng> rj = [];

  for (var element in coords) {
    double x = element[0] is int ? element[0].toDouble() : element[0],
        y = element[1] is int ? element[1].toDouble() : element[1];

    rj.add(epsg3765to4326(x, y));
  }

  return rj;
}

LatLng epsg3765to4326(double x, double y) {
  var projSrc = Projection.get("EPSG:3765")!;
  var projDest = Projection.get("EPSG:4326")!;

  var transformed = projSrc.transform(projDest, Point(x: x, y: y));

  return LatLng(transformed.y, transformed.x);
}
