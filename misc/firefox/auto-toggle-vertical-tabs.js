// DO NOT DELETE THIS LINE
// This file should go to /usr/lib64/firefox
// support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig

"use strict";

function shouldUseVerticalTabs(width, height) {
  return width <= 1080;
}

try {
  let { classes: Cc, interfaces: Ci, manager: Cm, utils: Cu } = Components;
  var Services =
    globalThis.Services ||
    ChromeUtils.import("resource://gre/modules/Services.jsm").Services;

  function ConfigJS() {
    Services.obs.addObserver(this, "chrome-document-global-created", false);
  }
  ConfigJS.prototype = {
    observe: function (aSubject) {
      aSubject.addEventListener("DOMContentLoaded", this, { once: true });
    },
    handleEvent: function (aEvent) {
      let document = aEvent.originalTarget;
      let window = document.defaultView;
      let location = window.location;

      window.addEventListener("resize", () => {
        if (shouldUseVerticalTabs(window.innerWidth, window.innerHeight)) {
          pref("sidebar.verticalTabs", true);
        } else {
          pref("sidebar.verticalTabs", false);
        }
      });
    },
  };
  if (!Services.appinfo.inSafeMode) {
    new ConfigJS();
  }
} catch (e) {
  Cu.reportError(e);
}
