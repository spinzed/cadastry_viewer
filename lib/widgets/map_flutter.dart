import 'dart:convert';

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
    required int timesPressed,
    required CadastryLayerColor cadastryColor,
    required void Function(CadastryData data) onParcelDataChanged,
  })  : _center = center,
        _overlayEnabled = overlayEnabled,
        _pressedNum = timesPressed,
        _cadastryColor = cadastryColor,
        _onParcelDataChanged = onParcelDataChanged,
        super(key: key);

  final LatLng _center;
  final bool _overlayEnabled;
  final int _pressedNum;
  final CadastryLayerColor _cadastryColor;
  final Function(CadastryData data) _onParcelDataChanged;

  @override
  State<MapFlutter> createState() => _MapFlutterState();
}

class _MapFlutterState extends State<MapFlutter> {
  String myCadastryToken = dotenv.get("PERSONAL_CADASTRY_TOKEN");
  String officialCadastryToken = dotenv.get("OFFICIAL_CADASTRY_TOKEN");
  String mapboxToken = dotenv.get("MAPBOX_PRIVATE_TOKEN");
  String geoportalToken = dotenv.get("GEOPORTAL_TOKEN");
  int tileSize = 2000;

  List<LayerOptions> layers = [];
  List<Polygon> renderedPolygons = [];

  late TileLayerOptions mapboxLayer;
  late TileLayerOptions cadastryLayerOrange;
  late TileLayerOptions cadastryLayerBlack;
  late TileLayerOptions zupanijaLayer;

  TileLayerOptions? _shownCadastryLayer;

  MapController mapController = MapController();
  int oldPressesNum = -1;

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
        ],
        //layers: [
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
    if (oldPressesNum == -1 || oldPressesNum != widget._pressedNum) {
      if (cadastryLayerShown()) renderParcelAtCenter();
      oldPressesNum = widget._pressedNum;
    }

    return FlutterMap(
      options: MapOptions(
        center: widget._center,
        maxZoom: 18.499,
      ),
      mapController: mapController,
      layers: layers,
    );
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
}
