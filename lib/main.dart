import 'dart:async';

import 'package:cadastry_viewer/utils/location.dart' as location;
import 'package:cadastry_viewer/utils/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cadastry_viewer/utils/epsg_crs.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'models/cadastry_geoserver.dart';
import 'widgets/map_flutter.dart';

Future main() async {
  await dotenv.load();
  await setupSharedPrefs();
  registerProjections();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastry Viewer',
      theme: ThemeData(
        primarySwatch: Colors.brown,
      ),
      home: const MyHomePage(title: 'Cadastry Viewer'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _cadastryEnabled = prefs?.getBool("cadastryEnabled") ?? true;
  CadastryData? _parcelData;
  CadastryLayerColor _cadastryLayerColor =
      (prefs?.getString("cadastryLayerColor") ?? "orange") == "orange"
          ? CadastryLayerColor.orange
          : CadastryLayerColor.black;

  // location related
  bool _userLocationEnabled = false;
  LatLng? _location;
  late final LatLng _initialPos;
  late final double _initialZoom;
  StreamSubscription? locationSS;

  TextStyle style0 = TextStyle(
      fontSize: 24, color: Colors.grey.shade300, fontWeight: FontWeight.w300);
  TextStyle style1 = const TextStyle(
      fontSize: 15, color: Colors.white, fontWeight: FontWeight.w100);
  TextStyle style2 = TextStyle(
      fontSize: 22, color: Colors.grey.shade300, fontWeight: FontWeight.bold);

  StateSetter? setStateSheet;

  _MyHomePageState() {
    _initialPos = getInitialPosition();
    _initialZoom = getInitialZoom();
  }

  void dispatchBottomSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.brown,
        builder: (b) {
          return StatefulBuilder(builder: (context, setStateS) {
            setStateSheet = setStateS;
            var props = _parcelData?.features[0].properties;
            return Container(
              margin: const EdgeInsets.all(25),
              child: props == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text("Parcel Details", style: style0),
                      ),
                      Text("Cadastral Municipality", style: style1),
                      Text(props.maticniBrojKo.toString(), style: style2),
                      const Divider(color: Colors.grey),
                      Text("Cadastral Parcel Number", style: style1),
                      Text(props.brojCestice, style: style2),
                      const Divider(color: Colors.grey),
                      Text("Cadastral Parcel Address", style: style1),
                      Text(props.opisnaAdresa, style: style2),
                      const Divider(color: Colors.grey),
                      Text("Cadastral Parcel Area", style: style1),
                      Text("${props.povrsinaAtributna} m²", style: style2),
                    ]),
            );
          });
        });
  }

  void registerLocationListener() {
    locationSS = location.location.onLocationChanged.listen((data) {
      setState(() {
        _location = LatLng(data.latitude ?? 0, data.longitude ?? 0);
      });
    });
  }

  void disableLocation() {
    if (_userLocationEnabled) {
      locationSS?.cancel();
      setState(() {
        _userLocationEnabled = false;
        _location = null;
      });
    }
  }

  LatLng getInitialPosition() {
    return LatLng(
      prefs?.getDouble("lastLat") ?? 44.539039,
      prefs?.getDouble("lastLng") ?? 16.442823,
    );
  }

  double getInitialZoom() {
    return prefs?.getDouble("lastZoom") ?? 6.627313992993807;
  }

  void setCadastryEnabled(bool enabled) {
    if (_cadastryEnabled == enabled) return;

    prefs?.setBool("cadastryEnabled", enabled);
    setState(() => _cadastryEnabled = enabled);
  }

  void setLocationEnabled(bool enabled) async {
    if (!_userLocationEnabled) {
      await location.setupLocation();
      if (location.enabled) {
        //LatLng lok = await location.getLocation();
        registerLocationListener();
        setState(() => _userLocationEnabled = true);
      }
    } else {
      disableLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.brown.shade700.withOpacity(0.9),
        child: Theme(
            data: ThemeData().copyWith(
                unselectedWidgetColor: Colors.grey.shade400,
                iconTheme: const IconThemeData(color: Colors.white),
                textTheme: TextTheme(
                  bodyText1: const TextStyle(color: Colors.white),
                  bodyText2: TextStyle(color: Colors.grey.shade300),
                  //subtitle1: TextStyle(color: Colors.grey.shade300), // expanded tile main text
                  //subtitle2: TextStyle(color: Colors.grey.shade300),
                )),
            child: ListView(children: [
              SizedBox(
                height: 70,
                child: DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.5),
                  ),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Cadastry Viewer",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              Card(
                  color: Colors.brown,
                  child: CheckboxListTile(
                    title: const Text("Catastry Layer Enabled"),
                    subtitle: const Text("Toggle cadastry layer visibility"),
                    enableFeedback: true,
                    //secondary: const Icon(Icons.map),
                    value: _cadastryEnabled,
                    checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                    onChanged: (val) => setCadastryEnabled(!_cadastryEnabled),
                  )),
              Card(
                  color: Colors.brown,
                  child: ExpansionTile(
                    title: const Text("Parcel Border Color"),
                    subtitle: const Text("Change parcel rendering style"),
                    iconColor: Colors.blue.shade50,
                    collapsedIconColor: Colors.white,
                    textColor: Colors.blue.shade50,
                    //collapsedTextColor: Colors.white,
                    //leading: const Icon(Icons.palette),
                    initiallyExpanded: true,
                    children: [
                      RadioListTile<CadastryLayerColor>(
                        title: const Text("Orange"),
                        value: CadastryLayerColor.orange,
                        groupValue: _cadastryLayerColor,
                        onChanged: (val) {
                          prefs?.setString("cadastryLayerColor", "orange");
                          setState(() => _cadastryLayerColor = val!);
                        },
                      ),
                      RadioListTile<CadastryLayerColor>(
                        title: const Text("Black"),
                        value: CadastryLayerColor.black,
                        groupValue: _cadastryLayerColor,
                        onChanged: (val) {
                          prefs?.setString("cadastryLayerColor", "black");
                          setState(() => _cadastryLayerColor = val!);
                        },
                      ),
                    ],
                  )),
              Card(
                color: Colors.brown,
                child: CheckboxListTile(
                  title: const Text("Location Enabled"),
                  subtitle: const Text("Toggle phone location"),
                  value: _userLocationEnabled,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                  onChanged: (v) => setLocationEnabled(!_userLocationEnabled),
                ),
              ),
            ])),
      ),
      body: MapFlutter(
        initialPosition: _initialPos,
        initialZoom: _initialZoom,
        overlayEnabled: _cadastryEnabled,
        cadastryColor: _cadastryLayerColor,
        location: _location,
        onParcelDataChanged: (data) => setStateSheet!(() => _parcelData = data),
        onParcelShown: () {
          setState(() => _parcelData = null);
          dispatchBottomSheet();
        },
        onEnableParcel: () => setCadastryEnabled(true),
        onEnableLocation: () => setLocationEnabled(true),
      ),
    );
  }
}
