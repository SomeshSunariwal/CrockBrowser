import 'dart:typed_data';

class BrowserTab {
  BrowserTab({String? id, this.url = '', this.title = 'New tab'})
    : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  String url;
  String title;
  bool atHome = true;
  bool loading = false;
  bool desktop = false;
  bool failed = false;
  double progress = 0;
  bool canBack = false;
  bool canForward = false;
  Uint8List? thumbnail;
  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'title': title,
    'home': atHome,
    'desktop': desktop,
  };
  factory BrowserTab.fromMap(Map<String, dynamic> map) {
    return BrowserTab(
        id: map['id'] as String?,
        url: map['url'] as String? ?? '',
        title: map['title'] as String? ?? 'New tab',
      )
      ..atHome = map['home'] != false
      ..desktop = map['desktop'] == true;
  }
}
