import 'dart:convert';

/// Netscape bookmark HTML is interoperable with desktop and mobile browsers.
abstract final class BookmarkExchange {
  static Map<String, List<Map<String, dynamic>>> parse(String text) {
    final bookmarks = <Map<String, dynamic>>[],
        folders = <Map<String, dynamic>>[];
    if (text.trimLeft().startsWith('{')) {
      final data = Map<String, dynamic>.from(jsonDecode(text) as Map);
      for (final item in (data['bookmarks'] as List? ?? [])) {
        bookmarks.add(Map<String, dynamic>.from(item as Map));
      }
      for (final item in (data['folders'] as List? ?? [])) {
        folders.add(Map<String, dynamic>.from(item as Map));
      }
      return {'bookmarks': bookmarks, 'folders': folders};
    }
    final pattern = RegExp(
      r'''<H3[^>]*>(.*?)</H3>|<DL[^>]*>|</DL>|<A[^>]*HREF\s*=\s*["']([^"']+)["'][^>]*>(.*?)</A>''',
      caseSensitive: false,
      dotAll: true,
    );
    final stack = <String>[''];
    String? pending;
    int sequence = 0;
    for (final token in pattern.allMatches(text)) {
      if (token.group(1) != null) {
        final id =
            'import_${DateTime.now().microsecondsSinceEpoch}_${sequence++}';
        folders.add({
          'id': id,
          'title': _decode(token.group(1)!),
          'parent': stack.last,
        });
        pending = id;
      } else if (token.group(2) != null) {
        final url = _decode(token.group(2)!);
        final uri = Uri.tryParse(url);
        if (uri != null && ['http', 'https'].contains(uri.scheme)) {
          bookmarks.add({
            'id':
                'import_${DateTime.now().microsecondsSinceEpoch}_${sequence++}',
            'url': url,
            'title': _decode(token.group(3) ?? url),
            'folder': stack.last,
          });
        }
      } else if (token.group(0)!.toUpperCase().startsWith('</DL')) {
        if (stack.length > 1) stack.removeLast();
      } else {
        stack.add(pending ?? stack.last);
        pending = null;
      }
    }
    return {'bookmarks': bookmarks, 'folders': folders};
  }

  static String html(
    List<Map<String, dynamic>> bookmarks,
    List<Map<String, dynamic>> folders,
  ) {
    const escape = HtmlEscape();
    final visited = <String>{};
    String branch(String parent) {
      if (!visited.add(parent)) return '';
      final out = StringBuffer('<DL><p>\n');
      for (final folder in folders.where(
        (f) => (f['parent'] ?? '') == parent,
      )) {
        out.write(
          '<DT><H3>${escape.convert(folder['title'] as String)}</H3>\n${branch(folder['id'] as String)}',
        );
      }
      for (final bookmark in bookmarks.where(
        (b) => (b['folder'] ?? '') == parent,
      )) {
        out.write(
          '<DT><A HREF="${escape.convert(bookmark['url'] as String)}">${escape.convert(bookmark['title'] as String)}</A>\n',
        );
      }
      out.write('</DL><p>\n');
      return out.toString();
    }

    return '<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">\n<TITLE>Crock Bookmarks</TITLE><H1>Bookmarks</H1>\n${branch('')}';
  }

  static String _decode(String value) => value
      .replaceAll(RegExp('<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}
