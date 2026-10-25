package com.browser.crockbrowser.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;

public final class JsonCodec {
  private JsonCodec() {}

  public static Map<String, Object> arguments(Object value) {
    if (!(value instanceof Map<?, ?> source)) return Collections.emptyMap();
    Map<String, Object> result = new LinkedHashMap<>();
    source.forEach((key, item) -> result.put((String) key, item));
    return result;
  }

  public static List<String> strings(Object value) {
    List<String> result = new ArrayList<>();
    if (value != null) for (Object item : (List<?>) value) result.add((String) item);
    return result;
  }

  public static Object unwrap(Object value) throws Exception {
    if (value == JSONObject.NULL) return null;
    if (value instanceof JSONObject) {
      Map<String, Object> result = new LinkedHashMap<>();
      Iterator<String> keys = ((JSONObject) value).keys();
      while (keys.hasNext()) {
        String key = keys.next();
        result.put(key, unwrap(((JSONObject) value).get(key)));
      }
      return result;
    }
    if (value instanceof JSONArray) {
      List<Object> result = new ArrayList<>();
      for (int i = 0; i < ((JSONArray) value).length(); i++)
        result.add(unwrap(((JSONArray) value).get(i)));
      return result;
    }
    return value;
  }

  public static String string(Map<?, ?> map, String key, String fallback) {
    Object value = map.get(key);
    return value == null ? fallback : value.toString();
  }

  public static int integer(Map<?, ?> map, String key, int fallback) {
    Object value = map.get(key);
    return value instanceof Number ? ((Number) value).intValue() : fallback;
  }

  public static Map<String, Object> map(Object... values) {
    Map<String, Object> result = new LinkedHashMap<>();
    for (int i = 0; i < values.length; i += 2) result.put(values[i].toString(), values[i + 1]);
    return result;
  }
}
