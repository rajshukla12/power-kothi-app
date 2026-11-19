import 'dart:convert';
import 'package:flutter/material.dart';
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
  final _search = TextEditingController();
  LatLng _center = const LatLng(26.4499, 80.3319);
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

  Widget _listView() {
    if (_stations.isEmpty) return _loading ? const SizedBox() : Message(t('No stations found here. Try a bigger radius or clear filters.'));
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
          _search.clear();
          await _nearby(here);
        },
        child: const Icon(Icons.my_location),
      ),
      body: Column(children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) MaterialBanner(content: Text(_error!), actions: [TextButton(onPressed: () => _nearby(_center), child: Text(t('Try again')))]),
        Expanded(child: _listView()),
      ]),
    );
  }
}
