import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class MapMapbox extends StatefulWidget {
  const MapMapbox({
    Key? key,
    required CameraPosition center,
    required bool overlayEnabled,
  })  : _center = center,
        _overlayEnabled = overlayEnabled,
        super(key: key);

  final CameraPosition _center;
  final bool _overlayEnabled;

  @override
  State<MapMapbox> createState() => _MapMapboxState();
}

class _MapMapboxState extends State<MapMapbox> {
  bool _addedLayer = false;
  final _key = GlobalKey();

  late MapboxMapController mapController;

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;

    mapController.addListener(() {
      debugPrint("change");
    });
  }

  void _onButtonPress() {
    if (_addedLayer) return;

    // vars
    //var width = _key.currentContext?.size?.width.round(); // 700
    //var height = _key.currentContext?.size?.height.round(); // 450
    var width = 1000;
    var height = 1000;
    var token = dotenv.get("PERSONAL_CADASTRY_TOKEN");
    var standard = "EPSG:3857";
    //var standard = "EPSG:4258";
    //var standard = "EPSG:4328";

    //const MINX = "42.40100004035178";
    //const MINY = "13.285948819776737";
    //const MAXX = "46.57331946653396";
    //const MAXY = "19.425000000022646";

    mapController.getVisibleRegion().then((bounds) {
      //var minx = bounds.southwest.latitude;
      //var miny = bounds.southwest.longitude;
      //var maxx = bounds.northeast.latitude;
      //var maxy = bounds.northeast.longitude;

      var url =
          //"https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?service=WMS&version=1.3.0&request=GetMap&layers=cp:CP.CadastralParcel&styles=&bbox=$minx,$miny,$maxx,$maxy&width=$width&height=$height&srs=$standard&format=image/png&transparent=true&token=$token";
          "https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?service=WMS&version=1.3.0&request=GetMap&layers=cp:CP.CadastralParcel&styles=&bbox={bbox-epsg-3857}&width=$width&height=$height&srs=$standard&format=image/png&transparent=true&token=$token";

      debugPrint(url);

      mapController.addSource(
        "kat",
        RasterSourceProperties(tiles: [
          //"https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?token=381bd6203bdf8b4252a48bb047e174ae881f10b504156220363d503eaa3afda4"),
          //"https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?service=WMS&version=1.3.0&request=GetMap&layers=cp:CP.CadastralParcel&styles=&bbox=502195,5012777,502292,5012835&width=700&height=450&srs=EPSG:3765&format=image/jpeg&token=381bd6203bdf8b4252a48bb047e174ae881f10b504156220363d503eaa3afda4",
          //"https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?service=WMS&version=1.3.0&request=GetMap&layers=cp:CP.CadastralParcel&styles=&bbox=502195,5012777,502292,5012835&width=$width&height=$height&srs=EPSG:3765&format=image/jpeg&token=381bd6203bdf8b4252a48bb047e174ae881f10b504156220363d503eaa3afda4",
          //"https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?service=WMS&version=1.3.0&request=GetMap&layers=cp:CP.CadastralParcel&styles=&bbox=502195,5012777,502292,5012835&width=$width&height=$height&srs=EPSG:3765&format=image/png&transparent=true&token=381bd6203bdf8b4252a48bb047e174ae881f10b504156220363d503eaa3afda4",
          url
        ]),
      );

      //mapController.addLayer(sourceId, layerId, properties);
      mapController.addLayer("kat", "kat", const RasterLayerProperties());
      //    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      //_counter++;
      //});
      setState(() {
        _addedLayer = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: MapboxMap(
              accessToken: dotenv.get("MAPBOX_PUBLIC_TOKEN"),
              styleString: "mapbox://styles/mapbox/streets-v11",
              initialCameraPosition: widget._center,
              myLocationEnabled: false,
              onMapCreated: _onMapCreated,
              onCameraTrackingChanged: (a) {
                debugPrint("update");
              },
              onMapIdle: () {
                debugPrint("onMapIdle");
              },
              onCameraIdle: () {
                debugPrint("onCameraIdle");
              },
              onMapClick: (point, latlng) {
                debugPrint("onMapClick");
              },
            ),
          ),
        ]),
      ),
    );
  }
}
