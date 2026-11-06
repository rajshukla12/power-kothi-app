import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'api.dart';
import 'i18n.dart';
import 'screens/login.dart';
import 'screens/station.dart';

const Color brandCopper = Color(0xFFBF5A1B);
const Color brandCoal = Color(0xFF232323);
const Color brandLight = Color(0xFFEC9A4C);
const Color busyYellow = Color(0xFFF2B705);
const Color asphalt = Color(0xFF232323);
const Color ground = Color(0xFFF3F2F0);
const Color muted = Color(0xFF5F5A55);

Color statusColor(String? s) {
  switch (s) {
    case 'available':
      return const Color(0xFF1F9D6B);
    case 'busy':
      return busyYellow;
    case 'down':
      return const Color(0xFFC4321C);
  }
  return const Color(0xFF8B989B);
}

String statusWord(String? s) {
  switch (s) {
    case 'available':
      return t('Available');
    case 'busy':
      return t('Busy');
    case 'down':
      return t('Not working');
  }
  return t('Status not known');
}

/// Kilometre stone: the cap shows status, the face shows distance or power.
class Milestone extends StatelessWidget {
  final String? status;
  final String value;
  final String unit;
  const Milestone({super.key, required this.status, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 70,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: asphalt, width: 2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28), bottom: Radius.circular(5)),
      ),
      child: Column(children: [
        Container(height: 24, decoration: BoxDecoration(color: statusColor(status), border: const Border(bottom: BorderSide(color: asphalt, width: 2)))),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1)),
            Text(unit, style: const TextStyle(fontSize: 11, height: 1.1)),
          ]),
        ),
      ]),
    );
  }
}

class StationTile extends StatelessWidget {
  final Map<String, dynamic> s;
  const StationTile(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final km = s['distance_km'];
    final kmText = km == null ? null : ((km as num) < 10 ? km.toStringAsFixed(1) : km.round().toString());
    final parts = <String>[
      statusWord(s['status'] as String?),
      if (s['connectors'] != null) '${s['connectors']}',
      if (s['max_kw'] != null) '${s['max_kw']} kW',
      if (s['price_dc'] != null) '₹${s['price_dc']}/kWh',
      if (s['rating'] != null) '★ ${s['rating']}',
    ];
    return InkWell(
      onTap: () => openStation(context, s['id'] as int),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Milestone(status: s['status'] as String?, value: kmText ?? '${s['max_kw'] ?? '?'}', unit: kmText != null ? 'km' : 'kW'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text('${s['area'] ?? s['address'] ?? s['city'] ?? ''}'),
              const SizedBox(height: 2),
              Text(parts.join(', '), style: const TextStyle(color: muted, fontSize: 13)),
              if (s['open_now'] != null) Text(t(s['open_now'] == true ? 'Open now' : 'Closed now'), style: TextStyle(fontSize: 13, color: s['open_now'] == true ? brandCopper : Colors.red.shade800)),
            ]),
          ),
        ]),
      ),
    );
  }
}

void openStation(BuildContext context, int id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => StationScreen(id: id)));
}

/// Loads a future with spinner, error + retry, and an optional empty message.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(T data, VoidCallback reload) builder;
  const Loader({super.key, required this.load, required this.builder});
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _f = widget.load();
  void _reload() => setState(() => _f = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Message('${snap.error}', action: t('Try again'), onTap: _reload);
        return widget.builder(snap.data as T, _reload);
      },
    );
  }
}

/// Logo that breathes while the app starts.
class PulseLogo extends StatefulWidget {
  final double width;
  const PulseLogo({super.key, this.width = 190});
  @override
  State<PulseLogo> createState() => _PulseLogoState();
}

class _PulseLogoState extends State<PulseLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.72, end: 1).animate(_a),
      child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1.03).animate(_a), child: Image.asset('assets/logo_dark.png', width: widget.width)),
    );
  }
}

class Message extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onTap;
  const Message(this.text, {super.key, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton(onPressed: onTap, child: Text(action!))),
        ]),
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Sends the user to sign in when needed. Returns true once signed in.
Future<bool> needLogin(BuildContext context) async {
  if (Api.loggedIn) return true;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
  return ok == true;
}

Future<LatLng?> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    final pos = await Geolocator.getCurrentPosition();
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

/// Plain grid clustering so a zoomed-out map stays readable.
List<List<Map<String, dynamic>>> clusterStations(List<dynamic> stations, double zoom) {
  final cell = 360 / (pow(2, zoom) * 5);
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final raw in stations) {
    final s = raw as Map<String, dynamic>;
    final key = '${((s['lat'] as num) / cell).floor()}:${((s['lng'] as num) / cell).floor()}';
    buckets.putIfAbsent(key, () => []).add(s);
  }
  return buckets.values.toList();
}
