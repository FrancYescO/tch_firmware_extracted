/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

<%
  local libos = require("libos")
  local platform_information = os.platform_information()
%>

var desktopAppId = "com.netdumasoftware.desktop";
var systemInfoAppId = "com.netdumasoftware.systeminfo";
var configAppId = "com.netdumasoftware.config";
var procmanagerAppId = "com.netdumasoftware.procmanager";

function apps() {
  return Q.promise(function (resolve, reject) {
    long_rpc_promise(procmanagerAppId, "installed_rapps", [])
      .then(function (apps) {
        resolve(apps[0]);
      }).fail(reject);
  });
}

function notifications() {
  return Q.promise(function (resolve, reject) {
    long_rpc_promise(desktopAppId, "get_notifications", [])
      .then(function (notifications) {
        resolve(notifications[0]);
      }).fail(reject);
  });
}

function themes(reload = false) {
  return Q.promise(function (resolve, reject) {
    long_rpc_promise(desktopAppId, "get_themes", [reload])
      .then(function (themes) {
        resolve(themes[0]);
      }).fail(reject);
  });
}

function activeTheme() {
  return Q.promise(function (resolve, reject) {
    long_rpc_promise(desktopAppId, "get_active_theme", [])
      .then(function (theme) {
        resolve(theme[0]);
      }).fail(reject);
  });
}

function generateAppPath(id) {
  return "/apps/" + id + "/desktop/";
}

function setPageTitle(name) {
  $("#app-name").text(name);
  document.title = name + " - DumaOS";
}

function loadApplicationSideBar(apps) {
  var processedApplications = [];

  for (var i = 0; i < apps.length; i++) {
    var app = apps[i];

    if (app.foreground) {
      processedApplications.push({
        id: app.id,
        icon: app.icon,
        title: app.name
      });
    }
  }

  $("application-sidebar").prop("applications", processedApplications);
}

function reloadSideBar(){
  apps().done(function(apps){
    loadApplicationSideBar(apps);
  })
}

function bindReloadSideBarEvent(){
  $("#application").find("iframe").load(function(){
    var contents = $(this).contents(); // contents of the iframe
    $(contents).find("body").on('reload-side-bar', function(event) {
        reloadSideBar(); 
    });
});
}

function removePageLoader() {
  $("#page-loader")
    .addClass("hidden")
    .delay(250)
    .remove();
}

function hideApplicationLoader() {
  $("#application-loader")
    .addClass("hidden")
    .find(".preloader-wrapper")
      .removeClass("active");
}

function showApplicationLoader() {
  $("#application-loader")
    .removeClass("hidden")
    .find(".preloader-wrapper")
      .addClass("active");
}

function getIdFromHash() {
  return location.hash.slice(1);
}

function loadCurrentApp() {
  var appId = getIdFromHash();
  loadApp(appId);
}

function loadApp(appId, callback) {
  $("application-sidebar").prop("activeApplicationId", appId);
  var app = $("application-sidebar")[0].getApp(appId);

  if (typeof app === "undefined") {
    document.location.hash = "#com.netdumasoftware.desktop";
    return;
  }

  changeApplication(app, callback);
}

function generateApplicationIframe(id, callback) {
  var frame = $("<iframe></iframe>")
    .css("visibility", "hidden")
    .attr("id", id)
    .one("load", function () {
      $(this).css("visibility", "visible");
      
      callback(this);

      hideApplicationLoader();
    });

  $(frame).attr("src", "/apps/" + id + "/desktop/??v=<%= dumaos_version %>&lang=<%= lang %>&theme=<%= current_theme %>&themeVersion=<%= current_theme_version %>");

  return frame;
}

function getFormattedDate(date) {
  return date.getDate() + "/"  +
         (date.getMonth() + 1) + "/" +
         date.getFullYear();
}

function setAppHelpButtonVisible(show) {
  if (show) {
    $("#app-help-button").show();
  } else {
    $("#app-help-button").hide();
  }
}

function getTour(windowContext, desktop) {
  if (
    typeof windowContext.duma !== "undefined" &&
    typeof windowContext.duma.tour !== "undefined" &&
    typeof windowContext.duma.tour.getTour(desktop) !== "undefined" &&
    windowContext.duma.tour.getTour(desktop) !== null
  ) {
    return windowContext.duma.tour.getTour(desktop);
  }
}

function changeApplication(app, callback) {
  if ($("#disconnection-page").is(":visible")) {
    return;
  }

  hideDisconnectionPage();
  showApplicationLoader();
  setAppHelpButtonVisible(false);

  $("#application iframe").remove();

  setPageTitle(app.title);

  $("#application").append(generateApplicationIframe(app.id, function (frame) {

    frame.contentWindow.browserSetup.onReady(function () {
      setAppHelpButtonVisible(typeof getTour(frame.contentWindow) !== "undefined");
    });

    if (callback) {
      callback(frame);
    }
  }));
  bindReloadSideBarEvent();
}

function bindNotificationBarEvent() {
  $("#notifications-open, #notifications-close").click(function () {
    $("#notification-drawer")[0].toggle();
  });
}

function findApp(id, apps) {
  return apps.find(function (app) {
    return app.id === id;
  });
}

function setNotificationNumber(notificationNumber) {
  if (notificationNumber) {
    $("#notification-number").prop("label", notificationNumber);
  } else {
    $("#notification-number").hide();
  }
}

function processNotifications(notifications) {
  var output = {};
  for (var i = 0; i < notifications.length; i++) {
    var notification = notifications[i];
    
    if (!output[notification.package]) {
      output[notification.package] = {};
    }

    if (!output[notification.package][notification.title]) {
      output[notification.package][notification.title] = [];
    }

    output[notification.package][notification.title].push(notification);
  }

  return output;
}

function deleteNotification(
  appId, title, notificationClass, 
  notificationElement
) {
  function on_notification_deleted() {
    $(notificationElement).remove();
    setNotificationNumber($("#notification-number").prop("label") - notificationClass.length);
  }

  if (appId === "cloud") {
    for (var i = 0; i < notificationClass.length; ++i) {
      long_rpc(desktopAppId,"delete_cloud_notification",[notificationClass[i].uid],on_notification_deleted);
    }
  } else {
    long_rpc(desktopAppId,"delete_rapp_notifications",[appId, title],on_notification_deleted);
  }

  if ($("#notification-number").prop("label") === 0) {
    showNoNotificationsMessage();
  }
}

function appendToElement(parent, children) {
  children = $(children);
  parent = $(parent);
  for (var i = 0; i < children.length; i++) {
    Polymer.dom(parent[0]).appendChild(children[i]);
  }
}

function load_rapp_from_notification(app_id,notification_class) {
  document.location.hash = "#" + app_id;

  loadApp(app_id,function(frame) {
    var app_data = [];
	app_data.length = notification_class.length;

    for (var i = 0; i < app_data.length; ++i) {
      var data = notification_class[i].data;

      if (typeof(data) === "string") {
        app_data[i] = JSON.parse(data);
      } else {
	app_data[i] = data;
      }
    }

    $(frame).contents().bind("body").prop("notificationData",app_data);
  });
}

function onNotificationClick(appId,apps,title,notificationClass,notificationElement) {
  deleteNotification(appId,title,notificationClass,notificationElement);

  if (appId === "cloud") {
    var action = notificationClass[0].action;
    
    if (action) {
      switch(action.type) {
        case "URL": window.open(action.url); break;
        case "RAPP": load_rapp_from_notification(action.app_id,notificationClass); break;
      }
    }
  } else {
    load_rapp_from_notification(appId,notificationClass);
  }

  $("#notification-drawer")[0].close();
}

var notification_timestamp_regex = new RegExp("^[a-zA-Z]{3} ([a-zA-Z]{3} [0-9]{1,2}) [0-9]{4} ([0-9]{2}:[0-9]{2})","");
var notification_timestamp_date_cutoff = 24 * 60 * 60;

function get_notification_timestamp(unix_time) {
        var matches = new Date(unix_time).toString().match(notification_timestamp_regex);
        var date = matches[1];
        var time = matches[2];

        if (Math.abs(Date.now() - unix_time) < notification_timestamp_date_cutoff) {
                return time;
        } else {
                return date;
        }
}

function generateNotification(app, appId, title, apps) {
  var notificationClass = app[title];
  var topNotification = notificationClass[0];
  var notificationElement = $("<paper-icon-item></paper-icon-item>")
    .click((function (appId, title, notificationClass) {
      return function () {
        onNotificationClick(
          appId, apps, title,
          notificationClass, notificationElement
        );
      };
    })(appId, title, notificationClass));

  var background = $("<image class=\"notification-background\"></image>")

  $(background).prop("src",topNotification.background);
  $(background).on("load",function() {
  	$(notificationElement).css("height",this.height);
  });

  var iconWrapper = $("<div item-icon></div>");

  var icon = topNotification.icon;
  if (!icon) {
    var localApp = findApp(appId, apps);
    if (localApp) {
      icon = localApp.icon;
    } else {
      // TODO put question mark.
    }
  }
  
  appendToElement(notificationElement,background);

  if (icon) {
    appendToElement(iconWrapper,$("<duma-image class='notification-icon'></duma-image>").attr("src", icon));
  }

  if (topNotification.date) {
    appendToElement(iconWrapper,$("<p class='notification-timestamp'>" + get_notification_timestamp(topNotification.date) + "</p>"));
  }

  if (notificationClass.length > 1) {
    appendToElement(iconWrapper, $("<paper-badge></paper-badge>")
      .attr("label", notificationClass.length));
  }

  appendToElement(notificationElement, iconWrapper);

  var body = $("<paper-item-body two-line></paper-item-body>");

  appendToElement(body, $("<div></div>").text(title));
  appendToElement(body, $("<div secondary></div>")
      .text(topNotification.description));

  appendToElement(notificationElement, body);

  appendToElement(
    notificationElement,
    $("<paper-icon-button icon='close' alt='Close'></paper-icon-button>")
      .click((function (
          appId, title, notificationClass,
          notificationElement
      ) {
        return function (event) {
          event.stopPropagation();
          deleteNotification(
            appId,
            title,
            notificationClass,
            notificationElement
          );
        };
      })(appId, title, notificationClass, notificationElement)));

  return notificationElement;
}

function showNoNotificationsMessage() {
  $("#no-notifications-message").show();
}

function loadNotifications(notifications, apps) {
  notifications = processNotifications(notifications);

  for (var appId in notifications) {
    if (notifications.hasOwnProperty(appId)) {
      var app = notifications[appId];

      for (var title in app) {
        if (app.hasOwnProperty(title)) {
          appendToElement(
            $("#notifications"),
            generateNotification(app, appId, title, apps)
          );
        }
      }
    }
  }

  if (jQuery.isEmptyObject(notifications)) {
    showNoNotificationsMessage();
  }
}

function bindOnHashChange() {
  $(window).on("hashchange", function () {
    loadCurrentApp();
  });
}

function showDisconnectionPage() {
  $("#disconnection-page").show();
  $("#application iframe").remove();
  $("#disconnection-page paper-spinner-lite").prop("active", true);
}

function hideDisconnectionPage() {
  $("#disconnection-page").hide();
  $("#disconnection-page paper-spinner-lite").prop("active", false);
}

function startDisconnectPoll(success, failure) {
  var timeout = 1000 * 1.5;
  var retry = 0;
  var apChangeDelay = 75 * 1000;
  var hijackChangeDelay = 120 * 1000;
  var poll = true;
  var timeoutId = null;


  function DelayedRedirect( url, delay ){
    poll = false;
    showDisconnectionPage();
    Q.delay( delay ).then( function(){
      window.location.replace( url );
    } );
  }

  function WhenRedirect( url, when ){
    var delay = when - timeGetTime();
    if( delay < 0 )
      delay = 0;
    DelayedRedirect( url, delay );
  }


  function pollRouter() {
    timeoutId = null;

    $.ajax({
      url: "/json/poll.json??v=<%= dumaos_version %>&lang=<%= lang %>&theme=<%= current_theme %>&themeVersion=<%= current_theme_version %>&cache=0",
      dataType: "text"
    }).done(function (response) {
      retry = 0;
      try {
        if( response.indexOf("multi_login.html") != -1 ){
          top.location="/multi_login.html";
          return;
        }

        var parsedResponse = JSON.parse(response);

        /* use routerlogin for redirects as IP may have changed e.g. AP mode */
        var url = location.protocol + "//" + "routerlogin.net";   

        if (parsedResponse.router) {
          /*
          * Make sure in correct mode either Router or AP.
          */
          if( Boolean( apMode ) != Boolean( parsedResponse.ap_mode ) ){
            DelayedRedirect( url, apChangeDelay );
            return;
          }

          /*
          * If hijacked then DumaOS shouldn't even be showing
          */
          if( Boolean( parsedResponse.hijack_mode ) ){
            DelayedRedirect( url, hijackChangeDelay );
            return;
          }

          /* If language is not ready show disconnect screen until it is */
          if( parsedResponse.translationReady === false ){
            throw Exception();
          } 

          if (
            parsedResponse.firmwareVersion !==
            firmwareVersion
          ) {
            location.reload();
            return;
          }

          success();
        } else {
          throw Exception();
        }
      } catch (e) {
        showDisconnectionPage();
      }

      if (poll) {
        timeoutId = setTimeout(pollRouter, timeout);
      }
    }).fail(function (e) {
      if(e.readyState === 4 || (retry++) >= 3) {
        failure();
      }

      if (poll) {
        timeoutId = setTimeout(pollRouter, timeout);
      }
    });
  };

  pollRouter();

  return function (start) {
    if (start) {
      if (poll) {
        return;
      }

      poll = true;
      pollRouter();

    } else {
      if (!poll) {
        return;
      }
      
      poll = false;

      if (timeoutId !== null) {
        clearTimeout(timeoutId);
      }
    }
  };
}

// https://stackoverflow.com/a/21903119/3250233
function getUrlParameter(sParam) {
  var sPageURL = decodeURIComponent(window.location.search.substring(1)),
    sURLVariables = sPageURL.split('&'),
    sParameterName,
    i;

  for (i = 0; i < sURLVariables.length; i++) {
    sParameterName = sURLVariables[i].split('=');

    if (sParameterName[0] === sParam) {
      return sParameterName[1] === undefined ? true : sParameterName[1];
    }
  }
}

function isBrowserWindowsChromeHttps() {
  return location.protocol === "https:" &&
         navigator.platform.indexOf("Win") > -1 &&
         bowser.check({chrome: "0"}, true);
}

function redirectBrowser(urlFunction, query) {
  var url = urlFunction(window.location.href.split("?")[0]);
  location.href = url + "?" + $.param(query);
}

function checkChromeWindowsHttps() {
  if (isBrowserWindowsChromeHttps()) {
    var chromeSave = getUrlParameter("chromeSaveOption") === "true";
    var chromeOption = getUrlParameter("chromeOption");

    if (getUrlParameter("chromeRedirect") === "true") {
      return;
    }

    if (
      chromeOption === "https" ||
      duma.storage(desktopAppId, "chrome-setting") === "https"
    ) {
      if (chromeSave) {
         duma.storage(desktopAppId, "chrome-setting", "https");
      }

      redirectBrowser(function (url) {
        return url.replace("http://", "https://");
      }, { chromeRedirect: true });
      return;

    } else if (
      chromeOption === "http" ||
      duma.storage(desktopAppId, "chrome-setting") === "http"
    ) {
      if (chromeSave) {
         duma.storage(desktopAppId, "chrome-setting", "http");
      }

      redirectBrowser(function (url) {
        return url.replace("https://", "http://");
      }, { chromeRedirect: true });
      return;
    
    } else if (
      chromeOption === "netgear" ||
      duma.storage(desktopAppId, "chrome-setting") === "netgear"
    ) {
      if (chromeSave) {
         duma.storage(desktopAppId, "chrome-setting", "netgear");
      }

      location.href = "/index.htm";
      return;

    } else {
      location.href = "/desktop/chrome-https.html";
      return;
    }
  }
}

function bindLogoutButtonClick() {
  $("#logout-button").click(function () {
    <% if os.implements_netgear_specification() then %>
    serial_netgear_soap_rpc("DeviceConfig", "WebLogout").done( function( obj ){ 
      top.location="/goodbye.html";
    });
    <% else %>
    // document.location = "http://log:out@" + document.domain;
    var xml = new XMLHttpRequest();
    xml.open('GET',document.baseURI,false,"a","a");
    xml.send('');
    // console.log(xml,document.domain)
    <% end %>
  });
}

function bindAccountSettings() {
  $("#account-settings-button").click(function () {

    $("#account-settings-username")
      .val("")
      .prop("invalid", false);

    $("#account-settings-password")
      .val("")
      .prop("invalid", false);

    $("#account-settings-password-confirmation")
      .val("")
      .prop("invalid", false);

    $("#account-settings-dialog")[0].open();
  });
  
  $("#save-account-settings-button").click(function () {

    if (
      $("#account-settings-username")[0].validate() &&
      $("#account-settings-password")[0].validate() &&
      $("#account-settings-password-confirmation")[0].validate()
    ) {

      long_rpc_promise(desktopAppId, "set_authentication", [
        $("#account-settings-username").val(),
        $("#account-settings-password").val()
      ]).done(function () {
        $("#account-settings-dialog")[0].close();
        location.reload();
      });
    }
  });

  $("#account-settings-password").change(function () {

    var passwordConfirmation = $("#account-settings-password-confirmation")[0];

    $(passwordConfirmation)
      .prop("pattern", "^" + $(this).val() + "$");

    if ($(passwordConfirmation).val()) {
      passwordConfirmation.validate();
    }
  });
  
  $("#account-settings-password-confirmation").change(function () {
    this.validate();
  });
}

function bindThemeSelection() {
  $("#theme-selection-button").click(function () {
    reload_themes().done(function(){
      $("#theme-selection-dialog")[0].open();
      $("#theme-dropdown").prop("selected", $("#selected-theme").prop("value"));
    });
  });

  $("#save-theme-button").click(function () {
    var selectedTheme = $("#theme-dropdown").prop("selected");
    $("#selected-theme").prop("value", selectedTheme);

    long_rpc_promise(desktopAppId, "set_active_theme", [selectedTheme])
      .done(function () {
        location.reload();
      });
  });
}

function bindTimeSettings(){
  $("#time-settings-button").click(function () {
    $("#time-settings")[0].open();
  });
}

function reload_themes(){
  return Q.spread([
    themes(true),
    activeTheme()
  ], function (themes, activeTheme) {
    loadThemes(themes,activeTheme);
  });
}

function loadThemes(themes, currentTheme) {
  var theme_dropdown = $("#theme-dropdown");
  var Polytheme = Polymer.dom(theme_dropdown[0]);
  while(Polytheme.childNodes.length > 0){
    Polytheme.removeChild(Polytheme.childNodes[0]);
  }
  for (var i = 0; i < themes.length; i++) {
    var theme = themes[i];

    var option = $("<paper-item> " + theme.name + "</paper-item>")
      .attr("value", theme.id);

    Polytheme.appendChild(option[0]);
  }

  $("#selected-theme").prop("value", currentTheme);
}

function onRebootClick() {
  $("#generic-duma-alert")[0].show(
    "<%= i18n.rebootConfirmation %>",

    [   
      { text: "<%= i18n.cancel %>", action: "dismiss" },
      { text: "<%= i18n.reboot %>", action: "confirm", callback: function () {

        long_rpc_promise(systemInfoAppId, "reboot", []).done(function () {
          $("#generic-duma-alert")[0].show(
            "<%= i18n.routerRebootingConfirmation %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }]

          );  
        }); 

      }}  
    ]   
  );  
}

function onFactoryResetClick() {
  $("#generic-duma-alert")[0].show(
    "<%= i18n.factoryResetConfirmation %>",

    [   
      { text: "<%= i18n.cancel %>", action: "dismiss" },
      { text: "<%= i18n.factoryReset %>", action: "confirm", callback: function () {

        long_rpc_promise(systemInfoAppId, "factory_reset", []).done(function () {
          $("#generic-duma-alert")[0].show(
            "<%= i18n.factoryResetHappening %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }]

          );  
        }); 

      }}  
    ]   
  );  
}
function onRestoreDefaultsClick() {
  $("#restore-defaults-dialog")[0].open();
}

function bindDumaOSInformationClick(apMode) {
  $("#dumaos-information-button").click(function () {
    $("#dumaos-information-dialog")[0].open();
  });

  if( !apMode ){
    $("#launch-dumaos-tour-button").on("click", function () {
      $("#dumaos-information-dialog")[0].close();
      hopscotch.startTour(getTour(window, true)(0), 0);
    });
  } else {
    $("#launch-dumaos-tour-button").hide();
  }

  $("#reboot-button").on("click", onRebootClick);
  $("#factory-reset-button").on("click", onFactoryResetClick);
  $("#restore-defaults-button").on("click", onRestoreDefaultsClick);
  $("#restore-defaults-dialog").find("#restore-confirm").on("click", function(e){
    long_rpc_promise(configAppId, "reset_overlay", []).done(function () {
      $("#generic-duma-alert")[0].show(
        "<%= i18n.restoreDefaultsHappening %>",
        [{ text: "<%= i18n.gotIt %>", action: "confirm" }]
      );  
    });
    $("#restore-defaults-dialog")[0].close();
  });
}

function bindSidebarToggleClick() {
  $("#sidebar-toggle").click(function () {
    var collapsed = !$("application-sidebar").prop("collapsed");
    $("application-sidebar, body").attr("collapsed", collapsed || null);
    duma.storage(desktopAppId, "sidebar-collapsed", collapsed);
  });
}

function loadApplicationSidebarState() {
  var collapsed = duma.storage(desktopAppId, "sidebar-collapsed");
  collapsed = collapsed === null ? false : collapsed;
  $("application-sidebar, body").attr("collapsed", collapsed === "true" || null);
}

function showLanguageChangeError() {
  hideLanguageChangingLoader();
  setSelectedLanguage();
  $("#language-update-error")[0].open();
}

function beginLanguageChangePoll() {
  setTimeout(function () {

    serial_netgear_soap_rpc("DeviceConfig", "SetGUILanguageStatus", {})
      .done(function(response) {
        switch (response.code) {
          case "000":
            location.reload();
            break;

          case "001":
            beginLanguageChangePoll();
            break;

          case "002":
            showLanguageChangeError();
            break;
        }
      });

  }, 1000)
}

function showLanguageChangingLoader() {
  $("#langauge-change-in-progress")[0].open();
  $("#langauge-change-in-progress paper-spinner-lite").prop("active", true);
}

function hideLanguageChangingLoader() {
  $("#langauge-change-in-progress")[0].close();
  $("#langauge-change-in-progress paper-spinner-lite").prop("active", false);
}

function bindLanguageChange() {
  $("language-selector").prop("disabled", false );
  $("language-selector").on("user-language-change", function () {
    
    var selectedLanguageCode = this.selectedLanguage;
    
    serial_netgear_soap_rpc("DeviceConfig", "SetGUILanguage", {
      "GUILanguage" : this.selectedLanguage
    }).done(function(response) {
      if (response.code === "000") {
        beginLanguageChangePoll();
        showLanguageChangingLoader();
      } else {
        showLanguageChangeError();
      }
    });

  });
}

function setSelectedLanguage() {
  serial_netgear_soap_rpc("DeviceConfig", "GetGUILanguage" )
    .done(function(lang) {
      if(lang.code == "000") {
        $("language-selector").prop(
          "selectedLanguage",
          lang.response.GUILanguage
        );
        $("language-selector").prop(
          "availableLanguages",
          lang.response.SupportLanguages.split(",")
        );
      }
    });
}

var firmware_check_wait = 1000 * 45;    /* wait till page fully loaded */
var firmware_check_interval = 1000 * 60 * 60;   /* how often to check for firmware update */

function pollFirmwareDownload() {
  serial_netgear_soap_rpc("DeviceConfig", "GetDownloadNewFirmwareStatus")
    .done(function (status) {

      if( parseInt( status.code, 10 ) != 0 )
        throw Error("GetDownloadNewFirmwareStatus failed with code: " + status.code + ".");

      switch( parseInt( status.response.Status, 10) ) {
        case 0:
        case 1:
          setTimeout( pollFirmwareDownload, 1000);
          break;
        case 3:
          serial_netgear_soap_rpc("DeviceConfig", "WriteRebootNewFirmware");
          break;
        default:
        case 2:
          throw Error("Download failed, please try again later.");
          break;
      }
    });
}

function onUpgradeFirmwareConfirmation() {
 <% if platform_information.odm == "FOXCONN" then %>
    serial_netgear_soap_rpc("DeviceConfig", "UpdateNewFirmware", {YesOrNo: 1});
    $("#update-progress-dialog").find("paper-spinner-lite").prop("active", true);
    $("#update-progress-dialog")[0].open();
 <% else %>
   serial_netgear_soap_rpc("DeviceConfig", "DownloadNewFirmware")
     .done(function () {
       $("#update-progress-dialog").find("paper-spinner-lite").prop("active", true);
       $("#update-progress-dialog")[0].open();
        
       pollFirmwareDownload();
     });
  <% end %>
}

function updatebtn_click_netgear(firmwareInformation){
  $("#update-current-version").text(firmwareInformation.CurrentVersion);
  $("#update-new-version").text(firmwareInformation.NewVersion);
  $("#update-release-notes").empty();
  
  var releaseNotes = firmwareInformation.ReleaseNote.split("\\");

  for (var i = 0; i < releaseNotes.length; i++) {
    $("#update-release-notes").append($("<li></li>")
      .text(releaseNotes[i])
    );
  }

  $("#update-confirmation-alert")[0].show(null,
    [
      { text: "<%= i18n.cancel %>", action: "dismiss" },
      {
        text: "<%= i18n.update %>", action: "confirm",
        default: true, callback: onUpgradeFirmwareConfirmation
      }
    ]
  );
}

function updatebtn_click_generic(){
  $("#firmware-upgrade-dialog")[0].open();

  $("#firmware-upgrade-button").click(function () {
    if ($("#firmware-upgrade-file").prop("files").length == 1) {
      $("#firmware-upgrade-file")[0]
        .uploadFile($("#firmware-upgrade-file").prop("files")[0]);
        var divP = $(this).parent();
        divP.find("paper-button").attr("disabled",true).attr("hidden",true);
        divP.prev().attr("hidden",false);//.attr("hidden",null);
      }
  });

  $("#firmware-upgrade-file").on("success", function (response) {
    $("#firmware-upgrade-dialog")[0].close();

    $("#confirmation-dialog")[0].open();
    $("#confirmation-dialog paper-spinner-lite").prop("active", true);
  });

  $("#firmware-upgrade-file").on("error", function (e) {

    $(this).prop("errorText", e.detail.xhr.responseText);

    e.stopPropagation();
  });
}

function startFirmwareCheck() {
  var firmwareInformation;

  $("#update-button").click(function () {
    <% if os.implements_netgear_specification() then %>
      updatebtn_click_netgear(firmwareInformation);
    <% else %>
      updatebtn_click_generic();
    <% end %>
  });

  /* NETGEAR platforms have automatic update detection. */
  <% if os.implements_netgear_specification() then %>
    start_cycle(function () {
      return [Q.promise(function (resolve) {
        serial_netgear_soap_rpc("DeviceConfig", "GetCheckNewFirmwareResult" )
          .done(resolve, resolve);
      })];

    }, function ( firmupdate ) {
      if(firmupdate.code === "000" && firmupdate.response.NewVersion !== "") {

        $("#update-button").prop("disabled", false);

        Polymer.dom($("paper-tooltip[for=update-container]")[0])
          .textContent = "<%= i18n.updateAvailable %>";

        firmwareInformation = firmupdate.response;

      } else {
        $("#update-button").prop("disabled", true);

        Polymer.dom($("paper-tooltip[for=update-container]")[0])
          .textContent = "<%= i18n.noUpdateAvailable %>";
      }
    }, firmware_check_interval);
  <% else %>
    $("#update-button").prop("disabled", false);
    Polymer.dom($("paper-tooltip[for=update-container]")[0])
      .textContent = "<%= i18n.update %>";
  <% end %>
}

function bindAppHelpButton() {
  $("#app-help-button").click(function () {
    var appId = $("application-sidebar").prop("activeApplicationId");

    var frameWindow = $("#application iframe")[0].contentWindow;

    if (typeof getTour(frameWindow) !== "undefined") {
      frameWindow.hopscotch.startTour(getTour(frameWindow)(0), 0);
    }
  });
}

// TODO
function init_apmode(){
  var processedApplications = [
    {
      "id": "com.netdumasoftware.ngportal",
      "icon": "/apps/com.netdumasoftware.ngportal/shared/settings.svg",
      "title": "Settings"
    }
  ];

  $("application-sidebar").prop("applications", processedApplications);
}

function bindTopBar(){
  <% if os.implements_netgear_specification () then %>
    setSelectedLanguage();
    bindLanguageChange();
  <% end %>

  Q.delay(
    <% if os.implements_netgear_specification () then %>
      firmware_check_wait
    <% else %>
      0
    <% end %>
  ).then( startFirmwareCheck );
}

function disconnectionPollSuccess() {
  if ($("#disconnection-page").is(":visible")) {
    hideDisconnectionPage();
    loadCurrentApp();
  }
}

function disconnectionPollFailure() {
  showDisconnectionPage();
}

function checkStartTour() {
  if (getUrlParameter("forceTourStart") === "true") {
    hopscotch.startTour(getTour(window, true)(0), 0);
  }
}

function checkAdblocker() {
  function detected() {
    $("#adblocker-alert")[0].show(
      null,

      [{ text: "Got it", action: "confirm" }],

      {
        enabled: true,
        packageId: "desktop",
        id: "adblocker-enabled"
      }
    );
  }

  if(typeof blockAdBlock === "undefined") {
	  detected();
  } else {
    blockAdBlock.onDetected(detected);
  }
}

browserSetup.onReady(function () {
  checkChromeWindowsHttps();
  bindLogoutButtonClick();
  bindSidebarToggleClick();
  loadApplicationSidebarState();
  bindOnHashChange();
  checkAdblocker();

  // TODO onhashchange after page load deosn't work properly.
  if( apMode ){
    init_apmode();
    setNotificationNumber( 0 );
    bindDumaOSInformationClick(apMode);
    document.location.hash = "#com.netdumasoftware.ngportal";
    loadCurrentApp();
    bindNotificationBarEvent();
    bindTopBar();
    removePageLoader();
    setAppHelpButtonVisible(false);
    startDisconnectPoll(disconnectionPollSuccess, disconnectionPollFailure);
    $("#reboot-button").hide();
    return;
  }

  Q.spread([
    apps(),
    notifications(),
    themes(),
    activeTheme()
  ], function (apps, notifications, themes, activeTheme) {
    startDisconnectPoll(disconnectionPollSuccess, disconnectionPollFailure);
    loadApplicationSideBar(apps);
    loadCurrentApp();
    bindNotificationBarEvent();
    bindAppHelpButton();
    bindDumaOSInformationClick(apMode);
    loadNotifications(notifications, apps);
    setNotificationNumber(notifications.length);
    bindTopBar();
    checkStartTour();
    bindThemeSelection();
    bindTimeSettings();
    loadThemes(themes, activeTheme);
    
    history.replaceState({}, null, location.pathname + location.hash);

    <% if platform_information.sdk == "OpenWRT" then %>
      bindAccountSettings();
    <% end %>

    removePageLoader();
  }).done();
});
