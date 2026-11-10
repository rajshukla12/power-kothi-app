import 'package:flutter/material.dart';
import '../api.dart';
import '../i18n.dart';
import '../main.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  /// Set when login is the app's first screen; otherwise the screen pops with true.
  final VoidCallback? onDone;
  const LoginScreen({super.key, this.onDone});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobile = TextEditingController();
  final _otp = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await Api.post('auth/send-otp', {'mobile': _mobile.text.trim()});
      if (r is Map && r['dev_otp'] != null) _otp.text = '${r['dev_otp']}';
      if (r is Map && r['otp_test_mode'] == true) Api.config['otp_test_mode'] = true;
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final r = await Api.post('auth/verify-otp', {'mobile': _mobile.text.trim(), 'otp': _otp.text.trim()}) as Map<String, dynamic>;
      await Api.saveLogin('${r['token']}', r['user'] as Map<String, dynamic>);
      await registerPush();
      if (!mounted) return;
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.onDone == null ? AppBar(title: Text(t('Sign in'))) : null,
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.onDone != null) ...[
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(color: brandCoal, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const PulseLogo(width: 170),
                const SizedBox(height: 10),
                Text(t('Partner app'), style: const TextStyle(color: brandLight, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 26),
            Text(t('Sign in with your mobile number'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t('We send an OTP to verify it is you.'), style: const TextStyle(color: muted)),
            const SizedBox(height: 18),
          ],
          TextField(controller: _mobile, enabled: !_sent, keyboardType: TextInputType.phone, maxLength: 10, autofillHints: const [AutofillHints.telephoneNumberNational], decoration: InputDecoration(labelText: t('Mobile number'), prefixText: '+91 ', border: const OutlineInputBorder())),
          if (_sent && Api.config['otp_test_mode'] == true)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: brandLight.withOpacity(.18), borderRadius: BorderRadius.circular(10)),
              child: Text(t('SMS is not active yet. Enter 1234 as OTP.')),
            ),
          if (_sent) TextField(controller: _otp, autofocus: true, keyboardType: TextInputType.number, maxLength: 6, autofillHints: const [AutofillHints.oneTimeCode], decoration: InputDecoration(labelText: t('Enter OTP'), border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : (_sent ? _verify : _send), child: Text(t(_sent ? 'Verify' : 'Send OTP'))),
          if (_sent)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _sent = false;
                        _otp.clear();
                      }),
              child: Text(t('Change number')),
            ),
        ],
        ),
      ),
    );
  }
}
