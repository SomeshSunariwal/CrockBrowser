import '../../shared/widgets/crock_dropdown.dart';

import 'package:flutter/material.dart';

enum BrowsingDataTimeRange {
  lastHour('Last 1 Hr', Duration(hours: 1)),
  last24Hours('Last 24 Hr', Duration(hours: 24)),
  last30Days('Last 30 Days', Duration(days: 30)),
  all('All', null);

  const BrowsingDataTimeRange(this.label, this.duration);
  final String label;
  final Duration? duration;
}

class BrowsingDataSelection {
  BrowsingDataSelection(Set<String> categories, this.timeRange)
    : categories = Set.unmodifiable(categories);
  final Set<String> categories;
  final BrowsingDataTimeRange timeRange;
}

List<Map<String, dynamic>> historyOutsideTimeRange(
  List<Map<String, dynamic>> history,
  BrowsingDataTimeRange range,
  DateTime now,
) {
  if (range == BrowsingDataTimeRange.all) return [];
  final end = now.millisecondsSinceEpoch;
  final start = now.subtract(range.duration!).millisecondsSinceEpoch;
  return history.where((entry) {
    final created = entry['created'];
    // Older imports may have no timestamp; a bounded deletion cannot date them.
    if (created is! num || !created.isFinite) return true;
    return created < start || created > end;
  }).toList();
}

class BrowsingDataTimeRangeDropdown extends StatelessWidget {
  const BrowsingDataTimeRangeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final BrowsingDataTimeRange value;
  final ValueChanged<BrowsingDataTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Time range',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) =>
              CrockPopupMenuButton<BrowsingDataTimeRange>(
                key: const ValueKey('clear-time-range'),
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                constraints: BoxConstraints.tightFor(
                  width: constraints.maxWidth,
                ),
                initialValue: value,
                onSelected: onChanged,
                itemBuilder: (_) => [
                  for (final range in BrowsingDataTimeRange.values)
                    PopupMenuItem<BrowsingDataTimeRange>(
                      key: ValueKey('time-option-${range.name}'),
                      value: range,
                      height: 40,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              range.label,
                              style: TextStyle(
                                fontSize: 14,
                                color: range == value
                                    ? colors.primary
                                    : colors.onSurface,
                                fontWeight: range == value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (range == value)
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }
}
