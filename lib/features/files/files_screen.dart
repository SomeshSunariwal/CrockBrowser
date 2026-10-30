import '../../shared/widgets/crock_switch.dart';
import '../../shared/widgets/crock_dropdown.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../../shared/widgets/editor_dialog.dart';
import 'archive_actions.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, this.media = false, this.initialPath});
  final bool media;
  final String? initialPath;
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<Map<String, dynamic>> files = [];
  final List<String> path = [];
  String filter = 'all', query = '';
  bool busy = true, device = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null) path.add(widget.initialPath!);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => busy = true);
    try {
      final rows = await NativeBridge.instance.list(
        device ? 'files.media' : 'files.list',
        device
            ? {
                'kind': filter == 'audio'
                    ? 'audio'
                    : filter == 'image'
                    ? 'image'
                    : 'video',
              }
            : path.isEmpty
            ? null
            : {'path': path.last},
      );
      if (mounted) {
        setState(() {
          files = rows;
          error = null;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = files
        .where(
          (file) =>
              file['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (filter == 'all' ||
                  device ||
                  (file['mime'] as String? ?? '').startsWith('$filter/')),
        )
        .toList();
    return FeatureScaffold(
      title: widget.media ? 'Media library' : 'Files',
      actions: [
        IconButton(
          tooltip: 'Import a file',
          onPressed: _import,
          icon: const Icon(Icons.file_upload_outlined),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                hintText: 'Search your files',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final kind in [
                  ('all', 'All files'),
                  ('video', 'Videos'),
                  ('audio', 'Audio'),
                  ('image', 'Images'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(kind.$2),
                      selected: filter == kind.$1,
                      onSelected: (_) async {
                        setState(() => filter = kind.$1);
                        if (device) {
                          if (filter == 'all') setState(() => device = false);
                          await _refresh();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (widget.media)
            CrockSwitchListTile(
              title: const Text('Include device media'),
              subtitle: const Text(
                'Grant access only when you want to browse device media.',
              ),
              value: device,
              onChanged: (value) async {
                if (value) {
                  final allowed = await NativeBridge.instance.call<bool>(
                    'device.permissions',
                    {
                      'permissions': [
                        'android.permission.READ_MEDIA_VIDEO',
                        'android.permission.READ_MEDIA_AUDIO',
                        'android.permission.READ_MEDIA_IMAGES',
                      ],
                    },
                  );
                  if (allowed != true) return;
                }
                setState(() {
                  device = value;
                  if (device && filter == 'all') filter = 'video';
                });
                await _refresh();
              },
            ),
          if (path.isNotEmpty && !device)
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Parent folder'),
              onTap: () {
                path.removeLast();
                _refresh();
              },
            ),
          Expanded(
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? CrockEmpty(
                    title: 'Could not list files',
                    detail: error!,
                    action: TextButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  )
                : rows.isEmpty
                ? CrockEmpty(
                    title: 'A home for your files',
                    detail: 'Downloaded and imported files appear here. Videos and audio open in Crock Player.',
                    action: FilledButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Import file'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final file = rows[index];
                        final directory = file['directory'] == true;
                        final mime = file['mime'] as String? ?? '';
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              directory
                                  ? Icons.folder_outlined
                                  : mime.startsWith('video/')
                                  ? Icons.play_circle_outline
                                  : mime.startsWith('audio/')
                                  ? Icons.music_note_outlined
                                  : mime.startsWith('image/')
                                  ? Icons.image_outlined
                                  : Icons.insert_drive_file_outlined,
                              color: const Color(0xFF087CFA),
                            ),
                            title: Text(
                              file['name'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              directory
                                  ? 'Folder'
                                  : byteLabel(file['size'] as num? ?? 0),
                            ),
                            onTap: () => _open(file),
                            trailing: device
                                ? null
                                : CrockPopupMenuButton<String>(
                                    onSelected: (action) =>
                                        _action(file, action),
                                    itemBuilder: (context) => [
                                      if (!directory)
                                        const PopupMenuItem(
                                          height: 40,
                                          value: 'share',
                                          child: Text('Share'),
                                        ),
                                      if (!directory)
                                        const PopupMenuItem(
                                          height: 40,
                                          value: 'export',
                                          child: Text('Save a copy…'),
                                        ),
                                      const PopupMenuItem(
                                        height: 40,
                                        value: 'rename',
                                        child: Text('Rename'),
                                      ),
                                      if (!directory &&
                                          isSupportedArchive(
                                            file['name'].toString(),
                                          ))
                                        const PopupMenuItem(
                                          height: 40,
                                          value: 'extract',
                                          child: Text('Extract archive'),
                                        ),
                                      if (!directory)
                                        const PopupMenuItem(
                                          height: 40,
                                          value: 'private',
                                          child: Text('Copy to Private Space'),
                                        ),
                                      if (!directory)
                                        const PopupMenuItem(
                                          height: 40,
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    try {
      await NativeBridge.instance.call('files.import');
      await _refresh();
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  Future<void> _open(Map<String, dynamic> file) async {
    try {
      if (file['directory'] == true) {
        path.add(file['path'] as String);
        await _refresh();
        return;
      }
      final mime = file['mime'] as String? ?? '';
      if (mime.startsWith('video/') || mime.startsWith('audio/')) {
        await NativeBridge.instance.call('media.play', {
          'path': file['path'],
          'uri': file['uri'],
        });
      } else if (mime.startsWith('image/')) {
        final data = await NativeBridge.instance.call<Uint8List>(
          'files.bytes',
          {'path': file['path'], 'uri': file['uri']},
        );
        if (data != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => FeatureScaffold(
                title: file['name'] as String,
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 6,
                  child: Center(child: Image.memory(data, fit: BoxFit.contain)),
                ),
              ),
            ),
          );
        }
      } else {
        await NativeBridge.instance.call('files.open', {'path': file['path']});
      }
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  Future<void> _action(Map<String, dynamic> file, String action) async {
    try {
      if (action == 'extract') {
        final folder = await extractArchive(context, file);
        if (folder != null && mounted) {
          setState(() => path.add(folder));
          await _refresh();
        }
        return;
      }
      if (action == 'delete' &&
          !await confirmCrock(
            context,
            'Delete file?',
            'This removes the app-managed file. Exported copies are kept.',
          )) {
        return;
      }
      String? name;
      if (action == 'rename') {
        if (!mounted) return;
        final input = TextEditingController(text: file['name'] as String);
        name = await showCrockDialog<String>(
          context: context,
          builder: (context) => CrockEditorDialog(
            title: 'Rename file',
            content: CrockEditorField(
              label: 'Filename',
              controller: input,
              autocorrect: false,
              textInputAction: TextInputAction.done,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, input.text.trim()),
                child: const Text('Rename'),
              ),
            ],
          ),
        );
        input.dispose();
        if (name == null || name.isEmpty) return;
      }
      if (action == 'private') {
        if (await NativeBridge.instance.call<bool>('vault.unlock') != true) {
          return;
        }
        await NativeBridge.instance.call('vault.import', {
          'path': file['path'],
          'name': file['name'],
        });
        await NativeBridge.instance.call('vault.lock');
        if (mounted) {
          crockMessage(
            context,
            'Encrypted copy added to Private Space. The original file is still in Files.',
          );
        }
      } else {
        await NativeBridge.instance.call('files.$action', {
          'path': file['path'],
          'name': name ?? file['name'],
          'mime': file['mime'],
        });
      }
      await _refresh();
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }
}
