import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'i18n.dart';
import 'widgets.dart';
import 'screens/favourites.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'screens/route_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  loadLanguage();
  await registerPush();
  runApp(const EvApp());
}

/// Push works once google-services.json is added (see README). The app runs fine without it.
Future<void> registerPush() async {
  try {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
    final tok = await FirebaseMessaging.instance.getToken();
    if (tok != null && Api.loggedIn) await Api.post('profile/device', {'fcm_token': tok});
  } catch (_) {}
}

class EvApp extends StatelessWidget {
  const EvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: language,
      builder: (context, lang, _) => MaterialApp(
        key: ValueKey(lang),
        title: 'Power Kothi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: brandCopper, primary: brandCopper, secondary: brandLight, surface: Colors.white),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(backgroundColor: brandCoal, foregroundColor: Colors.white),
          navigationBarTheme: NavigationBarThemeData(indicatorColor: brandLight.withOpacity(0.35)),
          useMaterial3: true,
        ),
        home: const Boot(),
      ),
    );
  }
}

class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  late Future<void> _f = _load();

  int _version(String v) {
    final p = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (p.length < 3) {
      p.add(0);
    }
    return p[0] * 10000 + p[1] * 100 + p[2];
  }

  Future<void> _load() async {
    Api.config = await Api.get('app/config') as Map<String, dynamic>;
    Api.masters = await Api.get('masters') as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(backgroundColor: brandCoal, body: Center(child: PulseLogo()));
        }
        if (snap.hasError) {
          return Scaffold(body: Message('${snap.error}', action: t('Try again'), onTap: () => setState(() => _f = _load())));
        }
        final mustUpdate = Api.config['force_update'] == true && _version(appVersion) < _version('${Api.config['min_app_version']}');
        if (mustUpdate) {
          return Scaffold(body: Message('${t('Update required')}\n${t('Please update the app to continue.')}'));
        }
        if (Api.prefs.getBool('seen_intro') != true) return const Onboarding();
        return const Shell();
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const HomeScreen(), if (_tab == 1) const FavouritesScreen() else const SizedBox(), const RoutePlanScreen(), if (_tab == 3) const ProfileScreen() else const SizedBox()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.ev_station), label: t('Find')),
          NavigationDestination(icon: const Icon(Icons.favorite), label: t('Saved')),
          NavigationDestination(icon: const Icon(Icons.alt_route), label: t('Route')),
          NavigationDestination(icon: const Icon(Icons.person), label: t('Profile')),
        ],
      ),
    );
  }
}
