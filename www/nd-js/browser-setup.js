/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

window.Polymer = {
  dom: "shady",
  lazyRegister: true
};

if (!String.prototype.format) {
  String.prototype.format = function() {
    var args = arguments;
    return this.replace(/{(\d+)}/g, function(match, number) { 
      return typeof args[number] != 'undefined'
        ? args[number]
        : match
      ;
    });
  };
}
if (!String.format) {
  String.format = function(format) {
    var args = Array.prototype.slice.call(arguments, 1);
    return format.replace(/{(\d+)}/g, function(match, number) { 
      return typeof args[number] != 'undefined'
        ? args[number] 
        : match
      ;
    });
  };
}

var browserSetup = (function() {


var callbacks = [];
var polymerReady = false;
var requiredImportsReady = false;

function isBrowserSupported() {
  return bowser.check({
    firefox: "45",
    chrome: "55",
    safari: "10",
    msie: "11"
  });
}

function bindErrors() {
  var errorDialog = document.createElement("duma-alert");
  document.body.appendChild(errorDialog);
  var noDialogErrors = ["AP RPC Error"]; // List of error prefixes that will not pop up in the dialog
  var isNoDialogError = function(errorMessage){
    for(var i = 0; i < noDialogErrors.length; i ++){
      var errorPrefix = noDialogErrors[i];
      if(errorMessage.startsWith(errorPrefix) || errorMessage.startsWith("Uncaught " + errorPrefix)){
        return true;
      }
    }
    return false;
  }
  
  window.onerror = function (errorMessage) {
    if(isNoDialogError(errorMessage)){
      console.warn(errorMessage)
      return true;
    }
    var message = errorMessage.replace("Uncaught Error:", "");
    if (errorDialog.show) {
      errorDialog.show(message);
      return false;
    }
  };
}

function callCallback(callback) {
  if (typeof jQuery !== "undefined") {
    jQuery(document).ready(function () {
      callback();
    });
  } else {
    callback();
  }
}

function callCallbacks() {
  for (var i = 0; i < callbacks.length; i++) {
    callCallback(callbacks[i]);
  }
}

function onPolymerReady() {
  polymerReady = true;
  onResourceLoad();
}

function browserUnsupported() {
  var message = "Your browser is not supported by DumaOS. The interface may " +
                "still load but we recommend you upgrade to an up to date " +
                "browser, such as the latest version of Chrome, for the best " +
                "experience.";

  alert(message);
}

function checkBrowserSupport() {
  if (isBrowserSupported()) {
    
  } else {
    browserUnsupported();
  }

}

function onResourceLoad() {
  if (polymerReady && requiredImportsReady) {
    bindErrors();
    callCallbacks();
  }
}

function loadWebComponentsPolyfill() {
  var e = document.createElement("script");
  e.src = "/custom-elements/webcomponentsjs/webcomponents-lite.min.js??v=<%= dumaos_version %>&lang=<%= lang %>&theme=<%= current_theme %>&themeVersion=<%= current_theme_version %>";
  e.type = "text/javascript";
  e.async = true;

  if (window.addEventListener) {
    window.addEventListener("WebComponentsReady", function () {
      onPolymerReady();
    });
  }
  
  document.getElementsByTagName("head")[0].appendChild(e);
}

function loadRequiredPageImports() {
  var e = document.createElement("link");
  e.href = "/libs/required-page-imports.html??v=<%= dumaos_version %>&lang=<%= lang %>&theme=<%= current_theme %>&themeVersion=<%= current_theme_version %>";
  e.rel = "import";
  e.async = true;

  e.onload = function () {
    requiredImportsReady = true;
    onResourceLoad();
  }

  document.getElementsByTagName("head")[0].appendChild(e);
}

function onBowserLoad() {
  checkBrowserSupport();
  loadRequiredPageImports();
  conditionallyLoadWebComponentsPolyfill();
}

function loadBowser() {
  var e = document.createElement("script");
  e.src = "/nd-js/bowser.js??v=<%= dumaos_version %>&lang=<%= lang %>&theme=<%= current_theme %>&themeVersion=<%= current_theme_version %>";
  e.type = "text/javascript";
  e.async = true;

  var done = false;

  e.onload = e.onreadystatechange = function() {
    if (
      !done && (
        !this.readyState ||
        this.readyState === "loaded" ||
        this.readyState === "complete"
      )
    ) {
      done = true;
      onBowserLoad();
    }
  }

  document.getElementsByTagName("head")[0].appendChild(e);
}

function conditionallyLoadWebComponentsPolyfill() {
  if (
    "registerElement" in document &&
    "import" in document.createElement("link") &&
    "content" in document.createElement("template")
  ) {
    onPolymerReady();

  } else {
    loadWebComponentsPolyfill();
  }
}

window.addEventListener("DOMContentLoaded", loadBowser);
  
return {
  onReady: function (callback) {
    if (callback) {
      if (polymerReady && requiredImportsReady) {
        callCallback(callback);
      } else {
        callbacks.push(callback);
      }
    }
  }
};


})();
