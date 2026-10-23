package com.example.crocbrowser.core;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.CipherInputStream;
import javax.crypto.CipherOutputStream;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** AES-GCM data files, with a non-exportable Android Keystore key. Backup is disabled. */
public final class EncryptedStore {
  private final Context context;

  public EncryptedStore(Context context) {
    this.context = context.getApplicationContext();
  }

  private synchronized SecretKey key() throws Exception {
    String alias = "croc.local.v1";
    KeyStore store = KeyStore.getInstance("AndroidKeyStore");
    store.load(null);
    if (store.containsAlias(alias)) return (SecretKey) store.getKey(alias, null);
    KeyGenerator generator =
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
    generator.init(
        new KeyGenParameterSpec.Builder(
                alias, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build());
    return generator.generateKey();
  }

  public byte[] encrypt(byte[] plain) throws Exception {
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(Cipher.ENCRYPT_MODE, key());
    byte[] body = cipher.doFinal(plain), iv = cipher.getIV();
    byte[] result = new byte[1 + iv.length + body.length];
    result[0] = (byte) iv.length;
    System.arraycopy(iv, 0, result, 1, iv.length);
    System.arraycopy(body, 0, result, 1 + iv.length, body.length);
    return result;
  }

  public byte[] decrypt(byte[] encrypted) throws Exception {
    int size = encrypted[0] & 255;
    if (size < 12 || size > 16 || encrypted.length < size + 17)
      throw new SecurityException("Invalid encrypted data");
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(
        Cipher.DECRYPT_MODE,
        key(),
        new GCMParameterSpec(128, Arrays.copyOfRange(encrypted, 1, 1 + size)));
    return cipher.doFinal(encrypted, 1 + size, encrypted.length - size - 1);
  }

  public void encryptFile(File source, File destination) throws Exception {
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(Cipher.ENCRYPT_MODE, key());
    try (InputStream input = new FileInputStream(source);
        OutputStream raw = new FileOutputStream(destination)) {
      byte[] iv = cipher.getIV();
      raw.write(iv.length);
      raw.write(iv);
      try (CipherOutputStream output = new CipherOutputStream(raw, cipher)) {
        input.transferTo(output);
      }
    } catch (Exception error) {
      destination.delete();
      throw error;
    }
  }

  public void decryptFile(File source, File destination) throws Exception {
    try (InputStream raw = new FileInputStream(source)) {
      int length = raw.read();
      if (length < 12 || length > 16) throw new IOException("Invalid encrypted file");
      byte[] iv = raw.readNBytes(length);
      if (iv.length != length) throw new IOException("Truncated encrypted file");
      Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
      cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, iv));
      try (InputStream input = new CipherInputStream(raw, cipher);
          OutputStream output = new FileOutputStream(destination)) {
        input.transferTo(output);
      }
    } catch (Exception error) {
      destination.delete();
      throw error;
    }
  }

  @FunctionalInterface
  public interface Transform {
    String apply(String current) throws Exception;
  }

  private static final Object PROCESS_LOCK = new Object();

  public void update(String name, Transform transform) throws Exception {
    synchronized (PROCESS_LOCK) {
      try (java.io.RandomAccessFile guard =
              new java.io.RandomAccessFile(
                  new File(context.getNoBackupFilesDir(), name + ".lock"), "rw");
          java.nio.channels.FileLock lock = guard.getChannel().lock()) {
        write(name, transform.apply(read(name, "{}")));
      }
    }
  }

  private File file(String name) {
    if (!name.matches("[a-zA-Z0-9_.-]+")) throw new IllegalArgumentException("Invalid storage key");
    return new File(context.getNoBackupFilesDir(), name + ".enc");
  }

  public synchronized String read(String name, String fallback) throws Exception {
    File file = file(name);
    if (!file.exists()) return fallback;
    return new String(decrypt(new AtomicFile(file).readFully()), StandardCharsets.UTF_8);
  }

  public synchronized void write(String name, String text) throws Exception {
    AtomicFile file = new AtomicFile(file(name));
    FileOutputStream output = null;
    try {
      output = file.startWrite();
      output.write(encrypt(text.getBytes(StandardCharsets.UTF_8)));
      file.finishWrite(output);
    } catch (Exception error) {
      if (output != null) file.failWrite(output);
      throw error;
    }
  }
}
