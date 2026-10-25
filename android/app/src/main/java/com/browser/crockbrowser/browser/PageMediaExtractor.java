package com.browser.crockbrowser.browser;

/** Reads media URLs already exposed to the current page. Never executes page configuration. */
public final class PageMediaExtractor {
  private PageMediaExtractor() {}

  public static final String SCRIPT =
      """
      (() => {
        const results = new Map();
        const host = location.hostname.toLowerCase();
        const platform = /(^|\\.)instagram\\.com$/.test(host) ? 'Instagram'
          : /(^|\\.)(facebook\\.com|fb\\.watch)$/.test(host) ? 'Facebook'
          : /(^|\\.)vimeo\\.com$/.test(host) ? 'Vimeo'
          : /(^|\\.)(twitter\\.com|x\\.com)$/.test(host) ? 'X'
          : /(^|\\.)tiktok\\.com$/.test(host) ? 'TikTok' : 'Website';
        const mediaPath = /\\.(mp4|webm|m4v|mov|mp3|m4a|aac|ogg|wav|m3u8|mpd)(?:$|[?#])/i;
        const mime = u => /\\.mpd(?:$|[?#])/i.test(u) ? 'application/dash+xml'
          : /\\.m3u8(?:$|[?#])/i.test(u) ? 'application/x-mpegURL' : '';
        const add = (value, type, source, title) => {
          if (typeof value !== 'string' || value.length > 16384 || results.size >= 150) return;
          try {
            const u = new URL(value, location.href);
            if (!['http:', 'https:'].includes(u.protocol) || u.username || u.password) return;
            const row = {url: u.href, mime: typeof type === 'string' && type ? type : mime(u.href),
              title: typeof title === 'string' && title ? title.slice(0, 300) : document.title || 'Media', source, platform};
            if (!results.has(u.href)) results.set(u.href, row);
          } catch (_) {}
        };
        document.querySelectorAll('video,audio,video source,audio source').forEach(e => {
          add(e.currentSrc || e.src, e.type || '', 'Player');
        });
        for (const property of ['og:video:secure_url','og:video:url','og:video',
            'twitter:player:stream']) {
          const el = document.querySelector(`meta[property="${property}"],meta[name="${property}"]`);
          if (el) add(el.content, '', platform + ' metadata');
        }
        document.querySelectorAll('a[href],link[href]').forEach(e => {
          if (mediaPath.test(e.href)) add(e.href, e.type || '', 'Media link', e.title);
        });
        performance.getEntriesByType('resource').slice(-1000).forEach(e => {
          if (mediaPath.test(e.name)) add(e.name, '', 'Network media');
        });
        let visited = 0;
        const walk = (node, depth) => {
          if (!node || typeof node !== 'object' || depth > 10 || ++visited > 10000) return;
          if (Array.isArray(node)) { node.slice(0, 300).forEach(v => walk(v, depth + 1)); return; }
          const type = String(node['@type'] || '').toLowerCase();
          for (const key of ['video_url','playable_url','playable_url_quality_hd',
              'contentUrl','downloadUrl']) {
            if (typeof node[key] === 'string' && (key !== 'contentUrl' ||
                /video|audio/.test(type) || mediaPath.test(node[key])))
              add(node[key], node.encodingFormat || '', platform + ' page data', node.name);
          }
          // Vimeo's public progressive-file configuration, when embedded in the page.
          if (platform === 'Vimeo' && typeof node.url === 'string' &&
              (String(node.mime || '').startsWith('video/') || mediaPath.test(node.url)))
            add(node.url, node.mime || '', 'Vimeo player', node.quality);
          Object.values(node).slice(0, 300).forEach(v => walk(v, depth + 1));
        };
        document.querySelectorAll('script[type="application/ld+json"],script[type="application/json"]').forEach(e => {
          if (e.textContent.length <= 1024 * 1024 && visited <= 10000)
            try { walk(JSON.parse(e.textContent), 0); } catch (_) {}
        });
        return JSON.stringify([...results.values()]);
      })()
      """;
}
