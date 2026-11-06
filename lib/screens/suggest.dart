import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

class SuggestScreen extends StatefulWidget {
  const SuggestScreen({super.key});
  @override
  State<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends State<SuggestScreen> {
  final _name = TextEditingController();
  final _conn = TextEditingController();
  final _map = MapController();
  LatLng _pin = const LatLng(26.4499, 80.3319);
  XFile? _photo;
  XFile? _doc;
  String _docType = 'Electricity bill';
  bool _busy = false;
  static const _docTypes = ['Electricity bill', 'Land ownership proof', 'Rent agreement', 'Trade licence', 'NOC', 'Other'];

  @override
  void initState() {
    super.initState();
    currentLocation().then((p) {
      if (p != null && mounted) {
        setState(() => _pin = p);
        _map.move(p, 15);
      }
    });
  }

  Future<void> _send() async {
    if (_name.text.trim().isEmpty) {
      toast(context, 'Enter the station name.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.upload(
        'stations/suggest',
        {'name': _name.text.trim(), 'lat': '${_pin.latitude}', 'lng': '${_pin.longitude}', 'connectors': _conn.text, if (_doc != null) 'doc_type1': _docType},
        {if (_photo != null) 'photo': _photo!.path, if (_doc != null) 'doc1': _doc!.path},
      );
      if (r is Map && r['doc_error'] != null && mounted) toast(context, '${r['doc_error']}');
      if (mounted) {
        toast(context, 'Sent. We will tell you once it is approved.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        toast(context, '$e');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Suggest a station'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Station name', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _conn, decoration: const InputDecoration(labelText: 'Connector types', hintText: 'CCS2, Type 2', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        const Text('Tap the map to place the pin.'),
        const SizedBox(height: 6),
        SizedBox(
          height: 260,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _pin, initialZoom: 14, onTap: (_, p) => setState(() => _pin = p)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'in.powerkothi.app'),
              MarkerLayer(markers: [Marker(point: _pin, width: 36, height: 36, child: const Icon(Icons.location_on, size: 36, color: brandCoal))]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_camera),
          label: Text(_photo == null ? 'Add photo' : 'Photo added'),
          onPressed: () async {
            final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
            if (f != null) setState(() => _photo = f);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _docType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Document type', border: OutlineInputBorder()),
          items: [for (final d in _docTypes) DropdownMenuItem(value: d, child: Text(d))],
          onChanged: (v) => setState(() => _docType = v ?? _docType),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.description),
          label: Text(_doc == null ? 'Add document photo' : 'Document added'),
          onPressed: () async {
            final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 2000);
            if (f != null) setState(() => _doc = f);
          },
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _busy ? null : _send, child: const Text('Send')),
      ]),
    );
  }
}
