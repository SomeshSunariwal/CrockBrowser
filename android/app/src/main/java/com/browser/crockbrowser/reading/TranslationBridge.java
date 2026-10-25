package com.browser.crockbrowser.reading;

import com.google.mlkit.common.model.DownloadConditions;
import com.google.mlkit.nl.translate.TranslateLanguage;
import com.google.mlkit.nl.translate.Translation;
import com.google.mlkit.nl.translate.Translator;
import com.google.mlkit.nl.translate.TranslatorOptions;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;

/** On-device translation. Language models download only after an explicit translate action. */
public final class TranslationBridge {
  public static void translate(Map<String, Object> args, MethodChannel.Result result) {
    String text = String.valueOf(args.getOrDefault("text", ""));
    if (text.length() > 50000) {
      result.error("TRANSLATION", "Select a shorter passage (up to 50,000 characters)", null);
      return;
    }
    String
        source =
            TranslateLanguage.fromLanguageTag(String.valueOf(args.getOrDefault("source", "en"))),
        target =
            TranslateLanguage.fromLanguageTag(String.valueOf(args.getOrDefault("target", "hi")));
    if (source == null || target == null) {
      result.error("TRANSLATION", "This language is not supported by the on-device model", null);
      return;
    }
    Translator translator =
        Translation.getClient(
            new TranslatorOptions.Builder()
                .setSourceLanguage(source)
                .setTargetLanguage(target)
                .build());
    translator
        .downloadModelIfNeeded(new DownloadConditions.Builder().build())
        .addOnSuccessListener(
            v ->
                translator
                    .translate(text)
                    .addOnSuccessListener(
                        translated -> {
                          translator.close();
                          result.success(translated);
                        })
                    .addOnFailureListener(
                        error -> {
                          translator.close();
                          result.error("TRANSLATION", error.getMessage(), null);
                        }))
        .addOnFailureListener(
            error -> {
              translator.close();
              result.error("MODEL_DOWNLOAD", error.getMessage(), null);
            });
  }
}
