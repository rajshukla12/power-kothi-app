import 'package:flutter/material.dart';
import '../api.dart';
import '../i18n.dart';

class FilterSheet extends StatefulWidget {
  final Map<String, dynamic> initial;
  const FilterSheet({super.key, required this.initial});
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final Map<String, dynamic> f = Map.of(widget.initial);

  Widget _drop(String label, String key, List<DropdownMenuItem<dynamic>> items) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<dynamic>(
          value: f[key],
          isExpanded: true,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          items: [const DropdownMenuItem<dynamic>(value: null, child: Text('Any')), ...items],
          onChanged: (v) => setState(() => v == null ? f.remove(key) : f[key] = v),
        ),
      );

  List<DropdownMenuItem<dynamic>> _master(String k) => ((Api.masters[k] as List?) ?? []).map((m) => DropdownMenuItem<dynamic>(value: m['id'], child: Text('${m['name']}'))).toList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _drop('Connector', 'connector_id', _master('connectors')),
          _drop('Charging', 'current', const [DropdownMenuItem(value: 'DC', child: Text('DC fast')), DropdownMenuItem(value: 'AC', child: Text('AC'))]),
          _drop('Minimum power', 'min_kw', const [DropdownMenuItem(value: 7, child: Text('7 kW')), DropdownMenuItem(value: 22, child: Text('22 kW')), DropdownMenuItem(value: 50, child: Text('50 kW')), DropdownMenuItem(value: 120, child: Text('120 kW'))]),
          _drop('Network', 'network_id', _master('networks')),
          _drop('Amenity', 'amenity_id', _master('amenities')),
          _drop('Sort by', 'sort', const [DropdownMenuItem(value: 'price', child: Text('Lowest price')), DropdownMenuItem(value: 'rating', child: Text('Best rated')), DropdownMenuItem(value: 'power', child: Text('Highest power'))]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Open 24×7'), value: f['is_24x7'] == 1, onChanged: (v) => setState(() => v ? f['is_24x7'] = 1 : f.remove('is_24x7'))),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('Available')), value: f['available'] == 1, onChanged: (v) => setState(() => v ? f['available'] = 1 : f.remove('available'))),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, <String, dynamic>{}), child: Text(t('Clear')))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, f), child: Text(t('Apply')))),
          ]),
        ]),
      ),
    );
  }
}
