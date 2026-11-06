import 'package:flutter/material.dart';
import '../api.dart';
import '../i18n.dart';
import '../main.dart';
import '../widgets.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _c = PageController();
  int _page = 0;

  Future<void> _finish({required bool askLocation}) async {
    if (askLocation) await currentLocation();
    await Api.prefs.setBool('seen_intro', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
  }

  @override
  Widget build(BuildContext context) {
    final slides = ((Api.config['intro'] as List?) ?? []).map((e) => '$e').toList();
    if (slides.isEmpty) slides.add('Find EV charging stations near you');
    final last = _page >= slides.length;
    return Scaffold(
      backgroundColor: brandCoal,
      body: SafeArea(
        child: Column(children: [
          const Padding(padding: EdgeInsets.only(top: 36), child: PulseLogo(width: 150)),
          Expanded(
            child: PageView(
              controller: _c,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final s in slides) _Slide(s),
                _Slide(t('We use your location to show chargers near you.')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: last
                ? Column(children: [
                    SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: brandCopper, foregroundColor: Colors.white), onPressed: () => _finish(askLocation: true), child: Text(t('Allow location')))),
                    TextButton(onPressed: () => _finish(askLocation: false), child: Text(t('Search by city instead'), style: const TextStyle(color: Colors.white))),
                  ])
                : SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: brandCopper, foregroundColor: Colors.white), onPressed: () => _c.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut), child: Text(t('Next')))),
          ),
        ]),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String text;
  const _Slide(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800))),
      );
}
