import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

class RoutePlanScreen extends StatefulWidget {
  const RoutePlanScreen({super.key});
  @override
  State<RoutePlanScreen> createState() => _RoutePlanScreenState();
}

class _RoutePlanScreenState extends State<RoutePlanScreen> {
  dynamic _from = 'me';
  dynamic _to;
  bool _busy = false;
  Map<String, dynamic>? _result;

  List<dynamic> get _cities => ((Api.masters['cities'] as List?) ?? []).where((c) => c['lat'] != null).toList();

  LatLng? _point(dynamic id) {
    final c = _cities.where((x) => x['id'] == id);
    return c.isEmpty ? null : LatLng((c.first['lat'] as num).toDouble(), (c.first['lng'] as num).toDouble());
  }

  LatLng? _a, _b;

  Future<void> _go() async {
    setState(() => _busy = true);
    _a = _from == 'me' ? await currentLocation() : _point(_from);
    _b = _point(_to);
    if (_a == null || _b == null) {
      if (mounted) {
        toast(context, _a == null ? 'Could not get your location. Pick a city instead.' : 'Pick a destination.');
        setState(() => _busy = false);
      }
      return;
    }
    try {
      final r = await Api.get('stations/route', {'from_lat': _a!.latitude, 'from_lng': _a!.longitude, 'to_lat': _b!.latitude, 'to_lng': _b!.longitude}) as Map<String, dynamic>;
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _cities.map((c) => DropdownMenuItem<dynamic>(value: c['id'], child: Text('${c['name']}'))).toList();
    final r = _result;
    final stations = ((r?['stations'] as List?) ?? []).cast<dynamic>();
    return Scaffold(
      appBar: AppBar(title: Text(t('Plan a trip'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        DropdownButtonFormField<dynamic>(value: _from, isExpanded: true, decoration: InputDecoration(labelText: t('From'), border: const OutlineInputBorder()), items: [DropdownMenuItem<dynamic>(value: 'me', child: Text(t('My location'))), ...items], onChanged: (v) => setState(() => _from = v)),
        const SizedBox(height: 10),
        DropdownButtonFormField<dynamic>(value: _to, isExpanded: true, decoration: InputDecoration(labelText: t('To'), border: const OutlineInputBorder()), items: items, onChanged: (v) => setState(() => _to = v)),
        const SizedBox(height: 10),
        FilledButton(onPressed: _busy ? null : _go, child: Text(t('Show stations'))),
        if (r != null) ...[
          const SizedBox(height: 12),
          Text('${stations.length} ${t('stations on this route')}', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open route in Google Maps'),
            onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&origin=${_a!.latitude},${_a!.longitude}&destination=${_b!.latitude},${_b!.longitude}'), mode: LaunchMode.externalApplication),
          ),
          if (r['path_type'] == 'straight') const Text('Stations are matched to a straight line between the two places.', style: TextStyle(color: muted, fontSize: 13)),
          if (stations.isEmpty) Message(t('No stations found here. Try a bigger radius or clear filters.')),
          for (final s in stations) StationTile(s as Map<String, dynamic>),
        ],
      ]),
    );
  }
}
