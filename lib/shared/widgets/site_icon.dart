import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/services/site_icons.dart';
import '../../core/theme/crock_theme.dart';

class SiteIcon extends StatefulWidget {
  const SiteIcon({
    super.key,
    required this.url,
    this.size = 24,
    this.allowNetwork = true,
    this.fallbackLabel = '',
  });
  final String url;
  final double size;
  final bool allowNetwork;
  final String fallbackLabel;
  @override
  State<SiteIcon> createState() => _SiteIconState();
}

class _SiteIconState extends State<SiteIcon> {
  late Future<Uint8List?> icon;
  @override
  void initState() {
    super.initState();
    _load();
    SiteIcons.changes.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    SiteIcons.changes.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didUpdateWidget(SiteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.allowNetwork != widget.allowNetwork) {
      _load();
    }
  }

  void _load() {
    icon = SiteIcons.load(widget.url, allowNetwork: widget.allowNetwork);
  }

  Widget get fallback {
    final host = Uri.tryParse(widget.url)?.host ?? '';
    final label = widget.fallbackLabel.trim().isNotEmpty
        ? widget.fallbackLabel.trim()
        : host.replaceFirst(RegExp(r'^www\.'), '');
    final initial = label.isEmpty
        ? '?'
        : String.fromCharCode(label.runes.first).toUpperCase();
    return Text(
      initial,
      maxLines: 1,
      style: TextStyle(
        color: CrockTheme.blue,
        fontSize: widget.size * 0.7,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: ExcludeSemantics(
      child: FutureBuilder<Uint8List?>(
        future: icon,
        builder: (context, snapshot) => Center(
          child: snapshot.data == null
              ? fallback
              : Image.memory(
                  snapshot.data!,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, error, stackTrace) => fallback,
                ),
        ),
      ),
    ),
  );
}
