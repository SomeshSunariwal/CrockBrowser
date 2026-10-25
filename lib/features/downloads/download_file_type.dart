import 'package:flutter/material.dart';

({IconData icon, String label}) downloadFileType(String name, String mime) {
  final extension = name.toLowerCase().split('.').last;
  final type = mime.toLowerCase().split(';').first.trim();
  bool matches(String extensions) => extensions.split(' ').contains(extension);

  if (type == 'application/pdf' || matches('pdf')) {
    return (icon: Icons.picture_as_pdf_outlined, label: 'PDF file');
  }
  if (type.startsWith('video/') ||
      matches('mp4 m4v mkv webm mov avi mpg mpeg 3gp ts m2ts')) {
    return (icon: Icons.videocam_rounded, label: 'Video file');
  }
  if (type.startsWith('audio/') ||
      matches('mp3 m4a aac wav flac ogg opus wma aiff mid midi')) {
    return (icon: Icons.audio_file_outlined, label: 'Audio file');
  }
  if (type.startsWith('image/') ||
      matches('jpg jpeg png gif webp svg heic heif avif bmp tiff ico')) {
    return (icon: Icons.image_outlined, label: 'Image file');
  }
  if (type == 'application/vnd.android.package-archive' ||
      matches('apk apks xapk aab')) {
    return (icon: Icons.android_rounded, label: 'Android app');
  }
  if (type.contains('zip') ||
      type.contains('compressed') ||
      type == 'application/x-tar' ||
      matches('zip rar 7z tar gz bz2 xz tgz zst')) {
    return (icon: Icons.folder_zip_outlined, label: 'Archive file');
  }
  if (type.contains('spreadsheet') ||
      type.contains('excel') ||
      matches('xls xlsx ods csv tsv')) {
    return (icon: Icons.table_chart_outlined, label: 'Spreadsheet');
  }
  if (type.contains('presentation') ||
      type.contains('powerpoint') ||
      matches('ppt pptx odp')) {
    return (icon: Icons.slideshow_outlined, label: 'Presentation');
  }
  if (type.contains('word') ||
      type == 'application/rtf' ||
      type == 'application/vnd.oasis.opendocument.text' ||
      matches('doc docx odt rtf epub mobi')) {
    return (icon: Icons.description_outlined, label: 'Document');
  }
  if (type.contains('json') ||
      type.contains('javascript') ||
      type.contains('xml') ||
      matches(
        'html htm css js ts jsx tsx json xml yaml yml py java kt dart c cpp h sh',
      )) {
    return (icon: Icons.code_rounded, label: 'Code file');
  }
  if (type.startsWith('text/') || matches('txt md log srt vtt')) {
    return (icon: Icons.text_snippet_outlined, label: 'Text file');
  }
  if (type.startsWith('font/') || matches('ttf otf woff woff2')) {
    return (icon: Icons.font_download_outlined, label: 'Font file');
  }
  return (icon: Icons.insert_drive_file_outlined, label: 'File');
}
