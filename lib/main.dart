import 'dart:async';

import 'package:cadastry_viewer/utils/location.dart' as location;
import 'package:flutter/material.dart';
import 'package:cadastry_viewer/utils/epsg_crs.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'models/cadastry_geoserver.dart';
import 'widgets/map_flutter.dart';

Future main() async {
  await dotenv.load();
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
  bool _cadastryLayerEnabled = false;
  CadastryData? _parcelData;
  CadastryLayerColor _cadastryLayerColor = CadastryLayerColor.orange;
  // used to signal flutter map when show parcel data button has been pressed
  int _timesPressedParcel = 0;
  int _timesPressedLocation = 0;

  // location related
  bool _userLocationEnabled = false;
  ll.LatLng? _currentPos;
  StreamSubscription? locationSS;

  final CameraPosition _cnt =
      const CameraPosition(target: LatLng(43.5152271, 16.1088484), zoom: 15);

  TextStyle style0 = TextStyle(
      fontSize: 24, color: Colors.grey.shade300, fontWeight: FontWeight.w300);
  TextStyle style1 = const TextStyle(
      fontSize: 15, color: Colors.white, fontWeight: FontWeight.w100);
  TextStyle style2 = TextStyle(
      fontSize: 22, color: Colors.grey.shade300, fontWeight: FontWeight.bold);

  StateSetter? setStateSheet;

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
    locationSS = location.location.onLocationChanged.listen((data) => setState(
        () =>
            _currentPos = ll.LatLng(data.latitude ?? 0, data.longitude ?? 0)));
  }

  void disableLocation() {
    if (_userLocationEnabled) {
      locationSS?.cancel();
      setState(() {
        _userLocationEnabled = false;
        _currentPos = null;
      });
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
                    value: _cadastryLayerEnabled,
                    checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                    onChanged: (val) => setState(() {
                      _cadastryLayerEnabled = !_cadastryLayerEnabled;
                    }),
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
                        onChanged: (val) =>
                            setState(() => _cadastryLayerColor = val!),
                      ),
                      RadioListTile<CadastryLayerColor>(
                        title: const Text("Black"),
                        value: CadastryLayerColor.black,
                        groupValue: _cadastryLayerColor,
                        onChanged: (val) =>
                            setState(() => _cadastryLayerColor = val!),
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
                  onChanged: (last) async {
                    if (!_userLocationEnabled) {
                      await location.setupLocation();
                      if (location.enabled) {
                        //ll.LatLng lok = await location.getLocation();
                        registerLocationListener();
                        setState(() => _userLocationEnabled = true);
                      }
                    } else {
                      disableLocation();
                    }
                  },
                ),
              ),
            ])),
      ),
      body: MapFlutter(
        center: ll.LatLng(_cnt.target.latitude, _cnt.target.longitude),
        overlayEnabled: _cadastryLayerEnabled,
        timesPressedParcel: _timesPressedParcel,
        timesPressedLocation: _timesPressedLocation,
        cadastryColor: _cadastryLayerColor,
        location: _currentPos,
        onParcelDataChanged: (data) => setStateSheet!(() => _parcelData = data),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        verticalDirection: VerticalDirection.up,
        //shrinkWrap: true,
        children: [
          FloatingActionButton(
            //onPressed: () => setState(() => _timesPressed++),
            backgroundColor: Colors.blue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            onPressed: () {
              setState(() {
                _timesPressedParcel++;
                _parcelData = null;
              });
              if (!_cadastryLayerEnabled) return;
              dispatchBottomSheet();
            },

            tooltip: "View Parcel Data",
            child: const Icon(Icons.not_listed_location,
                semanticLabel: "View Parcel Data"),
          ),
          const SizedBox(height: 18),
          FloatingActionButton(
            //onPressed: () => setState(() => _timesPressed++),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: () => setState(() => _timesPressedLocation++),
            tooltip: "Go to Your Location",
            child: const Icon(Icons.radio_button_on,
                semanticLabel: "Go to Your Location"),
          ),
        ],
      ),
    );
  }
}
