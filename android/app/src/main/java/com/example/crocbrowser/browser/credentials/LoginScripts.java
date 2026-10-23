package com.example.crocbrowser.browser.credentials;

/** Login-form observation only; never submits a form or stores credentials in page storage. */
final class LoginScripts {
  private LoginScripts() {}

  static final String INSTALL =
      """
      (() => {
        window.__crockLoginCaptureEnabled = true;
        if (window.__crockLoginObserver) return;
        window.__crockLoginObserver = true;
        let attempted = false, scheduled = false;
        const send = data => {
          if (window.__crockLoginCaptureEnabled && window.crockLoginEvents)
            window.crockLoginEvents.postMessage(JSON.stringify(data));
        };
        document.addEventListener('submit', event => {
          if (!window.__crockLoginCaptureEnabled || !event.isTrusted) return;
          const form = event.target;
          if (!form || !form.querySelectorAll) return;
          const passwords = [...form.querySelectorAll('input[type=password]')];
          if (passwords.length !== 1 || passwords[0].autocomplete === 'new-password') return;
          const password = passwords[0];
          if (!password.value || password.value.length > 4096) return;
          const username = form.querySelector('input[autocomplete=username],input[type=email]') ||
            [...form.querySelectorAll('input')].find(e =>
              ['text','email','tel'].includes(e.type) && e.value);
          attempted = true;
          send({type:'submitted',username:username ? username.value.slice(0, 512) : '',
            password:password.value});
          setTimeout(() => send({type:'check'}), 1800);
        }, true);
        new MutationObserver(() => {
          if (!attempted || scheduled || !window.__crockLoginCaptureEnabled) return;
          scheduled = true;
          setTimeout(() => { scheduled = false; send({type:'check'}); }, 1800);
        }).observe(document.documentElement, {subtree:true,childList:true});
      })()
      """;

  static String success(boolean navigated) {
    return """
    (() => {
      if (document.readyState !== 'complete') return false;
      const visible = e => e.getClientRects().length > 0 &&
        getComputedStyle(e).visibility !== 'hidden';
      if ([...document.querySelectorAll('input[type=password],input[autocomplete=one-time-code]')].some(visible)) return false;
      if ([...document.querySelectorAll('[role=alert],[aria-invalid=true]')].some(e =>
          visible(e) && /incorrect|invalid|failed|wrong|try again/i.test(e.innerText || e.textContent || ''))) return false;
      const signedIn = [...document.querySelectorAll('a,button')].slice(0, 400).some(e => visible(e) &&
        /^(log out|logout|sign out|signout)$/i.test((e.innerText || e.textContent || '').trim()));
      return signedIn || __NAVIGATED__;
    })()
    """
        .replace("__NAVIGATED__", navigated ? "true" : "false");
  }
}
