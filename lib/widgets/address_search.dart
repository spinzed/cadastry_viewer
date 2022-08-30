import 'dart:convert';

import 'package:cadastry_viewer/models/positionstack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AddressSearch extends StatefulWidget {
  const AddressSearch({
    Key? key,
    required double width,
    required Function(LatLng point) onChooseLocation,
    required int onUnfocus,
  })  : _width = width,
        _onChooseLocation = onChooseLocation,
        _onUnfocus = onUnfocus,
        super(key: key);

  final double _width;
  final Function(LatLng point) _onChooseLocation;
  final int _onUnfocus;

  @override
  State<AddressSearch> createState() => _AddressSearchState();
}

class _AddressSearchState extends State<AddressSearch> {
  String token = dotenv.get("POSITIONSTACK_TOKEN");
  final shownLimit = 4;
  final queryLimit = 80;

  String _lastInput = "";
  PositionstackData? _data;
  int _oldUnfocus = 0;

  void onTextChanged(String text) async {
    final query = text.replaceAll("?", "").replaceAll("\$", "");
    if (query.replaceAll(" ", "").length < 4) return;

    setState(() => _lastInput = text);

    final resp = await http.get(Uri.parse(
        "http://api.positionstack.com/v1/forward?access_key=$token&query=$query&limit=$queryLimit&country=HR&output=json"));

    if (_lastInput != text) return;
    debugPrint(resp.request?.url.toString());

    final parsed = jsonDecode(utf8.decode(resp.bodyBytes));
    final fin = PositionstackData.fromJson(parsed);

    if (fin.data.length <= shownLimit) {
      setState(() => _data = fin);
      return;
    }

    List<PositionstackEntry> addrs =
        fin.data.where((e) => e.type == "address").toList();

    for (int i = 0; addrs.length != shownLimit && i < fin.data.length; ++i) {
      if (fin.data[i].type != "address") {
        addrs.add(fin.data[i]);
      }
    }
    setState(() => _data = PositionstackData(data: addrs));
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
                for (PositionstackEntry item in _data?.data ?? [])
                  Container(
                    width: widget._width,
                    padding: EdgeInsets.zero,
                    color: Colors.white,
                    child: ListTile(
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(item.postalCode != ""
                          ? "${item.region}, ${item.postalCode}"
                          : item.region),
                      trailing: const Icon(Icons.place),
                      enableFeedback: true,
                      onTap: () {
                        widget._onChooseLocation(
                            LatLng(item.latitude, item.longitude));
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
