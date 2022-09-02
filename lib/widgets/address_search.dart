import 'dart:convert';

import 'package:cadastry_viewer/models/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AddressSearch extends StatefulWidget {
  const AddressSearch({
    Key? key,
    required double width,
    required MapController controller,
    required Function(LatLng point) onChooseLocation,
    required int onUnfocus,
  })  : _width = width,
        _cnt = controller,
        _onChooseLocation = onChooseLocation,
        _onUnfocus = onUnfocus,
        super(key: key);

  final double _width;
  final MapController _cnt;
  final Function(LatLng point) _onChooseLocation;
  final int _onUnfocus;

  @override
  State<AddressSearch> createState() => _AddressSearchState();
}

class _AddressSearchState extends State<AddressSearch> {
  String tokenP = dotenv.get("POSITIONSTACK_TOKEN");
  String tokenM = dotenv.get("MAPBOX_PRIVATE_TOKEN");
  final shownLimit = 4;
  final queryLimit = 10;

  String _lastInput = "";
  GeocodingData? _data;
  int _oldUnfocus = 0;

  TextEditingController controller = TextEditingController();

  void onTextChanged(String text) async {
    final query = text.replaceAll("?", "").replaceAll("\$", "");
    if (query.replaceAll(" ", "").length < 4) return;

    setState(() => _lastInput = text);

    //final fin = await getPositionstack(query, text);
    final fin = await getMapbox(query, text);
    if (fin == null) return;

    List<GeocodingEntry> addrs =
        fin.data.where((e) => e.type == "address").toList();

    if (addrs.length >= shownLimit) {
      setState(() => _data = GeocodingData(data: addrs.sublist(0, shownLimit)));
      return;
    }

    for (int i = 0; addrs.length < shownLimit && i < fin.data.length; ++i) {
      if (fin.data[i].type != "address") {
        addrs.add(fin.data[i]);
      }
    }
    setState(() => _data = GeocodingData(data: addrs));
  }

  Future<GeocodingData?> getPositionstack(String query, text) async {
    final resp = await http.get(Uri.parse(
        "http://api.positionstack.com/v1/forward?access_key=$tokenP&query=$query&limit=$queryLimit&country=HR&output=json"));

    if (_lastInput != text) return null;
    debugPrint(resp.request?.url.toString());

    final parsed = jsonDecode(utf8.decode(resp.bodyBytes));
    final fin = GeocodingData.fromPositionstackJson(parsed);

    return fin;
  }

  Future<GeocodingData?> getMapbox(String query, text) async {
    final lat = widget._cnt.center.latitude;
    final lng = widget._cnt.center.longitude;
    final resp = await http.get(Uri.parse(
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$tokenM&limit=$queryLimit&autocomplete=true&country=HR&proximity=$lng,$lat"));

    if (_lastInput != text) return null;
    debugPrint(resp.request?.url.toString());

    final parsed = jsonDecode(utf8.decode(resp.bodyBytes));
    final fin = GeocodingData.fromMapboxJson(parsed);

    return fin;
  }

  @override
  Widget build(BuildContext context) {
    if (_oldUnfocus != widget._onUnfocus) {
      setState(() {
        if (WidgetsBinding.instance.window.viewInsets.bottom == 0) {
          _data = null;
        }
        _oldUnfocus = widget._onUnfocus;
      });
      //FocusScope.of(context).unfocus();
      // if it is not done this way, it will refocus again on the input field if the drawer if opened
      FocusScope.of(context).requestFocus(FocusNode());
    }

    return Stack(children: [
      SizedBox(
        width: widget._width,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          child: FittedBox(
            child: Column(
              children: [
                Container(
                  width: widget._width,
                  height:
                      _data?.data != null && _data!.data.isNotEmpty ? 20 : 0,
                  margin: const EdgeInsets.only(top: 20),
                  color: Colors.white,
                ),
                for (GeocodingEntry item in _data?.data ?? [])
                  Container(
                    width: widget._width,
                    padding: EdgeInsets.zero,
                    color: Colors.white,
                    child: ListTile(
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(item.placeAndCode()),
                      trailing: const Icon(Icons.place),
                      enableFeedback: true,
                      onTap: () {
                        widget._onChooseLocation(
                            LatLng(item.latitude, item.longitude));
                        controller.text = item.name;
                        FocusScope.of(context).unfocus();
                        setState(() => _data = null);
                      },
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
      Container(
        width: widget._width,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Focus(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration.collapsed(
                      hintText: "Search addresses..."),
                  onChanged: onTextChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}
