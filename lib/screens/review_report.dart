import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

class ReviewScreen extends StatefulWidget {
  final int stationId;
  const ReviewScreen({super.key, required this.stationId});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _text = TextEditingController();
  final Set<String> _tags = {};
  final List<XFile> _photos = [];
  bool _busy = false;
  static const _quick = ['Charger working', 'Clean', 'Safe at night'];

  Future<void> _send() async {
    if (_rating == 0) {
      toast(context, 'Pick a star rating.');
      return;
    }
    setState(() => _busy = true);
    try {
      final files = <String, String>{};
      for (var i = 0; i < _photos.length; i++) {
        files['photo${i + 1}'] = _photos[i].path;
      }
      await Api.upload('stations/${widget.stationId}/review', {'rating': '$_rating', 'comment': _text.text, 'tags': _tags.join(',')}, files);
      if (mounted) {
        toast(context, 'Thanks. Your review will appear after a quick check.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Write a review'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++) IconButton(iconSize: 36, tooltip: '$i', icon: Icon(i <= _rating ? Icons.star : Icons.star_border, color: busyYellow), onPressed: () => setState(() => _rating = i)),
        ]),
        Wrap(spacing: 8, children: [
          for (final q in _quick) FilterChip(label: Text(q), selected: _tags.contains(q), onSelected: (v) => setState(() => v ? _tags.add(q) : _tags.remove(q))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _text, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(labelText: 'Your review', border: OutlineInputBorder())),
        OutlinedButton.icon(
          icon: const Icon(Icons.photo),
          label: Text('Add photos (${_photos.length}/3)'),
          onPressed: _photos.length >= 3
              ? null
              : () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
                  if (f != null) setState(() => _photos.add(f));
                },
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _busy ? null : _send, child: const Text('Post review')),
      ]),
    );
  }
}

class ReportScreen extends StatefulWidget {
  final int stationId;
  const ReportScreen({super.key, required this.stationId});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _types = {'charger_not_working': 'Charger not working', 'station_closed': 'Station closed', 'wrong_location': 'Wrong location', 'wrong_price': 'Wrong price', 'other': 'Other'};
  String _type = 'charger_not_working';
  final _note = TextEditingController();
  XFile? _photo;
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await Api.upload('stations/${widget.stationId}/report', {'type': _type, 'note': _note.text}, _photo == null ? {} : {'photo': _photo!.path});
      if (mounted) {
        toast(context, 'Report sent. Thank you.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        toast(context, '$e');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Report a problem'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in _types.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.value),
            leading: Icon(_type == e.key ? Icons.radio_button_checked : Icons.radio_button_off, color: brandCopper),
            onTap: () => setState(() => _type = e.key),
          ),
        TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_camera),
          label: Text(_photo == null ? 'Add photo' : 'Photo added'),
          onPressed: () async {
            final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
            if (f != null) setState(() => _photo = f);
          },
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _busy ? null : _send, child: const Text('Send report')),
      ]),
    );
  }
}
