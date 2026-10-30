import '../../../shared/widgets/crock_dialog.dart';

import 'package:flutter/material.dart';

import '../../privacy/browsing_data_time_range.dart';

class ClearWebsiteDataDialog extends StatefulWidget {
  const ClearWebsiteDataDialog({super.key, this.historyOnly = false});
  final bool historyOnly;

  @override
  State<ClearWebsiteDataDialog> createState() => _ClearWebsiteDataDialogState();
}

class _ClearWebsiteDataDialogState extends State<ClearWebsiteDataDialog> {
  late final selected = widget.historyOnly
      ? <String>{'history'}
      : <String>{'cookies', 'cache', 'storage'};
  BrowsingDataTimeRange timeRange = BrowsingDataTimeRange.all;
  static const options = [
    ('history', 'Browsing history'),
    ('cookies', 'Cookies'),
    ('cache', 'Cached images & files'),
    ('storage', 'Site storage'),
  ];

  @override
  Widget build(BuildContext context) => CrockDialog(
    title: Text(widget.historyOnly ? 'Clear history' : 'Clear website data'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.historyOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: BrowsingDataTimeRangeDropdown(
              value: timeRange,
              onChanged: (range) => setState(() {
                timeRange = range;
              }),
            ),
          ),
        if (!widget.historyOnly)
          for (final option in options)
            CheckboxListTile(
              key: ValueKey('clear-${option.$1}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              dense: true,
              checkboxShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(option.$2, style: const TextStyle(fontSize: 14)),
              value: selected.contains(option.$1),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  selected.add(option.$1);
                } else {
                  selected.remove(option.$1);
                }
              }),
            ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: selected.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                BrowsingDataSelection(selected, timeRange),
              ),
        child: Text(widget.historyOnly ? 'Clear history' : 'Clear data'),
      ),
    ],
  );
}
