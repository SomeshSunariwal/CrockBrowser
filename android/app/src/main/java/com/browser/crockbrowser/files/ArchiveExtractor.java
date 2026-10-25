package com.browser.crockbrowser.files;

import com.github.junrar.Archive;
import com.github.junrar.ArchiveOptions;
import com.github.junrar.rarfile.FileHeader;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import org.apache.commons.compress.archivers.sevenz.SevenZArchiveEntry;
import org.apache.commons.compress.archivers.sevenz.SevenZFile;

/** Scoped, bounded extraction. Partial output is removed instead of presented as complete. */
public final class ArchiveExtractor {
  private static final long MAX_BYTES = 4L * 1024 * 1024 * 1024;
  private static final int MEMORY_KIB = 128 * 1024;
  private final File staging;
  private final Set<String> names = new HashSet<>();
  private final long started = android.os.SystemClock.elapsedRealtime();
  private long bytes;
  private int entries;

  private ArchiveExtractor(File root) throws IOException {
    staging = new File(root, ".extracting-" + UUID.randomUUID()).getCanonicalFile();
    if (!staging.mkdir()) throw new IOException("Cannot create extraction folder");
  }

  public static String extract(File root, File archive, String password) throws Exception {
    ArchiveExtractor operation = new ArchiveExtractor(root);
    boolean complete = false;
    try {
      String name = archive.getName().toLowerCase(Locale.ROOT);
      if (name.endsWith(".zip")) operation.zip(archive);
      else if (name.endsWith(".7z")) operation.sevenZip(archive, password);
      else if (name.endsWith(".rar")) operation.rar(archive, password);
      else throw new IOException("Choose a ZIP, RAR or 7z archive");
      if (operation.entries == 0) throw new IOException("Archive is empty or unreadable");
      File destination = new File(root, "Extracted_" + UUID.randomUUID());
      if (!operation.staging.renameTo(destination))
        throw new IOException("Cannot finish extraction");
      complete = true;
      return destination.getPath();
    } finally {
      if (!complete) operation.removePartial(operation.staging);
    }
  }

  private void check() throws IOException {
    if (Thread.currentThread().isInterrupted()
        || android.os.SystemClock.elapsedRealtime() - started > 5 * 60 * 1000)
      throw new IOException("Extraction stopped: time limit reached");
  }

  private File entry(String rawName, boolean directory, long size) throws IOException {
    check();
    if (++entries > 10000) throw new IOException("Archive contains more than 10,000 entries");
    if (size > MAX_BYTES - bytes)
      throw new IOException("Archive exceeds the 4 GB extraction limit");
    if (rawName == null || rawName.isBlank()) throw new IOException("Archive entry has no name");
    String name = rawName.replace('\\', '/');
    if (name.startsWith("/")
        || name.contains(":")
        || name.indexOf('\0') >= 0
        || name.split("/", -1).length > 64) throw new IOException("Unsafe archive path");
    for (String part : name.split("/"))
      if (part.equals("..")) throw new IOException("Unsafe archive path");
    File target = new File(staging, name).getCanonicalFile();
    if (!target.getPath().startsWith(staging.getPath() + File.separator)
        || !names.add(target.getPath())) throw new IOException("Unsafe or duplicate archive path");
    if (directory) {
      if (!target.isDirectory() && !target.mkdirs()) throw new IOException("Cannot create folder");
    } else {
      File parent = target.getParentFile();
      if (!parent.isDirectory() && !parent.mkdirs()) throw new IOException("Cannot create folder");
      if (!target.createNewFile()) throw new IOException("Archive entry already exists");
    }
    return target;
  }

  private OutputStream output(File target) throws IOException {
    return new FilterOutputStream(new BufferedOutputStream(new FileOutputStream(target))) {
      @Override
      public void write(int value) throws IOException {
        write(new byte[] {(byte) value}, 0, 1);
      }

      @Override
      public void write(byte[] data, int offset, int length) throws IOException {
        check();
        if (length > MAX_BYTES - bytes)
          throw new IOException("Archive exceeds the 4 GB extraction limit");
        out.write(data, offset, length);
        bytes += length;
      }
    };
  }

  private void zip(File source) throws IOException {
    try (ZipInputStream input =
        new ZipInputStream(new BufferedInputStream(new FileInputStream(source)))) {
      ZipEntry item;
      while ((item = input.getNextEntry()) != null) {
        File target = entry(item.getName(), item.isDirectory(), item.getSize());
        if (!item.isDirectory())
          try (OutputStream out = output(target)) {
            input.transferTo(out);
          }
        input.closeEntry();
      }
    }
  }

  private void sevenZip(File source, String password) throws IOException {
    SevenZFile.Builder builder =
        SevenZFile.builder().setFile(source).setMaxMemoryLimitKiB(MEMORY_KIB);
    if (!password.isEmpty()) builder.setPassword(password);
    try (SevenZFile input = builder.get()) {
      SevenZArchiveEntry item;
      byte[] buffer = new byte[64 * 1024];
      while ((item = input.getNextEntry()) != null) {
        if (item.isAntiItem()) throw new IOException("7z deletion entries are not supported");
        File target = entry(item.getName(), item.isDirectory(), item.getSize());
        if (!item.isDirectory())
          try (OutputStream out = output(target)) {
            int read;
            while ((read = input.read(buffer)) != -1) out.write(buffer, 0, read);
          }
      }
    }
  }

  private void rar(File source, String password) throws Exception {
    ArchiveOptions options =
        ArchiveOptions.builder()
            .maxDictionarySize((long) MEMORY_KIB * 1024)
            .password(password.isEmpty() ? null : password)
            .build();
    // InputStream volume manager cannot follow archive-controlled sibling filenames.
    try (InputStream stream = new BufferedInputStream(new FileInputStream(source));
        Archive input = new Archive(stream, options)) {
      FileHeader item;
      while ((item = input.nextFileHeader()) != null) {
        if (item.isSplitBefore() || item.isSplitAfter())
          throw new IOException("Split RAR volumes are not supported; use a single archive");
        if (item.getRedirection() != null) throw new IOException("Archive links are not supported");
        File target = entry(item.getFileName(), item.isDirectory(), item.getFullUnpackSize());
        if (!item.isDirectory())
          try (OutputStream out = output(target)) {
            input.extractFile(item, out);
          }
      }
    }
  }

  private void removePartial(File file) throws IOException {
    File canonical = file.getCanonicalFile();
    if (!canonical.equals(staging)
        && !canonical.getPath().startsWith(staging.getPath() + File.separator))
      throw new IOException("Unsafe partial extraction path");
    File[] children = canonical.listFiles();
    if (children != null) for (File child : children) removePartial(child);
    if (canonical.exists() && !canonical.delete())
      throw new IOException("Cannot remove incomplete extraction");
  }
}
