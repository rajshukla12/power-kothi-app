import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';
import 'booking.dart';
import 'review_report.dart';

class StationScreen extends StatefulWidget {
  final int id;
  const StationScreen({super.key, required this.id});
  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  bool? _fav;

  void _remember(Map<String, dynamic> s) {
    final raw = Api.prefs.getString('recent');
    final list = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
    list.removeWhere((e) => e['id'] == s['id']);
    list.insert(0, {'id': s['id'], 'name': s['name'], 'city': s['city']});
    Api.prefs.setString('recent', jsonEncode(list.take(15).toList()));
  }

  Future<void> _toggleFav() async {
    if (!await needLogin(context)) return;
    final now = !(_fav ?? false);
    try {
      now ? await Api.post('favourites/${widget.id}') : await Api.delete('favourites/${widget.id}');
      setState(() => _fav = now);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _directions(Map<String, dynamic> s) async {
    Api.post('stations/${s['id']}/navigate').catchError((_) {});
    await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${s['lat']},${s['lng']}'), mode: LaunchMode.externalApplication);
  }

  Future<String?> _chargeTime(num maxKw) async {
    if (!Api.loggedIn || maxKw <= 0) return null;
    try {
      final v = await Api.get('vehicles') as List;
      if (v.isEmpty || v.first['battery_kwh'] == null) return null;
      final kwh = (v.first['battery_kwh'] as num) * 0.6;
      return 'About ${(kwh / maxKw * 60).round()} minutes for 20 to 80% on your ${v.first['model']}';
    } catch (_) {
      return null;
    }
  }

  Widget _head(String text) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 6), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)));

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.white, child: Loader<Map<String, dynamic>>(
      load: () async => (await Api.get('stations/${widget.id}')) as Map<String, dynamic>,
      builder: (s, reload) {
        _remember(s);
        _fav ??= s['is_favourite'] == true;
        final photos = ((s['photos'] as List?) ?? []).cast<dynamic>();
        final conns = ((s['connector_list'] as List?) ?? []).cast<dynamic>();
        final reviews = ((s['reviews'] as List?) ?? []).cast<dynamic>();
        final amen = ((s['amenities'] as List?) ?? []).join(', ');
        return Scaffold(
          appBar: AppBar(
            title: Text('${s['name']}'),
            actions: [
              IconButton(tooltip: t('Share'), icon: const Icon(Icons.share), onPressed: () => Share.share('${s['name']}\n${s['url']}')),
              IconButton(tooltip: t('Saved'), icon: Icon(_fav == true ? Icons.favorite : Icons.favorite_border), onPressed: _toggleFav),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: brandCopper, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                onPressed: () => _directions(s),
                icon: const Icon(Icons.directions),
                label: Text(t('Get directions')),
              ),
            ),
          ),
          body: ListView(padding: const EdgeInsets.all(14), children: [
            if (photos.isNotEmpty)
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network('${photos[i]}', height: 170, width: 240, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 240))),
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Milestone(status: s['status'] as String?, value: '${s['max_kw'] ?? '?'}', unit: 'kW'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(statusWord(s['status'] as String?), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${s['address'] ?? ''}, ${s['city'] ?? ''} ${s['pincode'] ?? ''}'),
                  if (s['network'] != null) Text('${s['network']}${s['verified'] == true ? ', verified' : ''}', style: const TextStyle(color: muted)),
                  Text(s['is_24x7'] == true ? '24×7' : (s['open_time'] != null ? '${s['open_time']} - ${s['close_time']}' : ''), style: const TextStyle(color: muted)),
                ]),
              ),
            ]),
            if (s['reported_issue'] == true)
              Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), color: const Color(0xFFFFF3CD), child: const Text('Drivers reported a problem here recently. Call before you go.')),
            _head(t('Connectors')),
            for (final c in conns)
              ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.power, color: statusColor(c['status'] as String?)), title: Text('${c['type']} (${c['current']})'), subtitle: Text('${c['kw']} kW, ${c['count']} × ${statusWord(c['status'] as String?)}')),
            FutureBuilder<String?>(
              future: _chargeTime((s['max_kw'] as num?) ?? 0),
              builder: (_, snap) => snap.data == null ? const SizedBox() : Text(snap.data!, style: const TextStyle(color: brandCopper)),
            ),
            _head(t('Price')),
            Text('AC: ${s['price_ac'] != null ? '₹${s['price_ac']}/kWh' : '-'}     DC: ${s['price_dc'] != null ? '₹${s['price_dc']}/kWh' : '-'}'),
            if (s['parking_fee'] != null) Text('Parking: ₹${s['parking_fee']}'),
            if (amen.isNotEmpty) ...[_head('Nearby'), Text(amen)],
            if (s['phone'] != null) TextButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${s['phone']}')), icon: const Icon(Icons.call), label: Text('${s['phone']}')),
            _head('${t('Reviews')}${s['rating'] != null ? ' ★ ${s['rating']} (${s['review_count']})' : ''}'),
            for (final r in reviews) ListTile(contentPadding: EdgeInsets.zero, title: Text('${'★' * (r['rating'] as int)}  ${r['user']}'), subtitle: Text('${r['comment'] ?? ''}')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton(
                onPressed: () async {
                  if (await needLogin(context) && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(stationId: widget.id)));
                },
                child: Text(t('Write a review')),
              ),
              OutlinedButton(
                onPressed: () async {
                  if (await needLogin(context) && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(stationId: widget.id)));
                },
                child: Text(t('Report a problem')),
              ),
              OutlinedButton(
                onPressed: () async {
                  if (await needLogin(context) && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(stationId: widget.id)));
                },
                child: Text(t('Book a slot')),
              ),
            ]),
          ]),
        );
      },
    ));
  }
}
