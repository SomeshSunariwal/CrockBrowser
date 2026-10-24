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

class BrowsingDataTimeRangeDropdown extends StatefulWidget {
  const BrowsingDataTimeRangeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final BrowsingDataTimeRange value;
  final ValueChanged<BrowsingDataTimeRange> onChanged;

  @override
  State<BrowsingDataTimeRangeDropdown> createState() =>
      _TimeRangeDropdownState();
}

class _TimeRangeDropdownState extends State<BrowsingDataTimeRangeDropdown> {
  final fieldKey = GlobalKey();
  double menuWidth = 240;

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
        MenuAnchor(
          key: const ValueKey('clear-time-range'),
          animated: !MediaQuery.disableAnimationsOf(context),
          consumeOutsideTap: true,
          crossAxisUnconstrained: false,
          alignmentOffset: const Offset(0, 8),
          style: MenuStyle(
            alignment: Alignment.bottomLeft,
            backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(4),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
            fixedSize: WidgetStatePropertyAll(Size(menuWidth, double.infinity)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            side: WidgetStatePropertyAll(
              BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
            ),
          ),
          menuChildren: [
            for (final range in BrowsingDataTimeRange.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: MenuItemButton(
                  key: ValueKey('time-option-${range.name}'),
                  onPressed: () => widget.onChanged(range),
                  style: ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size(menuWidth - 12, 44),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    backgroundColor: WidgetStatePropertyAll(
                      range == widget.value
                          ? colors.primary.withValues(alpha: .12)
                          : Colors.transparent,
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      range == widget.value ? colors.primary : colors.onSurface,
                    ),
                  ),
                  trailingIcon: range == widget.value
                      ? const Icon(Icons.check_rounded, size: 18)
                      : const SizedBox(width: 18),
                  child: Text(
                    range.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: range == widget.value
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
          builder: (context, controller, _) => OutlinedButton(
            key: fieldKey,
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
                return;
              }
              final width = fieldKey.currentContext?.size?.width;
              if (width != null && width != menuWidth) {
                setState(() => menuWidth = width);
              }
              controller.open();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              foregroundColor: colors.onSurface,
              backgroundColor: colors.surfaceContainerLow,
              side: BorderSide(color: colors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.value.label,
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
      ],
    );
  }
}
