import 'dart:async';
import 'dart:convert';

import 'package:cadastry_viewer/utils/shared_preferences.dart';
import 'package:cadastry_viewer/widgets/address_search.dart';
import 'package:cadastry_viewer/widgets/custom_dialog.dart';
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
    required LatLng initialPosition,
    required double initialZoom,
    required bool overlayEnabled,
    required CadastryLayerColor cadastryColor,
    required LatLng? location,
    required void Function(CadastryData data) onParcelDataChanged,
    required void Function() onParcelShown,
    required void Function() onEnableParcel,
    required void Function() onEnableLocation,
  })  : _initialPosition = initialPosition,
        _initialZoom = initialZoom,
        _overlayEnabled = overlayEnabled,
        _cadastryColor = cadastryColor,
        _location = location,
        _onParcelDataChanged = onParcelDataChanged,
        _onParcelShown = onParcelShown,
        _onEnableParcel = onEnableParcel,
        _onEnableLocation = onEnableLocation,
        super(key: key);

  final LatLng _initialPosition;
  final double _initialZoom;
  final bool _overlayEnabled;
  final CadastryLayerColor _cadastryColor;
  final LatLng? _location;
  final Function(CadastryData data) _onParcelDataChanged;
  final Function() _onParcelShown;
  final Function() _onEnableParcel;
  final Function() _onEnableLocation;

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
  double? currentRotation;

  Marker? currentLocation;
  bool _locationAtCenter = false;
  bool _pointerDown = false;
  bool _locationWriteable = true; // used to throttle position caching
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
    layers.add(zupanijaLayer);
    layers.add(MarkerLayerOptions(markers: renderedMarkers));
    layers.add(PolygonLayerOptions(polygons: renderedPolygons));
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
    updateLocation();

    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          center: widget._initialPosition,
          zoom: widget._initialZoom,
          maxZoom: 18.499,
          onTap: (a, b) => setState(() => timesMapPressed++),
          onMapCreated: (c) => mapController = c,
          onPointerDown: (a, b) => setState(() => _pointerDown = true),
          onPointerUp: (a, b) => setState(() => _pointerDown = false),
          onPositionChanged: (a, b) {
            WidgetsBinding.instance.addPostFrameCallback((d) {
              savePosition();
              setState(() {
                currentRotation = mapController.rotation;
                _locationAtCenter = _pointerDown ? false : _locationAtCenter;
              });
            });
          },
          maxBounds:
              LatLngBounds(LatLng(40.001, 12.005), LatLng(48.936, 20.8525)),
        ),
        mapController: mapController,
        layers: layers,
      ),
      // bottom right buttons
      Container(
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.only(bottom: 20, right: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          verticalDirection: VerticalDirection.up,
          children: [
            // parcel select button
            FloatingActionButton(
              backgroundColor: Colors.blue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              onPressed: () {
                if (widget._overlayEnabled) {
                  renderParcelAtCenter();
                  widget._onParcelShown();
                } else {
                  showEnableOverlayDialog();
                }
              },
              tooltip: "View Parcel Data",
              child: const Icon(Icons.not_listed_location,
                  semanticLabel: "View Parcel Data"),
            ),
            const SizedBox(height: 18),
            // go to location button
            FloatingActionButton(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () {
                if (widget._location != null) {
                  focusOnLocation(widget._location!);
                  setState(() => _locationAtCenter = true);
                } else {
                  showLocationDialog();
                }
              },
              tooltip: "Go to Your Location",
              child: Icon(
                  widget._location == null
                      ? Icons.location_disabled
                      : _locationAtCenter
                          ? Icons.my_location
                          : Icons.location_searching,
                  semanticLabel: "Go to Your Location"),
            ),
          ],
        ),
      ),
      // center icon
      const Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Icon(Icons.not_listed_location, color: Colors.white, size: 24),
        ),
      ),
      // compass
      Padding(
        padding: EdgeInsets.only(
            right: 15.0, top: 100.0 + MediaQuery.of(context).viewPadding.top),
        child: GestureDetector(
          onTap: () => rotate(0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Transform.rotate(
                angle: degToRadian(currentRotation ?? 0.0),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Transform.rotate(
                      angle: degToRadian(-45),
                      child: const Icon(
                        Icons.explore,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(top: 1),
                      child: const Text(
                        "N",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // search bar
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
              controller: mapController,
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

    layers.add(getSelectedCadastryLayer());
    setState(() => _shownCadastryLayer = getSelectedCadastryLayer());
  }

  void hideCadastryLayer() {
    if (!cadastryLayerShown()) return;

    layers.remove(_shownCadastryLayer);
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
    final zoomTween = Tween(begin: mapController.zoom, end: 16.5);

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

  void rotate(double angle) {
    if (mapController.rotation == angle) return;

    final tween = Tween(begin: mapController.rotation, end: angle);
    final cnt = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final anim = CurvedAnimation(parent: cnt, curve: Curves.easeOutQuart);

    cnt.addListener(() {
      mapController.rotate(tween.evaluate(anim));
      setState(() => currentRotation = tween.evaluate(anim));
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

  void savePosition() {
    if (!_locationWriteable) {
      return;
    }
    Timer(const Duration(milliseconds: 1000), () {
      setState(() {
        _locationWriteable = true;
        savePositionNoThrottle();
      });
    });
    savePositionNoThrottle();
    setState(() => _locationWriteable = false);
  }

  void savePositionNoThrottle() {
    prefs?.setDouble("lastLat", mapController.center.latitude);
    prefs?.setDouble("lastLng", mapController.center.longitude);
    prefs?.setDouble("lastZoom", mapController.zoom);
  }

  void showEnableOverlayDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return CustomDialog(
          title: const Text("Cadastry Visibility is Off"),
          content: const [
            Text(
                "You were attempting to get details of a parcel, but the parcel visibilty is turned off."),
            Text("Would you like to show the parcel layer first?"),
          ],
          actions: [
            TextButton(
              child: const Text("Yes", style: TextStyle(color: Colors.white)),
              onPressed: () {
                widget._onEnableParcel();
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child: const Text("No", style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  void showLocationDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return CustomDialog(
          title: const Text("Location Services are Off"),
          content: const [
            Text(
                "You were trying to go to your location, but location services are turned off."),
            Text("Enable location services and try again."),
          ],
          actions: [
            TextButton(
              child: const Text("Enable Location",
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                widget._onEnableLocation();
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child:
                  const Text("Dismiss", style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }
}
