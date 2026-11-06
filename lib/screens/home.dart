import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';
import 'filters.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  LatLng _center = const LatLng(26.4499, 80.3319);
  double _zoom = 11;
  bool _moved = false;
  bool _showList = false;
  bool _loading = true;
  String? _error;
  List<dynamic> _stations = [];
  Map<String, dynamic> _filters = {};

  @override
  void initState() {
    super.initState();
    final saved = Api.prefs.getString('filters');
    if (saved != null) _filters = jsonDecode(saved) as Map<String, dynamic>;
    _start();
  }

  Future<void> _start() async {
    await _applyVehicleConnector();
    final here = await currentLocation();
    if (here != null) _center = here;
    if (!mounted) return;
    setState(() {});
    if (here != null) {
      try {
        _map.move(here, 12);
      } catch (_) {}
    }
    await _nearby(_center);
  }

  /// A saved vehicle sets the connector filter unless the user already chose one.
  Future<void> _applyVehicleConnector() async {
    if (!Api.loggedIn || _filters['connector_id'] != null) return;
    try {
      final v = await Api.get('vehicles') as List;
      if (v.isNotEmpty && v.first['connector_id'] != null) _filters['connector_id'] = v.first['connector_id'];
    } catch (_) {}
  }

  Future<void> _nearby(LatLng c) async {
    setState(() {
      _loading = true;
      _error = null;
      _moved = false;
    });
    try {
      final rows = await Api.get('stations/nearby', {'lat': c.latitude, 'lng': c.longitude, 'radius': Api.config['default_radius_km'] ?? 10, ..._filters}) as List;
      if (mounted) setState(() => _stations = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _searchText(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.get('stations/search', {'q': q.trim(), ..._filters}) as List;
      if (!mounted) return;
      setState(() => _stations = rows);
      if (rows.isNotEmpty) _map.move(LatLng((rows.first['lat'] as num).toDouble(), (rows.first['lng'] as num).toDouble()), 12);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openFilters() async {
    final f = await showModalBottomSheet<Map<String, dynamic>>(context: context, isScrollControlled: true, builder: (_) => FilterSheet(initial: _filters));
    if (f == null) return;
    _filters = f;
    await Api.prefs.setString('filters', jsonEncode(f));
    await _nearby(_center);
  }

  List<Marker> _markers() {
    final out = <Marker>[];
    for (final group in clusterStations(_stations, _zoom)) {
      final first = group.first;
      final p = LatLng((first['lat'] as num).toDouble(), (first['lng'] as num).toDouble());
      if (group.length > 1 && _zoom < 13) {
        out.add(Marker(
          point: p,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _map.move(p, _zoom + 2),
            child: CircleAvatar(backgroundColor: brandCoal, child: Text('${group.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          ),
        ));
      } else {
        for (final s in group) {
          out.add(Marker(
            point: LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
            width: 34,
            height: 34,
            child: GestureDetector(
              onTap: () => openStation(context, s['id'] as int),
              child: Icon(Icons.location_on, size: 34, color: statusColor(s['status'] as String?)),
            ),
          ));
        }
      }
    }
    return out;
  }

  Widget _mapView() => Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            onMapEvent: (e) {
              if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd) {
                setState(() {
                  _center = e.camera.center;
                  _zoom = e.camera.zoom;
                  _moved = true;
                });
              }
            },
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'in.powerkothi.app'),
            MarkerLayer(markers: _markers()),
            SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
          ],
        ),
        if (_moved)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(child: FilledButton.tonal(onPressed: () => _nearby(_center), child: Text(t('Search this area')))),
          ),
      ]);

  Widget _listView() {
    if (_stations.isEmpty) return Message(t('No stations found here. Try a bigger radius or clear filters.'));
    return RefreshIndicator(
      onRefresh: () => _nearby(_center),
      child: ListView.separated(
        itemCount: _stations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => StationTile(_stations[i] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: _searchText,
          style: const TextStyle(color: asphalt),
          decoration: InputDecoration(hintText: t('Search city, area or station'), filled: true, fillColor: Colors.white, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        ),
        actions: [
          IconButton(tooltip: t('Filters'), onPressed: _openFilters, icon: Badge(isLabelVisible: _filters.isNotEmpty, child: const Icon(Icons.tune))),
          IconButton(tooltip: t(_showList ? 'Map' : 'List'), onPressed: () => setState(() => _showList = !_showList), icon: Icon(_showList ? Icons.map : Icons.list)),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: t('My location'),
        onPressed: () async {
          final here = await currentLocation();
          if (here == null) {
            if (context.mounted) toast(context, 'Location is off. Turn it on, or search by city.');
            return;
          }
          _center = here;
          _map.move(here, 12);
          await _nearby(here);
        },
        child: const Icon(Icons.my_location),
      ),
      body: Column(children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) MaterialBanner(content: Text(_error!), actions: [TextButton(onPressed: () => _nearby(_center), child: Text(t('Try again')))]),
        Expanded(child: IndexedStack(index: _showList ? 1 : 0, children: [_mapView(), _listView()])),
      ]),
    );
  }
}
