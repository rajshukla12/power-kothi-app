import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

/// Partner section: people who bring EV-charger sites earn money when the site goes live.
/// API (all need login):
///   GET  partner/status   POST partner/join   GET partner/dashboard
///   GET  partner/leads    POST partner/leads (multipart)   GET partner/leads/{id}
///   GET  partner/wallet   POST partner/payout-request      PUT partner/bank

// ---------------------------------------------------------------------------
// Lead stages (keys must match the server)
// ---------------------------------------------------------------------------
const List<String> leadStages = ['new', 'verified', 'site_visit', 'agreement', 'installed'];

String stageLabel(String? s) {
  switch (s) {
    case 'new':
      return t('Submitted');
    case 'verified':
      return t('Site survey scheduled');
    case 'site_visit':
      return t('Feasibility approved');
    case 'agreement':
      return t('Agreement signed');
    case 'installed':
      return t('Charger live');
    case 'rejected':
      return t('Not suitable');
  }
  return s ?? '';
}

Color stageColor(String? s) {
  switch (s) {
    case 'installed':
      return const Color(0xFF1F9D6B);
    case 'agreement':
    case 'site_visit':
      return const Color(0xFF2F6FDB);
    case 'verified':
      return busyYellow;
    case 'rejected':
      return const Color(0xFFC4321C);
  }
  return brandCopper;
}

/// Server numbers may arrive as int, double or string.
double numOf(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

String rupees(dynamic v) {
  final n = numOf(v);
  final s = n.round().toString();
  if (s.length <= 3) return '₹$s';
  // Indian grouping: 12,34,567
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

/// (key, label) pairs. Keys match station_leads.site_type on the server.
List<(String, String)> propertyTypes() {
  final m = Api.masters['property_types'];
  if (m is List && m.isNotEmpty) return [for (final x in m) if (x is Map) ('${x['key']}', '${x['name']}')];
  return const [
    ('petrol_pump', 'Petrol pump'),
    ('hotel', 'Hotel / Restaurant / Dhaba'),
    ('mall', 'Mall / Shopping complex'),
    ('parking', 'Parking lot'),
    ('owned', 'Own land / building'),
    ('rented', 'Rented place'),
    ('other', 'Other'),
  ];
}

// ---------------------------------------------------------------------------
// Partner tab
// ---------------------------------------------------------------------------
class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});
  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _dashKey = GlobalKey<_DashboardTabState>();
  final _leadsKey = GlobalKey<_LeadsTabState>();
  Future<Map<String, dynamic>>? _status;

  Future<Map<String, dynamic>> _loadStatus() async => (await Api.get('partner/status')) as Map<String, dynamic>;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _afterSubmit() {
    _dashKey.currentState?.reload();
    _leadsKey.currentState?.reload();
    _tabs.animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    if (!Api.loggedIn) {
      _status = null;
      return Scaffold(
        appBar: AppBar(title: Text(t('Partner'))),
        body: _PartnerIntro(onSignedIn: () => setState(() {})),
      );
    }
    _status ??= _loadStatus();
    return FutureBuilder<Map<String, dynamic>>(
      future: _status,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(title: Text(t('Partner'))), body: const Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(t('Partner'))),
            body: Message('${snap.error}', action: t('Try again'), onTap: () => setState(() => _status = _loadStatus())),
          );
        }
        final st = snap.data!;
        if (st['is_partner'] != true) {
          return Scaffold(
            appBar: AppBar(title: Text(t('Partner'))),
            body: _PartnerIntro(status: st, onSignedIn: () => setState(() => _status = _loadStatus())),
          );
        }
        return _partnerTabs();
      },
    );
  }

  Widget _partnerTabs() {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Partner')),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: brandLight,
          indicatorWeight: 3,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard), text: t('Dashboard')),
            Tab(icon: const Icon(Icons.add_location_alt), text: t('Submit')),
            Tab(icon: const Icon(Icons.timeline), text: t('My leads')),
            Tab(icon: const Icon(Icons.account_balance_wallet), text: t('Wallet')),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        DashboardTab(key: _dashKey, onSubmit: () => _tabs.animateTo(1), onLeads: () => _tabs.animateTo(2), onWallet: () => _tabs.animateTo(3)),
        SubmitLocationTab(onDone: _afterSubmit),
        LeadsTab(key: _leadsKey),
        const PartnerWalletTab(),
      ]),
    );
  }
}

class _PartnerIntro extends StatefulWidget {
  final VoidCallback onSignedIn;
  final Map<String, dynamic>? status;
  const _PartnerIntro({required this.onSignedIn, this.status});
  @override
  State<_PartnerIntro> createState() => _PartnerIntroState();
}

class _PartnerIntroState extends State<_PartnerIntro> {
  late final _name = TextEditingController(text: '${Api.user?['name'] ?? ''}');
  bool _busy = false;

  Future<void> _join() async {
    if (_name.text.trim().length < 2) {
      toast(context, t('Enter your full name.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.post('partner/join', {'name': _name.text.trim()});
      widget.onSignedIn();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.status;
    final perLead = numOf(st?['per_lead']);
    final steps = [
      (Icons.add_location_alt, t('Find a site'), t('A petrol pump, hotel, parking or society with space for an EV charger.')),
      (Icons.photo_camera, t('Submit in 1 minute'), t('Owner name, phone, property type, location and photos.')),
      (Icons.timeline, t('Track every step'), t('See survey, approval, agreement and installation live in the app.')),
      (Icons.currency_rupee, t('Earn when it goes live'), t('Money is added to your wallet and paid to your bank or UPI.')),
    ];
    return ListView(padding: const EdgeInsets.all(20), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [brandCoal, Color(0xFF3A2A1E)]), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.bolt, color: brandLight, size: 36),
          const SizedBox(height: 8),
          Text(t('Earn with Power Kothi'), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(t('Bring locations for new EV charging stations and earn for every charger that goes live.'), style: const TextStyle(color: Colors.white70, fontSize: 15)),
          if (perLead > 0) ...[
            const SizedBox(height: 10),
            Text('${t('Earn up to')} ${rupees(perLead)} ${t('per charger')}', style: const TextStyle(color: brandLight, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ]),
      ),
      const SizedBox(height: 18),
      for (var i = 0; i < steps.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: brandLight.withOpacity(.25), child: Text('${i + 1}', style: const TextStyle(color: brandCopper, fontWeight: FontWeight.w800))),
          title: Text(steps[i].$2, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(steps[i].$3),
          trailing: Icon(steps[i].$1, color: muted),
        ),
      const SizedBox(height: 16),
      if (st == null)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.login),
          label: Text(t('Sign in to start')),
          onPressed: () async {
            if (await needLogin(context)) widget.onSignedIn();
          },
        )
      else if (st['can_join'] == true) ...[
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: t('Your full name'), prefixIcon: const Icon(Icons.person), border: const OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.handshake),
          label: Text(t('Join as partner')),
          onPressed: _busy ? null : _join,
        ),
      ] else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: ground, borderRadius: BorderRadius.circular(12)),
          child: Text(t('Partner sign-up is by invitation. Ask Power Kothi to add your mobile number as a partner, then open this tab again.')),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// S-1 Dashboard: earnings, pipeline, leaderboard
// ---------------------------------------------------------------------------
class DashboardTab extends StatefulWidget {
  final VoidCallback onSubmit, onLeads, onWallet;
  const DashboardTab({super.key, required this.onSubmit, required this.onLeads, required this.onWallet});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _f = _load();
  Future<Map<String, dynamic>> _load() async => (await Api.get('partner/dashboard')) as Map<String, dynamic>;
  void reload() => setState(() => _f = _load());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Message('${snap.error}', action: t('Try again'), onTap: reload);
        final d = snap.data!;
        final pipe = (d['pipeline'] as Map?) ?? {};
        final board = ((d['leaderboard'] as List?) ?? []).cast<dynamic>();
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await _f;
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _EarningsCard(d: d, onWallet: widget.onWallet),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: widget.onSubmit,
              icon: const Icon(Icons.add_location_alt),
              label: Text(t('Submit a new location')),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Text(t('Lead pipeline'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton(onPressed: widget.onLeads, child: Text(t('See all'))),
            ]),
            const SizedBox(height: 6),
            _Pipeline(pipe: pipe),
            const SizedBox(height: 24),
            Text(t('Leaderboard'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(t('Partners who earned the most this month'), style: const TextStyle(color: muted)),
            const SizedBox(height: 8),
            if (board.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(t('No live chargers yet this month. Be the first!'), textAlign: TextAlign.center)),
            for (final r in board) _BoardRow(r as Map<String, dynamic>),
            if (d['my_rank'] != null && !board.any((r) => r['me'] == true)) ...[
              const Divider(),
              _BoardRow({...(d['my_rank'] as Map<String, dynamic>), 'me': true}),
            ],
          ]),
        );
      },
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final Map<String, dynamic> d;
  final VoidCallback onWallet;
  const _EarningsCard({required this.d, required this.onWallet});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onWallet,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [brandCoal, Color(0xFF4A2D16)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(t('Total earnings'), style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ]),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: numOf(d['total_earnings'])),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(rupees(v), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _mini(t('In wallet'), rupees(d['wallet_balance'] ?? 0)),
            _mini(t('Pending'), rupees(d['pending_earnings'] ?? 0)),
            _mini(t('Live chargers'), '${d['live_count'] ?? 0}'),
          ]),
        ]),
      ),
    );
  }

  Widget _mini(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: brandLight, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );
}

/// Submit → Inspected → Approved → Live, with the number of leads at each step.
class _Pipeline extends StatelessWidget {
  final Map pipe;
  const _Pipeline({required this.pipe});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('submitted', t('Submitted'), Icons.send),
      ('inspected', t('Inspected'), Icons.search),
      ('approved', t('Approved'), Icons.verified),
      ('live', t('Live'), Icons.ev_station),
    ];
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(color: i == 3 ? const Color(0xFFE5F5EE) : ground, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Icon(steps[i].$3, size: 20, color: i == 3 ? const Color(0xFF1F9D6B) : brandCopper),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: numOf(pipe[steps[i].$1])),
                duration: Duration(milliseconds: 600 + i * 150),
                builder: (_, v, __) => Text('${v.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              Text(steps[i].$2, style: const TextStyle(fontSize: 11.5, color: muted), textAlign: TextAlign.center),
            ]),
          ),
        ),
        if (i < steps.length - 1) const Icon(Icons.chevron_right, size: 18, color: muted),
      ],
    ]);
  }
}

class _BoardRow extends StatelessWidget {
  final Map<String, dynamic> r;
  const _BoardRow(this.r);

  @override
  Widget build(BuildContext context) {
    final rank = numOf(r['rank']);
    final me = r['me'] == true;
    final medal = {1: const Color(0xFFE2B007), 2: const Color(0xFFA7ADB4), 3: const Color(0xFFC07A3E)}[rank.toInt()];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: me ? brandLight.withOpacity(.18) : null, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: medal ?? ground,
          child: Text('${rank.toInt()}', style: TextStyle(fontWeight: FontWeight.w800, color: medal != null ? Colors.white : asphalt)),
        ),
        title: Text(me ? '${r['name'] ?? ''} (${t('You')})' : '${r['name'] ?? ''}', style: TextStyle(fontWeight: me ? FontWeight.w800 : FontWeight.w600)),
        subtitle: Text('${r['city'] ?? ''}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${r['live_count'] ?? 0} ${t('live')}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (r['earnings'] != null) Text(rupees(r['earnings']), style: const TextStyle(color: muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// S-2 Submit a location (core tool): owner name & phone, property type,
// current location, camera photos. Nothing else.
// ---------------------------------------------------------------------------
class SubmitLocationTab extends StatefulWidget {
  final VoidCallback onDone;
  const SubmitLocationTab({super.key, required this.onDone});
  @override
  State<SubmitLocationTab> createState() => _SubmitLocationTabState();
}

class _SubmitLocationTabState extends State<SubmitLocationTab> with AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  String? _type;
  LatLng? _pin;
  bool _locating = false;
  bool _busy = false;
  final List<XFile> _photos = [];
  static const int maxPhotos = 4;

  @override
  bool get wantKeepAlive => true;

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final p = await currentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      toast(context, t('Turn on location (GPS) and allow it for Power Kothi.'));
      return;
    }
    setState(() => _pin = p);
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= maxPhotos) return;
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (f != null && mounted) setState(() => _photos.add(f));
    } catch (_) {
      if (mounted) toast(context, t('Allow camera for Power Kothi to take photos.'));
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (_pin == null) {
      toast(context, t('Tap “Use current location” while standing at the site.'));
      return;
    }
    if (_photos.isEmpty) {
      toast(context, t('Add at least one photo of the site.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.upload('partner/leads', {
        'owner_name': _owner.text.trim(),
        'owner_phone': _phone.text.trim(),
        'property_type': _type!,
        'lat': _pin!.latitude.toStringAsFixed(7),
        'lng': _pin!.longitude.toStringAsFixed(7),
      }, {
        for (var i = 0; i < _photos.length; i++) 'photo${i + 1}': _photos[i].path,
      });
      if (!mounted) return;
      final saved = res is Map ? numOf(res['photos_saved']).toInt() : _photos.length;
      if (saved < _photos.length) toast(context, '${_photos.length - saved} ${t('photo(s) could not be saved. Our team may ask you for them.')}');
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF1F9D6B), size: 48),
          title: Text(t('Location submitted')),
          content: Text(t('Our team will check it and schedule a site survey. You can follow every step in My leads.')),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(t('OK')))],
        ),
      );
      _form.currentState!.reset();
      _owner.clear();
      _phone.clear();
      setState(() {
        _type = null;
        _pin = null;
        _photos.clear();
        _busy = false;
      });
      widget.onDone();
    } catch (e) {
      if (mounted) {
        toast(context, '$e');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('Submit a location'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(t('Stand at the site and fill these four things.'), style: const TextStyle(color: muted)),
        const SizedBox(height: 16),
        _label('1', t('Property owner')),
        TextFormField(
          controller: _owner,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: t('Owner name'), prefixIcon: const Icon(Icons.person), border: const OutlineInputBorder()),
          validator: (v) => (v ?? '').trim().length < 2 ? t('Enter the owner’s name.') : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(labelText: t('Owner phone number'), prefixText: '+91 ', prefixIcon: const Icon(Icons.call), border: const OutlineInputBorder(), counterText: ''),
          validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch((v ?? '').trim()) ? null : t('Enter a 10-digit mobile number.'),
        ),
        const SizedBox(height: 18),
        _label('2', t('Type of property')),
        DropdownButtonFormField<String>(
          value: _type,
          isExpanded: true,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.apartment), border: const OutlineInputBorder(), hintText: t('Choose property type')),
          items: [for (final p in propertyTypes()) DropdownMenuItem(value: p.$1, child: Text(p.$2))],
          onChanged: (v) => setState(() => _type = v),
          validator: (v) => v == null ? t('Choose the property type.') : null,
        ),
        const SizedBox(height: 18),
        _label('3', t('Location')),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _locating ? null : _useLocation,
          icon: _locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
          label: Text(_pin == null ? t('Use current location') : t('Update current location')),
        ),
        if (_pin != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE5F5EE), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF1F9D6B)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('Location captured'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${_pin!.latitude.toStringAsFixed(6)}, ${_pin!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 18),
        _label('4', '${t('Site photos')} (${_photos.length}/$maxPhotos)'),
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < _photos.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_photos[i].path), width: 96, height: 96, fit: BoxFit.cover)),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: InkWell(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            if (_photos.length < maxPhotos)
              InkWell(
                onTap: _takePhoto,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 96,
                  decoration: BoxDecoration(border: Border.all(color: brandCopper, width: 1.5), borderRadius: BorderRadius.circular(10), color: brandLight.withOpacity(.1)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.photo_camera, color: brandCopper),
                    const SizedBox(height: 4),
                    Text(t('Take photo'), style: const TextStyle(fontSize: 12, color: brandCopper, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        Text(t('Show the space for parking and charger, the entrance and the electricity meter.'), style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _busy ? null : _send,
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
          label: Text(_busy ? t('Submitting…') : t('Submit location')),
        ),
      ]),
    );
  }

  Widget _label(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          CircleAvatar(radius: 11, backgroundColor: brandCoal, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// S-3 Lead tracker & status (refreshes every 30 s while open)
// ---------------------------------------------------------------------------
class LeadsTab extends StatefulWidget {
  const LeadsTab({super.key});
  @override
  State<LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<LeadsTab> with AutomaticKeepAliveClientMixin {
  List<dynamic>? _rows;
  String? _error;
  String _filter = 'all';
  Timer? _poll;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => reload(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _error = null);
    try {
      final r = (await Api.get('partner/leads')) as List<dynamic>;
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted && !silent) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null && _rows == null) return Message(_error!, action: t('Try again'), onTap: reload);
    if (_rows == null) return const Center(child: CircularProgressIndicator());
    final rows = _filter == 'all'
        ? _rows!
        : _filter == 'active'
            ? _rows!.where((r) => r['status'] != 'installed' && r['status'] != 'rejected').toList()
            : _rows!.where((r) => r['status'] == _filter).toList();
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in [('all', t('All')), ('active', t('In progress')), ('installed', t('Live')), ('rejected', t('Not suitable'))])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(f.$2), selected: _filter == f.$1, onSelected: (_) => setState(() => _filter = f.$1)),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 60), child: Message(_rows!.isEmpty ? t('You have not submitted a location yet.') : t('No leads in this list.'))),
        for (final r in rows) _LeadCard(r as Map<String, dynamic>, onChanged: reload),
      ]),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onChanged;
  const _LeadCard(this.r, {required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final st = '${r['status']}';
    final idx = leadStages.indexOf(st);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(id: numOf(r['id']).toInt())));
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: _ph()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['owner_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${r['property_type'] ?? ''}${r['city'] != null ? ' · ${r['city']}' : ''}', style: const TextStyle(color: muted)),
                  Text('${r['lead_no'] ?? '#${r['id']}'} · ${r['created_at'] ?? ''}', style: const TextStyle(color: muted, fontSize: 12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: stageColor(st).withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                child: Text(stageLabel(st), style: TextStyle(color: stageColor(st), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
            if (st != 'rejected') ...[
              const SizedBox(height: 12),
              Row(children: [
                for (var i = 0; i < leadStages.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300 + i * 120),
                      height: 6,
                      decoration: BoxDecoration(color: i <= idx ? stageColor(st) : Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  if (i < leadStages.length - 1) const SizedBox(width: 4),
                ],
              ]),
            ],
            if (numOf(r['earned']) > 0 || (numOf(r['earning']) > 0 && st != 'rejected')) ...[
              const SizedBox(height: 8),
              Text(
                numOf(r['earned']) > 0 ? '${t('Earned')} ${rupees(r['earned'])}${st != 'installed' && numOf(r['earning']) > numOf(r['earned']) ? ' ${t('of')} ${rupees(r['earning'])}' : ''}' : '${t('Earn up to')} ${rupees(r['earning'])}',
                style: TextStyle(color: numOf(r['earned']) > 0 ? const Color(0xFF1F9D6B) : muted, fontWeight: FontWeight.w700),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _ph() => Container(width: 56, height: 56, color: ground, child: const Icon(Icons.location_on, color: brandCopper));
}

class LeadDetailScreen extends StatelessWidget {
  final int id;
  const LeadDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Lead details'))),
      body: Loader<Map<String, dynamic>>(
        load: () async => (await Api.get('partner/leads/$id')) as Map<String, dynamic>,
        builder: (l, reload) {
          final st = '${l['status']}';
          final timeline = ((l['timeline'] as List?) ?? []).cast<dynamic>();
          final photoCount = numOf(l['photo_count']).toInt();
          final byStage = {for (final x in timeline) '${x['status']}': x};
          final idx = leadStages.indexOf(st);
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('${l['owner_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              if (l['lead_no'] != null) Text('${l['lead_no']}', style: const TextStyle(color: muted, fontSize: 12)),
              Text('${l['property_type'] ?? ''}${l['address'] != null ? '\n${l['address']}' : ''}', style: const TextStyle(color: muted)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ActionChip(avatar: const Icon(Icons.call, size: 18), label: Text('${l['owner_phone']}'), onPressed: () => launchUrl(Uri.parse('tel:${l['owner_phone']}'))),
                if (l['lat'] != null)
                  ActionChip(
                    avatar: const Icon(Icons.map, size: 18),
                    label: Text(t('Open in maps')),
                    onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${l['lat']},${l['lng']}'), mode: LaunchMode.externalApplication),
                  ),
              ]),
              if (st != 'rejected' && (numOf(l['earned']) > 0 || numOf(l['earning']) > 0))
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: numOf(l['earned']) > 0 ? const Color(0xFFE5F5EE) : ground, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(numOf(l['earned']) > 0 ? Icons.check_circle : Icons.currency_rupee, color: numOf(l['earned']) > 0 ? const Color(0xFF1F9D6B) : brandCopper),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        numOf(l['earned']) > 0
                            ? '${rupees(l['earned'])} ${t('added to your wallet')}${st != 'installed' && numOf(l['earning']) > numOf(l['earned']) ? '. ${t('Up to')} ${rupees(numOf(l['earning']) - numOf(l['earned']))} ${t('more as it moves ahead.')}' : ''}'
                            : '${t('Earn up to')} ${rupees(l['earning'])} ${t('as this lead moves to Charger live')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 20),
              Text(t('Status'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (st == 'rejected')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
                  child: Text('${t('Not suitable')}${l['reject_reason'] != null ? ': ${l['reject_reason']}' : ''}', style: const TextStyle(color: Color(0xFFC4321C), fontWeight: FontWeight.w600)),
                )
              else
                for (var i = 0; i < leadStages.length; i++)
                  _TimelineStep(
                    title: stageLabel(leadStages[i]),
                    date: byStage[leadStages[i]]?['date']?.toString(),
                    note: byStage[leadStages[i]]?['note']?.toString(),
                    done: i <= idx,
                    current: i == idx,
                    last: i == leadStages.length - 1,
                  ),
              if (photoCount > 0)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_library, color: muted),
                  title: Text('$photoCount ${t('site photos sent')}'),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String? date, note;
  final bool done, current, last;
  const _TimelineStep({required this.title, this.date, this.note, required this.done, required this.current, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = done ? const Color(0xFF1F9D6B) : Colors.grey.shade400;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 32,
          child: Column(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: done ? c : Colors.white, shape: BoxShape.circle, border: Border.all(color: c, width: 2)),
              child: done ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
            ),
            if (!last) Expanded(child: Container(width: 2, color: c)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: current ? FontWeight.w800 : FontWeight.w600, color: done ? asphalt : muted)),
              if (date != null) Text(date!, style: const TextStyle(color: muted, fontSize: 12)),
              if (note != null && note!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note!, style: const TextStyle(fontSize: 13))),
              if (current && !last) Padding(padding: const EdgeInsets.only(top: 2), child: Text(t('Current step'), style: const TextStyle(color: brandCopper, fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// S-4 Wallet & payouts
// ---------------------------------------------------------------------------
class PartnerWalletTab extends StatefulWidget {
  const PartnerWalletTab({super.key});
  @override
  State<PartnerWalletTab> createState() => _PartnerWalletTabState();
}

class _PartnerWalletTabState extends State<PartnerWalletTab> with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _f = _load();
  Future<Map<String, dynamic>> _load() async => (await Api.get('partner/wallet')) as Map<String, dynamic>;
  void _reload() => setState(() => _f = _load());

  @override
  bool get wantKeepAlive => true;

  Future<void> _requestPayout(Map<String, dynamic> w) async {
    final bank = w['bank'] as Map?;
    if (bank == null || ('${bank['account_no'] ?? ''}'.isEmpty && '${bank['upi'] ?? ''}'.isEmpty)) {
      toast(context, t('Add your bank account or UPI first.'));
      await _editBank(w);
      return;
    }
    final bal = numOf(w['balance']);
    final min = w['min_payout'] == null ? 100.0 : numOf(w['min_payout']);
    if (bal < min) {
      toast(context, '${t('Minimum payout is')} ${rupees(min)}.');
      return;
    }
    final amt = TextEditingController(text: bal.round().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Request payout')),
        content: TextField(controller: amt, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: '₹ ', labelText: t('Amount'), helperText: '${t('Available')}: ${rupees(bal)}')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Request payout'))),
        ],
      ),
    );
    if (ok != true) return;
    final v = num.tryParse(amt.text.trim()) ?? 0;
    if (v < min || v > bal) {
      if (mounted) toast(context, '${t('Enter an amount between')} ${rupees(min)} ${t('and')} ${rupees(bal)}.');
      return;
    }
    try {
      await Api.post('partner/payout-request', {'amount': v});
      if (mounted) toast(context, t('Payout requested. It is usually paid within 3 working days.'));
      _reload();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _editBank(Map<String, dynamic> w) async {
    final b = (w['bank'] as Map?) ?? {};
    final name = TextEditingController(text: '${b['account_name'] ?? ''}');
    final acc = TextEditingController(text: '${b['account_no'] ?? ''}');
    final ifsc = TextEditingController(text: '${b['ifsc'] ?? ''}');
    final upi = TextEditingController(text: '${b['upi'] ?? ''}');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Payout account'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: t('Account holder name'), border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: acc, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('Account number'), border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: ifsc, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'IFSC', border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          Text(t('or'), textAlign: TextAlign.center, style: const TextStyle(color: muted)),
          const SizedBox(height: 8),
          TextField(controller: upi, decoration: InputDecoration(labelText: 'UPI ID', hintText: 'name@okaxis', border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Save'))),
        ]),
      ),
    );
    if (saved != true) return;
    if (ifsc.text.trim().isNotEmpty && !RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$').hasMatch(ifsc.text.trim())) {
      if (mounted) toast(context, t('IFSC looks wrong. It has 11 characters, like SBIN0001234.'));
      return;
    }
    try {
      await Api.put('partner/bank', {'account_name': name.text.trim(), 'account_no': acc.text.trim(), 'ifsc': ifsc.text.trim().toUpperCase(), 'upi': upi.text.trim()});
      if (mounted) toast(context, t('Payout account saved.'));
      _reload();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Message('${snap.error}', action: t('Try again'), onTap: _reload);
        final w = snap.data!;
        final tx = ((w['transactions'] as List?) ?? []).cast<dynamic>();
        final payouts = ((w['payouts'] as List?) ?? []).cast<dynamic>();
        final bank = w['bank'] as Map?;
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _f;
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [brandCopper, brandLight]), borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Wallet balance'), style: const TextStyle(color: Colors.white70)),
                Text(rupees(w['balance'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(children: [
                  _stat(t('Total earned'), rupees(w['total_earned'] ?? 0)),
                  _stat(t('Paid out'), rupees(w['total_paid'] ?? 0)),
                  _stat(t('Payout pending'), rupees(w['pending_payout'] ?? 0)),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brandCopper, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _requestPayout(w),
                    icon: const Icon(Icons.account_balance),
                    label: Text(t('Request payout')),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(backgroundColor: ground, child: Icon(Icons.account_balance, color: brandCopper)),
              title: Text(t('Payout account'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(bank == null
                  ? t('Not added yet')
                  : '${bank['upi'] ?? ''}'.isNotEmpty && '${bank['account_no'] ?? ''}'.isEmpty
                      ? '${bank['upi']}'
                      : '${bank['account_name'] ?? ''} · ${_mask('${bank['account_no'] ?? ''}')} · ${bank['ifsc'] ?? ''}'),
              trailing: w['bank_locked'] == true ? null : TextButton(onPressed: () => _editBank(w), child: Text(t('Add'))),
            ),
            if (w['bank_locked'] == true) Text(t('To change your payout account, call Power Kothi support.'), style: const TextStyle(color: muted, fontSize: 12)),
            if (payouts.isNotEmpty) ...[
              const Divider(),
              Text(t('Payouts'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              for (final p in payouts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(p['status'] == 'paid' ? Icons.check_circle : (p['status'] == 'pending' ? Icons.schedule : Icons.cancel), color: p['status'] == 'paid' ? const Color(0xFF1F9D6B) : (p['status'] == 'pending' ? busyYellow : Colors.red.shade700)),
                  title: Text('${rupees(p['amount'])}${p['payout_no'] != null ? '  ·  ${p['payout_no']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p['date'] ?? ''}${p['utr'] != null ? ' · UTR ${p['utr']}' : ''}${p['note'] != null ? '\n${p['note']}' : ''}'),
                  trailing: Text(_payoutWord('${p['status']}')),
                ),
            ],
            const Divider(),
            Text(t('Transactions'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (tx.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(t('Earnings appear here when a charger you brought goes live.'), textAlign: TextAlign.center, style: const TextStyle(color: muted))),
            for (final x in tx)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: x['type'] == 'credit' ? const Color(0xFFE5F5EE) : const Color(0xFFFDECEA),
                  child: Icon(x['type'] == 'credit' ? Icons.south_west : Icons.north_east, color: x['type'] == 'credit' ? const Color(0xFF1F9D6B) : Colors.red.shade700, size: 18),
                ),
                title: Text('${x['remark'] ?? x['category'] ?? ''}'),
                subtitle: Text('${x['date'] ?? ''}'),
                trailing: Text('${x['type'] == 'credit' ? '+' : '−'}${rupees(x['amount'])}', style: TextStyle(color: x['type'] == 'credit' ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.w700)),
              ),
          ]),
        );
      },
    );
  }

  static String _mask(String a) => a.length <= 4 ? a : '•••• ${a.substring(a.length - 4)}';

  String _payoutWord(String s) {
    switch (s) {
      case 'paid':
        return t('Paid');
      case 'rejected':
        return t('Rejected');
      case 'reversed':
        return t('Reversed');
    }
    return t('Processing');
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ]),
      );
}
