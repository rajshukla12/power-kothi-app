import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});
  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  @override
  Widget build(BuildContext context) {
    final raw = Api.prefs.getString('recent');
    final recent = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
    return Scaffold(
      appBar: AppBar(title: Text(t('Saved'))),
      body: ListView(children: [
        if (!Api.loggedIn)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () async {
                await needLogin(context);
                if (mounted) setState(() {});
              },
              child: Text('${t('Sign in')}: ${t('Saved')}'),
            ),
          )
        else
          SizedBox(
            height: 340,
            child: Loader<List<dynamic>>(
              load: () async => (await Api.get('favourites')) as List<dynamic>,
              builder: (rows, reload) => rows.isEmpty
                  ? const Message('Tap the heart on a station to save it here.')
                  : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => StationTile(rows[i] as Map<String, dynamic>)),
            ),
          ),
        if (recent.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 4), child: Text(t('Recently viewed'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        for (final r in recent) ListTile(title: Text('${r['name']}'), subtitle: Text('${r['city'] ?? ''}'), onTap: () => openStation(context, r['id'] as int)),
      ]),
    );
  }
}
