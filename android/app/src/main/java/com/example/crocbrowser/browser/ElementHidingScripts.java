package com.example.crocbrowser.browser;

import org.json.JSONArray;
import org.json.JSONObject;

/** User-selected cosmetic filtering. No page-to-native interface is exposed. */
public final class ElementHidingScripts {
  private ElementHidingScripts() {}

  public static String pick(double x, double y, String url) {
    return "(() => { const x="
        + x
        + ", y="
        + y
        + ", expected="
        + JSONObject.quote(url)
        + ";"
        + PICK
        + "})()";
  }

  // Coordinates are fractions of the visible native WebView, including at page zoom.
  static final String PICK =
      """
      if (location.href !== expected) return null;
      const viewport = window.visualViewport;
      const px = x * (viewport ? viewport.width : innerWidth);
      const py = y * (viewport ? viewport.height : innerHeight);
      let element = document.elementFromPoint(px, py);
      if (!element || ['HTML', 'BODY'].includes(element.tagName)) return null;
      // A cross-origin ad frame can be selected as a whole; its contents stay isolated.
      element = element.closest('iframe,[data-ad-slot],[data-ad-unit],.adsbygoogle,.advertisement,.ad,.ads') || element;
      const unique = selector => {
        try {
          const matches = document.querySelectorAll(selector);
          return matches.length === 1 && matches[0] === element;
        } catch (_) { return false; }
      };
      let selector = '';
      if (element.id && unique('#' + CSS.escape(element.id))) {
        selector = '#' + CSS.escape(element.id);
      } else {
        const classes = Array.from(element.classList).map(name => '.' + CSS.escape(name)).join('');
        const candidate = element.localName + classes;
        if (classes && unique(candidate)) selector = candidate;
      }
      if (!selector) {
        const path = [];
        let node = element;
        while (node && node.nodeType === 1 && node !== document.documentElement) {
          let part = node.localName;
          if (node.id && document.querySelectorAll('#' + CSS.escape(node.id)).length === 1) {
            part = '#' + CSS.escape(node.id);
          } else if (node.parentElement) {
            const siblings = Array.from(node.parentElement.children).filter(other => other.localName === node.localName);
            part += ':nth-of-type(' + (siblings.indexOf(node) + 1) + ')';
          }
          path.unshift(part);
          const candidate = path.join(' > ');
          if (unique(candidate)) { selector = candidate; break; }
          node = node.parentElement;
        }
      }
      if (!selector || selector.length > 4096) return null;
      return selector;
      """;

  public static String apply(JSONArray rules) {
    return "(() => { const rules=" + rules + ";" + APPLY + "})()";
  }

  // A stylesheet also filters matching elements inserted after page load.
  static final String APPLY =
      """
      window.__crocHiddenObserver?.disconnect();
      if (window.__crocHiddenOriginals instanceof Map) {
        for (const [element, original] of window.__crocHiddenOriginals) {
          if (!element.isConnected) continue;
          if (original.value) element.style.setProperty('display', original.value, original.priority);
          else element.style.removeProperty('display');
        }
      }
      const originals = new Map();
      window.__crocHiddenOriginals = originals;
      const valid = rules.filter(selector => {
        try { document.querySelector(selector); return true; } catch (_) { return false; }
      });
      const css = valid.map(selector => selector + '{display:none!important;}').join('\\n');
      // Constructed sheets work under restrictive page style-src policies and
      // automatically filter replacement nodes without a mutation observer.
      let sheet = window.__crocHiddenSheet;
      if (!(sheet instanceof CSSStyleSheet)) sheet = new CSSStyleSheet();
      sheet.replaceSync(css);
      if (!document.adoptedStyleSheets.includes(sheet)) {
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
      }
      window.__crocHiddenSheet = sheet;
      // Inline !important declarations outrank stylesheets. Also handle new ad
      // nodes without observing style mutations or polling the whole document.
      const hide = root => {
        for (const selector of valid) {
          const elements = Array.from(root.querySelectorAll(selector));
          if (root.nodeType === 1 && root.matches(selector)) elements.push(root);
          for (const element of elements) {
            if (!originals.has(element)) originals.set(element, {
              value:element.style.getPropertyValue('display'), priority:element.style.getPropertyPriority('display')
            });
            element.style.setProperty('display', 'none', 'important');
          }
        }
      };
      hide(document);
      if (valid.length) {
        const observer = new MutationObserver(records => {
          for (const element of originals.keys()) if (!element.isConnected) originals.delete(element);
          for (const record of records) {
            for (const node of record.addedNodes) if (node.nodeType === 1) hide(node);
          }
        });
        observer.observe(document, {childList:true, subtree:true});
        window.__crocHiddenObserver = observer;
      }
      """;
}
