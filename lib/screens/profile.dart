import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';
import 'booking.dart';
import 'suggest.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _gated(Widget page) async {
    if (await needLogin(context)) {
      if (mounted) {
        setState(() {});
        _open(page);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Delete account')),
        content: const Text('Your name, vehicles, favourites and reviews will be removed. This cannot be undone.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep account')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Delete account')))],
      ),
    );
    if (yes != true) return;
    try {
      await Api.delete('profile');
      await Api.logout();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = Api.user;
    final support = (Api.config['support'] as Map?) ?? {};
    return Scaffold(
      appBar: AppBar(title: Text(t('Profile'))),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Image.asset('assets/word.png', height: 44, alignment: Alignment.centerLeft)),
        if (u == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                await needLogin(context);
                if (mounted) setState(() {});
              },
              child: Text(t('Sign in')),
            ),
          )
        else
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('${u['name'] ?? u['mobile']}'),
            subtitle: Text('${u['mobile']}'),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfile()));
              if (mounted) setState(() {});
            },
          ),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.directions_car), title: Text(t('My vehicles')), onTap: () => _gated(const VehiclesScreen())),
        ListTile(leading: const Icon(Icons.event), title: Text(t('My bookings')), onTap: () => _gated(const MyBookingsScreen())),
        ListTile(leading: const Icon(Icons.report), title: Text(t('My reports')), onTap: () => _gated(const MyReportsScreen())),
        ListTile(leading: const Icon(Icons.notifications), title: Text(t('Notifications')), onTap: () => _gated(const NotificationsScreen())),
        ListTile(leading: const Icon(Icons.add_location_alt), title: Text(t('Suggest a station')), onTap: () => _gated(const SuggestScreen())),
        ListTile(leading: const Icon(Icons.fact_check), title: const Text('My submitted stations'), onTap: () => _gated(const MySuggestionsScreen())),
        ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('My wallet'), onTap: () => _gated(const WalletScreen())),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(t('Language')),
          trailing: DropdownButton<String>(
            value: language.value,
            underline: const SizedBox(),
            items: const [DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'hi', child: Text('हिन्दी'))],
            onChanged: (v) {
              if (v != null) setLanguage(v);
            },
          ),
        ),
        if ('${support['phone'] ?? ''}'.isNotEmpty) ListTile(leading: const Icon(Icons.call), title: const Text('Call support'), onTap: () => launchUrl(Uri.parse('tel:${support['phone']}'))),
        if ('${support['email'] ?? ''}'.isNotEmpty) ListTile(leading: const Icon(Icons.mail), title: const Text('Email support'), onTap: () => launchUrl(Uri.parse('mailto:${support['email']}'))),
        if (u != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t('Sign out')),
            onTap: () async {
              await Api.logout();
              if (mounted) setState(() {});
            },
          ),
          ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: Text(t('Delete account')), onTap: _deleteAccount),
        ],
      ]),
    );
  }
}

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});
  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _name = TextEditingController(text: '${Api.user?['name'] ?? ''}');
  final _email = TextEditingController(text: '${Api.user?['email'] ?? ''}');

  Future<void> _save() async {
    try {
      final u = await Api.put('profile', {'name': _name.text.trim(), 'email': _email.text.trim()}) as Map<String, dynamic>;
      await Api.saveUser(u);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Profile'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: t('Name'), border: const OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: t('Email'), border: const OutlineInputBorder())),
          const SizedBox(height: 10),
          FilledButton(onPressed: _save, child: Text(t('Save'))),
        ]),
      ),
    );
  }
}

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  Future<void> _add(BuildContext context, VoidCallback reload) async {
    final models = ((Api.masters['vehicle_models'] as List?) ?? []);
    final brands = {for (final b in ((Api.masters['vehicle_brands'] as List?) ?? [])) b['id']: b['name']};
    final id = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => ListView(children: [
        for (final m in models) ListTile(title: Text('${brands[m['brand_id']] ?? ''} ${m['name']}'), subtitle: Text(m['battery_kwh'] != null ? '${m['battery_kwh']} kWh' : ''), onTap: () => Navigator.pop(c, m['id'] as int)),
      ]),
    );
    if (id == null) return;
    try {
      await Api.post('vehicles', {'model_id': id});
    } catch (e) {
      if (context.mounted) toast(context, '$e');
    }
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('My vehicles'))),
      body: Loader<List<dynamic>>(
        load: () async => (await Api.get('vehicles')) as List<dynamic>,
        builder: (rows, reload) => Stack(children: [
          if (rows.isEmpty) const Message('Add your EV to see stations with the right connector.'),
          ListView(children: [
            for (final v in rows)
              ListTile(
                title: Text('${v['brand']} ${v['model']}'),
                subtitle: Text('${v['connector'] ?? ''}${v['battery_kwh'] != null ? ', ${v['battery_kwh']} kWh' : ''}'),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await Api.delete('vehicles/${v['id']}');
                    reload();
                  },
                ),
              ),
          ]),
          Positioned(right: 16, bottom: 16, child: FloatingActionButton(tooltip: 'Add vehicle', onPressed: () => _add(context, reload), child: const Icon(Icons.add))),
        ]),
      ),
    );
  }
}

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('My reports'))),
        body: Loader<List<dynamic>>(
          load: () async => (await Api.get('my/reports')) as List<dynamic>,
          builder: (rows, reload) => rows.isEmpty
              ? const Message('No reports yet.')
              : ListView(children: [for (final r in rows) ListTile(title: Text('${r['station']}'), subtitle: Text('${r['type']}'.replaceAll('_', ' ')), trailing: Text('${r['status']}'.replaceAll('_', ' ')))]),
        ),
      );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Notifications'))),
        body: Loader<List<dynamic>>(
          load: () async => (await Api.get('notifications')) as List<dynamic>,
          builder: (rows, reload) => rows.isEmpty
              ? const Message('No notifications yet.')
              : ListView(children: [
                  for (final n in rows)
                    ListTile(
                      title: Text('${n['title']}'),
                      subtitle: Text('${n['body']}'),
                      onTap: n['deep_link_station_id'] == null ? null : () => openStation(context, n['deep_link_station_id'] as int),
                    ),
                ]),
        ),
      );
}

class MySuggestionsScreen extends StatelessWidget {
  const MySuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My submitted stations')),
        body: Loader<List<dynamic>>(
          load: () async => (await Api.get('my/suggestions')) as List<dynamic>,
          builder: (rows, reload) => rows.isEmpty
              ? const Message('You have not submitted a station yet.')
              : ListView(children: [
                  for (final r in rows)
                    ListTile(
                      title: Text('${r['name']}'),
                      subtitle: r['reject_reason'] == null ? null : Text('${r['reject_reason']}'),
                      trailing: Text('${r['status']}'),
                      onTap: r['station_id'] == null ? null : () => openStation(context, r['station_id'] as int),
                    ),
                ]),
        ),
      );
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My wallet')),
        body: Loader<Map<String, dynamic>>(
          load: () async => (await Api.get('wallet')) as Map<String, dynamic>,
          builder: (w, reload) {
            final tx = ((w['transactions'] as List?) ?? []).cast<dynamic>();
            return ListView(children: [
              Padding(padding: const EdgeInsets.all(20), child: Text('₹${w['balance']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
              const Divider(height: 1),
              if (tx.isEmpty) const Message('No transactions yet.'),
              for (final x in tx)
                ListTile(
                  title: Text('${x['remark'] ?? x['category']}'),
                  subtitle: Text('${x['date']}'),
                  trailing: Text('${x['type'] == 'credit' ? '+' : '-'}₹${x['amount']}', style: TextStyle(color: x['type'] == 'credit' ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.w700)),
                ),
            ]);
          },
        ),
      );
}
