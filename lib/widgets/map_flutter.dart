import 'dart:convert';

import 'package:cadastry_viewer/widgets/address_search.dart';
import 'package:flutter/material.dart';
import 'package:cadastry_viewer/models/cadastry_geoserver.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

enum CadastryLayerColor { orange, black }

class MapFlutter extends StatefulWidget {
  const MapFlutter({
    Key? key,
    required LatLng center,
    required bool overlayEnabled,
    required int timesPressedParcel,
    required int timesPressedLocation,
    required CadastryLayerColor cadastryColor,
    required LatLng? location,
    required void Function(CadastryData data) onParcelDataChanged,
  })  : _center = center,
        _overlayEnabled = overlayEnabled,
        _pressedNumParcel = timesPressedParcel,
        _pressedNumLocation = timesPressedLocation,
        _cadastryColor = cadastryColor,
        _location = location,
        _onParcelDataChanged = onParcelDataChanged,
        super(key: key);

  final LatLng _center;
  final bool _overlayEnabled;
  final int _pressedNumParcel;
  final int _pressedNumLocation;
  final CadastryLayerColor _cadastryColor;
  final LatLng? _location;
  final Function(CadastryData data) _onParcelDataChanged;

  @override
  State<MapFlutter> createState() => _MapFlutterState();
}

class _MapFlutterState extends State<MapFlutter> with TickerProviderStateMixin {
  String myCadastryToken = dotenv.get("PERSONAL_CADASTRY_TOKEN");
  String officialCadastryToken = dotenv.get("OFFICIAL_CADASTRY_TOKEN");
  String mapboxToken = dotenv.get("MAPBOX_PRIVATE_TOKEN");
  String geoportalToken = dotenv.get("GEOPORTAL_TOKEN");
  int tileSize = 2000;

  List<LayerOptions> layers = [];
  List<Marker> renderedMarkers = [];
  List<Polygon> renderedPolygons = [];

  late TileLayerOptions mapboxLayer;
  late TileLayerOptions cadastryLayerOrange;
  late TileLayerOptions cadastryLayerBlack;
  late TileLayerOptions zupanijaLayer;

  TileLayerOptions? _shownCadastryLayer;

  MapController mapController = MapController();
  Marker? currentLocation;
  int oldPressesNumParcel = -1;
  int oldPressesNumLocation = -1;
  int timesMapPressed = 0;

  _MapFlutterState() {
    mapboxLayer = TileLayerOptions(
        urlTemplate:
            "https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}@2x.png?access_token=$mapboxToken",
        additionalOptions: {
          "accessToken": mapboxToken,
        });

    cadastryLayerOrange = TileLayerOptions(
      wmsOptions: WMSTileLayerOptions(
        baseUrl:
            //"https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?",
            "https://oss.uredjenazemlja.hr/OssWebServices/wms?",
        version: "1.3.0",
        transparent: true,
        styles: [
          "jis_cestice_kathr",
          "jis_cestice_nazivi_kathr",
          "jis_zgrade_kathr_2"
        ], //layers: [
        //  "cp:CP.CadastralParcel",
        //  "cp:CP.CadastralZoning"
        //],
        layers: ["oss:BZP_CESTICE", "oss:BZP_CESTICE", "oss:BZP_ZGRADE"],
        otherParameters: {
          "token": officialCadastryToken,
          "ratio": "2",
          "serverType": "geoserver",
        },
      ),
      tileSize: tileSize.toDouble(),
      backgroundColor: Colors.transparent,
    );

    cadastryLayerBlack = TileLayerOptions(
      wmsOptions: WMSTileLayerOptions(
        baseUrl:
            "https://oss.uredjenazemlja.hr/OssWebServices/inspireService/wms?",
        version: "1.3.0",
        transparent: true,
        layers: ["cp:CP.CadastralParcel", "cp:CP.CadastralZoning"],
        otherParameters: {
          "token": myCadastryToken,
          "ratio": "2",
        },
      ),
      tileSize: tileSize.toDouble(),
      backgroundColor: Colors.transparent,
    );

    zupanijaLayer = TileLayerOptions(
      wmsOptions: WMSTileLayerOptions(
        baseUrl: "https://geoportal.dgu.hr/services/sla/rpj/wms?",
        version: "1.3.0",
        layers: ["zupanija"],
        otherParameters: {
          "authKey": geoportalToken,
          "ratio": "2",
          "serverType": "geoserver",
        },
      ),
      tileSize: tileSize.toDouble(),
      backgroundColor: Colors.transparent,
    );

    layers.add(mapboxLayer);
    layers.add(MarkerLayerOptions(markers: renderedMarkers));
    layers.add(PolygonLayerOptions(polygons: renderedPolygons));
    //getPolygon([
    //  LatLng(43.5152045, 16.1085803),
    //  LatLng(43.5152017, 16.1085852),
    //  LatLng(43.5151671, 16.1086481),
    //  LatLng(43.5151606, 16.1086685),
    //  LatLng(43.5151676, 16.1087024),
    //  LatLng(43.5152041, 16.1087673),
    //  LatLng(43.5154459, 16.1086745),
    //  LatLng(43.5154131, 16.1086225),
    //  LatLng(43.5152949, 16.1085823),
    //  LatLng(43.5152043, 16.1085802),
    //])
  }

  @override
  Widget build(BuildContext context) {
    if (!cadastryLayerShown() && widget._overlayEnabled) {
      showCadastryLayer();
    }
    if (cadastryLayerShown() && !widget._overlayEnabled) {
      hideCadastryLayer();
    }
    if (cadastryLayerShown() &&
        getSelectedCadastryLayer() != _shownCadastryLayer) {
      hideCadastryLayer();
      showCadastryLayer();
    }
    if (oldPressesNumParcel != widget._pressedNumParcel) {
      if (cadastryLayerShown()) renderParcelAtCenter();
      oldPressesNumParcel = widget._pressedNumParcel;
    }
    if (oldPressesNumLocation != widget._pressedNumLocation) {
      if (widget._location != null) focusOnLocation(widget._location!);
      oldPressesNumLocation = widget._pressedNumLocation;
    }
    updateLocation();

    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          center: widget._center,
          maxZoom: 18.499,
          onTap: (a, b) => setState(() => timesMapPressed++),
          maxBounds:
              LatLngBounds(LatLng(42.101, 13.205), LatLng(46.836, 19.6525)),
        ),
        mapController: mapController,
        layers: layers,
      ),
      const Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Icon(Icons.not_listed_location, color: Colors.white, size: 24),
        ),
      ),
      Padding(
        padding:
            EdgeInsets.only(top: 25.0 + MediaQuery.of(context).viewPadding.top),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 40,
              child: IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              ),
            ),
            AddressSearch(
              width: MediaQuery.of(context).size.width * 0.75,
              onChooseLocation: (l) => focusOnLocation(l),
              onUnfocus: timesMapPressed,
            ),
          ],
        ),
      ),
    ]);
  }

  Polygon getPolygon(List<LatLng> points) {
    return Polygon(
      color: Colors.orange,
      isFilled: true,
      borderColor: Colors.red,
      borderStrokeWidth: 1,
      points: points,
    );
  }

  void showCadastryLayer() {
    if (cadastryLayerShown()) return;

    layers.addAll([getSelectedCadastryLayer(), zupanijaLayer]);

    setState(() => _shownCadastryLayer = getSelectedCadastryLayer());
  }

  void hideCadastryLayer() {
    if (!cadastryLayerShown()) return;

    layers.remove(_shownCadastryLayer);
    layers.remove(zupanijaLayer);

    setState(() => _shownCadastryLayer = null);
  }

  TileLayerOptions getSelectedCadastryLayer() {
    return widget._cadastryColor == CadastryLayerColor.orange
        ? cadastryLayerOrange
        : cadastryLayerBlack;
  }

  bool cadastryLayerShown() {
    return _shownCadastryLayer != null;
  }

  void renderParcelAtCenter() {
    getParcelAtCenter().then((parcel) {
      if (parcel.points.isEmpty) return;

      if (renderedPolygons.isNotEmpty) renderedPolygons.removeLast();
      renderedPolygons.add(parcel);

      setState(() {});
    });
  }

  Future<Polygon> getParcelAtCenter() async {
    LatLng c = mapController.center;
    var lng = c.longitude;
    var lat = c.latitude;

    var latMin = lat - 0.00005;
    var latMax = lat + 0.00005;
    var lngMin = lng - 0.00005;
    var lngMax = lng + 0.00005;

    var standard = "EPSG:4326";
    var url =
        "https://oss.uredjenazemlja.hr/OssWebServices/wms?token=$officialCadastryToken&SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&FORMAT=image/png8&TRANSPARENT=true&QUERY_LAYERS=oss:BZP_CESTICE,oss:BZP_CESTICE,oss:BZP_ZGRADE&LAYERS=oss:BZP_CESTICE,oss:BZP_CESTICE,oss:BZP_ZGRADE&STYLES=jis_cestice_kathr,jis_cestice_nazivi_kathr,jis_zgrade_kathr_2&tiled=false&ratio=2&serverType=geoserver&INFO_FORMAT=application/json&I=50&J=50&CRS=$standard&WIDTH=101&HEIGHT=101&BBOX=$lngMin,$latMin,$lngMax,$latMax";

    final resp = await http.get(Uri.parse(url));
    final feats = jsonDecode(utf8.decode(resp.bodyBytes))["features"];
    CadastryData f = CadastryData.fromJson(feats);

    if (f.features.isEmpty) return Polygon(points: []);

    debugPrint(url);
    debugPrint(f.features[0].geometry.toString());

    widget._onParcelDataChanged(f);
    return getPolygon(f.features[0].geometry);
  }

  void updateLocation() {
    if (widget._location == null && currentLocation == null) return;
    if (currentLocation != null) {
      renderedMarkers.remove(currentLocation);
      currentLocation = null;
    }
    if (widget._location != null) {
      currentLocation = Marker(
        point: widget._location!,
        builder: (b) => const Icon(Icons.radio_button_on, color: Colors.white),
      );
      renderedMarkers.add(currentLocation!);
    }
    setState(() {});
  }

  void focusOnLocation(LatLng location) {
    final latTween =
        Tween(begin: mapController.center.latitude, end: location.latitude);
    final lngTween =
        Tween(begin: mapController.center.longitude, end: location.longitude);
    final zoomTween = Tween(begin: mapController.zoom, end: 17.0);

    final cnt = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    final anim = CurvedAnimation(parent: cnt, curve: Curves.easeInOut);

    cnt.addListener(() {
      mapController.move(
          LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)),
          zoomTween.evaluate(anim));
    });

    anim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        cnt.dispose();
      } else if (status == AnimationStatus.dismissed) {
        cnt.dispose();
      }
    });

    cnt.forward();
  }
}
