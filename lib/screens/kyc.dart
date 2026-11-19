import 'package:flutter/material.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

/// Aadhaar OTP KYC + bank account check for partners.
/// API: GET partner/kyc · POST partner/kyc/aadhaar-otp {aadhaar} · POST partner/kyc/aadhaar-verify {otp} · POST partner/kyc/bank-check
class KycScreen extends StatefulWidget {
  const KycScreen({super.key, this.gate = false, this.onDone, this.onSignOut});

  /// gate = shown right after sign-up; the partner must verify Aadhaar before the dashboard opens.
  final bool gate;
  final VoidCallback? onDone;
  final VoidCallback? onSignOut;
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  Map<String, dynamic>? _k;
  String? _error;
  bool _busy = false;
  bool _otpSent = false;
  bool _test = false;
  final _aadhaar = TextEditingController();
  final _otp = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = Map<String, dynamic>.from(await Api.get('partner/kyc') as Map);
      if (mounted) {
        setState(() {
          _k = d;
          _otpSent = d['aadhaar'] == 'otp_sent';
          _test = d['test_mode'] == true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendOtp() => _run(() async {
        final a = _aadhaar.text.replaceAll(RegExp(r'\D'), '');
        if (a.length != 12) {
          toast(context, t('Enter all 12 digits of your Aadhaar.'));
          return;
        }
        final d = await Api.post('partner/kyc/aadhaar-otp', {'aadhaar': a}) as Map;
        if (!mounted) return;
        setState(() {
          _otpSent = true;
          _test = d['test_mode'] == true;
        });
        toast(context, t('OTP sent to the mobile number linked with your Aadhaar.'));
      });

  Future<void> _verify() => _run(() async {
        final d = await Api.post('partner/kyc/aadhaar-verify', {'otp': _otp.text.trim()});
        if (!mounted) return;
        setState(() => _k = Map<String, dynamic>.from(d as Map));
        toast(context, t('Aadhaar verified.'));
        if (widget.gate && _k?['aadhaar'] == 'verified') widget.onDone?.call();
      });

  Future<void> _bank() => _run(() async {
        final d = await Api.post('partner/kyc/bank-check', {});
        if (!mounted) return;
        setState(() => _k = Map<String, dynamic>.from(d as Map));
        toast(context, t('Bank account verified.'));
      });

  @override
  Widget build(BuildContext context) {
    final k = _k;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gate ? t('Verify your Aadhaar') : t('KYC verification')),
        automaticallyImplyLeading: !widget.gate,
        actions: [
          if (widget.gate && widget.onSignOut != null) IconButton(tooltip: t('Sign out'), onPressed: widget.onSignOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: k == null
          ? (_error != null ? Message(_error!, action: t('Try again'), onTap: _load) : const Center(child: CircularProgressIndicator()))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (widget.gate)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFE8F1FB), borderRadius: BorderRadius.circular(10)),
                  child: Text(t('Last step: verify your Aadhaar with the OTP sent to your Aadhaar-linked mobile. Then your dashboard opens.')),
                ),
              if (!widget.gate && k['required_for_payout'] == true && !(k['aadhaar'] == 'verified'))
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(10)),
                  child: Text(t('KYC is needed before you can take a payout.')),
                ),
              _aadhaarCard(k),
              if (!widget.gate) ...[
                const SizedBox(height: 12),
                _bankCard(k),
              ],
              if (widget.gate && k['aadhaar'] == 'verified') ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: widget.onDone, child: Text(t('Continue'))),
              ],
              const SizedBox(height: 16),
              Text(t('Your full Aadhaar number is not saved. Only the last 4 digits are kept.'), textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
            ]),
    );
  }

  Widget _card(IconData icon, String title, Widget status, List<Widget> children) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(icon, color: brandCopper), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), status]),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );

  Widget _chip(bool ok, String text, {bool bad = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: ok ? const Color(0xFFE5F5EE) : (bad ? const Color(0xFFFDECEA) : const Color(0xFFF0EEEC)), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ok ? const Color(0xFF1F9D6B) : (bad ? Colors.red.shade700 : muted))),
      );

  Widget _aadhaarCard(Map<String, dynamic> k) {
    final done = k['aadhaar'] == 'verified';
    return _card(Icons.badge_outlined, t('Aadhaar'), _chip(done, done ? t('Verified') : t('Not verified')), [
      if (done) ...[
        Text('${k['name'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text('XXXX XXXX ${k['aadhaar_last4'] ?? ''}', style: const TextStyle(color: muted)),
      ] else ...[
        TextField(
          controller: _aadhaar,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          maxLength: 14,
          decoration: InputDecoration(labelText: t('Aadhaar number'), hintText: '1234 5678 9012', border: const OutlineInputBorder(), counterText: ''),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : _sendOtp, child: Text(_otpSent ? t('Send OTP again') : t('Send OTP'))),
        if (_otpSent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otp,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(labelText: t('6-digit OTP'), helperText: _test ? 'Test mode: 1234' : t('Sent to the mobile linked with your Aadhaar'), border: const OutlineInputBorder(), counterText: ''),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _verify, child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t('Verify'))),
        ],
      ],
    ]);
  }

  Widget _bankCard(Map<String, dynamic> k) {
    final s = '${k['bank'] ?? 'none'}';
    final ok = s == 'verified';
    final bad = s == 'name_mismatch' || s == 'failed';
    return _card(Icons.account_balance, t('Bank account'), _chip(ok, ok ? t('Verified') : (bad ? t('Problem') : t('Not checked')), bad: bad), [
      if (k['bank_name_at_bank'] != null && '${k['bank_name_at_bank']}'.isNotEmpty) Text('${t('Name at bank')}: ${k['bank_name_at_bank']}'),
      if (k['bank_error'] != null && '${k['bank_error']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${k['bank_error']}', style: TextStyle(color: Colors.red.shade700))),
      if (!ok) ...[
        const SizedBox(height: 8),
        Text(t('Add your bank account in Wallet first. The name at the bank must match your Aadhaar.'), style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : _bank, child: Text(t('Check bank account'))),
      ],
    ]);
  }
}
