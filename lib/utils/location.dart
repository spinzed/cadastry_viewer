import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';

bool enabled = false;
bool _setupDone = false;
Location location = Location();

Future<void> setupLocation() async {
  if (_setupDone) return;

  PermissionStatus permissionGranted;
  //LocationData locationData;

  enabled = await location.serviceEnabled();
  if (!enabled) {
    enabled = await location.requestService();
    if (!enabled) return;
  }

  permissionGranted = await location.hasPermission();
  if (permissionGranted == PermissionStatus.denied) {
    permissionGranted = await location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) {
      return;
    }
  }

  _setupDone = true;
  enabled = true;

  //locationData = await location.getLocation();
}

Future<LatLng> getLocation() async {
  if (!enabled) return LatLng(0, 0);
  LocationData data = await location.getLocation();

  return LatLng(data.latitude ?? 0, data.longitude ?? 0);
}
