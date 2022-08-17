import 'package:proj4dart/proj4dart.dart';

void registerProjections() {
  Projection.add("EPSG:3765",
      "+proj=tmerc +lat_0=0 +lon_0=16.5 +k=0.9999 +x_0=500000 +y_0=0 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs");
}
