package com.browser.crockbrowser.browser;

/** Fixed scripts only: no native JavascriptInterface is exposed to visited pages. */
public final class BrowserScripts {
  private BrowserScripts() {}

  public static final String READER =
      "(()=>{const el=document.querySelector('article,[role=main],main')||document.body;return"
          + " JSON.stringify({title:document.title,url:location.href,text:el.innerText});})()";
  public static final String MEDIA =
      "(()=>JSON.stringify(Array.from(document.querySelectorAll('video,audio,source')).map(e=>({url:e.currentSrc||e.src,title:document.title,mime:e.type||''})).filter(e=>e.url)))()";
  public static final String FORM =
      "(()=>{const p=document.querySelector('input[type=password]');if(!p)return null;const"
          + " f=p.form||document;const"
          + " u=f.querySelector('input[autocomplete=username],input[type=email],input[name*=user],input[type=text]');return"
          + " JSON.stringify({origin:location.origin,username:u?u.value:'',password:p.value});})()";

  public static String fill(String username, String password) {
    return "(()=>{const p=document.querySelector('input[type=password]');if(!p)return false;const"
               + " f=p.form||document;const"
               + " u=f.querySelector('input[autocomplete=username],input[type=email],input[name*=user],input[type=text]');const"
               + " set=(e,v)=>{if(e){const"
               + " setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;setter.call(e,v);e.dispatchEvent(new"
               + " Event('input',{bubbles:true}));e.dispatchEvent(new"
               + " Event('change',{bubbles:true}));}};set(u,"
        + org.json.JSONObject.quote(username)
        + ");set(p,"
        + org.json.JSONObject.quote(password)
        + ");return true;})()";
  }
}
