import 'package:flutter/material.dart';
import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

class BookingScreen extends StatefulWidget {
  final int stationId;
  const BookingScreen({super.key, required this.stationId});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _date = DateTime.now();
  String get _d => '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _book(int slot, VoidCallback reload) async {
    try {
      await Api.post('bookings', {'slot_id': slot});
      if (mounted) toast(context, 'Booked. The station will confirm it.');
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Book a slot'))),
      body: Column(children: [
        ListTile(
          leading: const Icon(Icons.calendar_month),
          title: Text(_d),
          trailing: const Text('Change'),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
            if (d != null) setState(() => _date = d);
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: Loader<List<dynamic>>(
            key: ValueKey(_d),
            load: () async => (await Api.get('stations/${widget.stationId}/slots', {'date': _d})) as List<dynamic>,
            builder: (rows, reload) => rows.isEmpty
                ? const Message('This station has no slots on this date.')
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final s = rows[i];
                      final free = s['available'] as int;
                      return ListTile(
                        title: Text('${'${s['start_time']}'.substring(0, 5)} - ${'${s['end_time']}'.substring(0, 5)}'),
                        subtitle: Text('${s['connector'] ?? ''}, $free left'),
                        trailing: FilledButton(onPressed: free > 0 ? () => _book(s['id'] as int, reload) : null, child: const Text('Book')),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('My bookings'))),
      body: Loader<List<dynamic>>(
        load: () async => (await Api.get('bookings')) as List<dynamic>,
        builder: (rows, reload) => rows.isEmpty
            ? const Message('No bookings yet.')
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final b = rows[i];
                  final live = b['status'] == 'pending' || b['status'] == 'confirmed';
                  return ListTile(
                    title: Text('${b['station']}'),
                    subtitle: Text('${b['slot_date']}, ${'${b['start_time']}'.substring(0, 5)}, ${b['status']}'),
                    trailing: live
                        ? TextButton(
                            onPressed: () async {
                              try {
                                await Api.delete('bookings/${b['id']}');
                              } catch (e) {
                                if (context.mounted) toast(context, '$e');
                              }
                              reload();
                            },
                            child: const Text('Cancel'),
                          )
                        : null,
                  );
                },
              ),
      ),
    );
  }
}
