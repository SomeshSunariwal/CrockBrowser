import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/platform/native_bridge.dart';
import '../../../core/storage/browser_store.dart';
import '../../../shared/widgets/feature_scaffold.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key, required this.store});
  final BrowserStore store;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  final _name = TextEditingController();
  bool _editing = false, _picking = false;

  String get name =>
      widget.store.setting('profileName', 'Your Browser') as String;

  void _saveName() {
    final value = _name.text.trim();
    if (value.isEmpty) return;
    widget.store.setSetting('profileName', value);
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final path = await NativeBridge.instance.call<String>(
        'profile.pickPhoto',
      );
      if (path == null) return;
      final previous = widget.store.setting('profilePhoto', '') as String;
      widget.store.setSetting('profilePhoto', path);
      await widget.store.flush();
      if (widget.store.saveError == null &&
          previous.isNotEmpty &&
          previous != path) {
        final oldPhoto = File(previous);
        if (oldPhoto.parent.path == File(path).parent.path &&
            await oldPhoto.exists()) {
          await oldPhoto.delete();
        }
      }
    } catch (error) {
      if (mounted) {
        crockMessage(
          context,
          'Could not update profile photo. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = widget.store.setting('profilePhoto', '') as String;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final editStyle = TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide.none,
    );
    final placeholder = Icon(
      Icons.person_rounded,
      size: 46,
      color: colors.primary,
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.surfaceContainerLow, colors.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Update profile photo',
            button: true,
            child: InkWell(
              onTap: _picking ? null : _pickPhoto,
              borderRadius: BorderRadius.circular(38),
              child: SizedBox.square(
                dimension: 76,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        Color(0xFF7045D9),
                        Color(0xFFF23BAD),
                        Color(0xFFFFA33C),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: ColoredBox(
                        color: Color.alphaBlend(
                          colors.primary.withValues(alpha: .1),
                          colors.surface,
                        ),
                        child: photo.isEmpty
                            ? placeholder
                            : Image.file(
                                File(photo),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) => placeholder,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _editing
                        ? TextField(
                            controller: _name,
                            autofocus: true,
                            style: titleStyle,
                            maxLength: 40,
                            textInputAction: TextInputAction.done,
                            scrollPadding: EdgeInsets.zero,
                            onSubmitted: (_) => _saveName(),
                            decoration: const InputDecoration(
                              hintText: 'Browser name',
                              counterText: '',
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          )
                        : Text(
                            name,
                            style: titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
                SizedBox(
                  height: 26,
                  child: Row(
                    children: [
                      TextButton.icon(
                        style: editStyle,
                        onPressed: _editing
                            ? _saveName
                            : () {
                                _name.text = name;
                                setState(() => _editing = true);
                              },
                        icon: Icon(
                          _editing ? Icons.check_rounded : Icons.edit_outlined,
                          size: 14,
                        ),
                        label: Text(
                          _editing ? 'Save' : 'Edit name',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (_editing) ...[
                        const SizedBox(width: 16),
                        TextButton(
                          style: editStyle,
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() => _editing = false);
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
