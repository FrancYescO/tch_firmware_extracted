/*
 * (C) 2020 NETDUMA Software
 * Kian Cross
 * Luke Meppem
*/

<%
  local libos = require("libos")
  local platform_information = os.platform_information()
%>

var desktopAppId = "com.netdumasoftware.desktop";
var systemInfoAppId = "com.netdumasoftware.systeminfo";
var configAppId = "com.netdumasoftware.config";
var procmanagerAppId = "com.netdumasoftware.procmanager";
var hasBeenFactoryReset = false;
var notificationRefresh = 0;
var _doUpdateFirmwareDialogBind = true;

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

function generateApplicationIframe(app, callback) {
  var frame = $("<iframe></iframe>")
    .css("visibility", "hidden")
    .attr("id", app.id)
    .attr("title", app.title)
    .one("load", function () {
      $(this).css("visibility", "visible");
      
      callback(this);

      hideApplicationLoader();
      bindGlobalMenuIframeEvents(this);
    });

  $(frame).attr("src", "/apps/" + app.id + "/desktop/index.html??v=<%= dumaos_version %>&lang=<%= lang %>&theme=<%= current_theme %>&themeVersion=<%= current_theme_version %>");

  return frame;
}

function getFormattedDate(date) {
  return date.getDate() + "/"  +
         (date.getMonth() + 1) + "/" +
         date.getFullYear();
}

function setAppHelpButtonVisible(show) {
  if (show) {
    $("#app-help-button").show().attr("aria-disabled",false).attr("aria-hidden",false);
  } else {
    $("#app-help-button").hide().attr("aria-disabled",true).attr("aria-hidden",true);
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

function appHelpVisibleRefresh(frame){
  if(!frame) frame = $("#application").find("iframe")[0];
  if(frame && frame.contentWindow)
    frame.contentWindow.browserSetup.onReady(function () {
      setAppHelpButtonVisible(typeof getTour(frame.contentWindow) !== "undefined");
    });
}

function showTourCanBeFoundHereTooltip(){
  var tooltip = $("#tour-help-tooltip");
  tooltip.find(".tooltip-close").on("click",function(){
    tooltip[0].hide();
  });
  tooltip[0].show();
  tooltip[0].onmouseleave = function(e){
    this.hide();
  }
}

function bindReloadToursEvent(){
  $("#application").find("iframe").load(function(){
    var contents = $(this).contents(); // contents of the iframe
    contents.on('reload-tours', function() {
      appHelpVisibleRefresh(); 
    });
    contents.on('show-tour-found-here', function() {
      showTourCanBeFoundHereTooltip();
    });
  });
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

  $("#application").append(generateApplicationIframe(app, function (frame) {

    appHelpVisibleRefresh();

    if (callback) {
      callback(frame);
    }
    checkStartTour();
  }));
  bindReloadSideBarEvent();
  bindReloadToursEvent();
}

function bindNotificationBarEvent() {
  $("#notifications-open, #notifications-close").click(function () {
    $("#notification-drawer")[0].toggle();
  });
  $("#delete-all-notifications").click(function() {
    deleteAllNotifications();
  });
}

function findApp(id, apps) {
  return apps.find(function (app) {
    return app.id === id;
  });
}

function setNotificationNumber(notificationNumber,append=false) {
  var notificationNumberElement = $("#notification-number");
  var offset = append ? parseInt(notificationNumberElement.prop("label") || 0) : 0;
  var final = notificationNumber + offset;
  if (final) {
    notificationNumberElement.show();
    notificationNumberElement.prop("label", final);
  } else {
    notificationNumberElement.hide();
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
    setNotificationNumber(0 - notificationClass.length,true);
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
  }else{
    hideNoNotificationsMessage();
  }
}

function deleteAllNotifications(){
  long_rpc_promise(desktopAppId,"delete_all_notifications",[]).done(function(){
    reloadNotifications();
  });
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
function hideNoNotificationsMessage() {
  $("#no-notifications-message").hide();
}

function loadNotifications(notifications, apps) {
  notifications = processNotifications(notifications);
  var notiEl = $("#notifications");
  notiEl.children().not("#no-notifications-message").remove();

  for (var appId in notifications) {
    if (notifications.hasOwnProperty(appId)) {
      var app = notifications[appId];

      for (var title in app) {
        if (app.hasOwnProperty(title)) {
          appendToElement(
            notiEl,
            generateNotification(app, appId, title, apps)
          );
        }
      }
    }
  }

  if (jQuery.isEmptyObject(notifications)) {
    showNoNotificationsMessage();
  }else{
    hideNoNotificationsMessage();
  }
}

function reloadNotifications(){
  Q.spread([
    apps(),
    notifications()
  ], function (apps, notifications) {
    loadNotifications(notifications, apps);
    setNotificationNumber(notifications.length);
  });
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
        if( response.indexOf("<!DOCTYPE HTML>") != -1 ){
          <% if platform_information.model == "LH1000" then %>
          location.replace(location.protocol + "//" + location.hostname + "/home.htm");
          <% elseif platform_information.model == "DJA0231" or platform_information.model == "DJA0230" then %>
          location.replace(location.protocol + "//" + location.hostname + "/home.lp");
          <% else %>
          location.reload();
          <% end %>
          return;
        }

        var parsedResponse = JSON.parse(response);

        /* use routerlogin for redirects as IP may have changed e.g. AP mode */
        var url = location.protocol + "//" + "routerlogin.net";   

        if (parsedResponse.router) {
          if( hasBeenFactoryReset ){
            location.reload();
            return;
          }
          /*
          * Make sure in correct mode either Router or AP.
          */
          if( Boolean( apMode ) != Boolean( parsedResponse.ap_mode ) ){
            apMode = parsedResponse.ap_mode;
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

          if (parsedResponse.notificationRefresh !== notificationRefresh){
            reloadNotifications();
            notificationRefresh = parsedResponse.notificationRefresh;
          }

          if (typeof top.accessibility_mode !== "undefined" && parsedResponse.accessibilityMode !== top.accessibility_mode){
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
      <% if platform_information.model ~= "LH1000" then %>
      location.href = "/desktop/chrome-https.html";
      <% end %>
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
    <% elseif platform_information.model == "LH1000" then %>
    //Ripped from LH000
    var dLogout=GetCookie("disableLogout");
    dLogout=(dLogout)?dLogout:0;
    if(dLogout==0){              
      window.location.href=URLTimeStamp("/logout.htm");
    }
    <% elseif platform_information.model == "DJA0231" or platform_information.model == "DJA0230" then %>
    var token = $("meta[name=CSRFtoken]").attr("content");
    if(token){

      $.ajax({
        url: "/login.lp",
        type: 'POST',
        data: {
          do_signout: 1,
          CSRFtoken: token
        },
        success: function(data){
          console.log("Logging out...")
        }
      })
    }
    <% else %>
    // document.location = "http://log:out@" + document.domain;
    var xml = new XMLHttpRequest();
    xml.open('GET',document.baseURI,false,"a","a");
    xml.setRequestHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
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

  function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); // $& means the whole matched string
  }

  $("#account-settings-password").change(function () {

    var passwordConfirmation = $("#account-settings-password-confirmation")[0];

    $(passwordConfirmation)
      .prop("pattern", "^" + escapeRegExp($(this).val()) + "$");

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

function bindRappOverview(){
  $("#rapp-overview-button").click(function () {
    $("#rapp-overview")[0].open();
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
      { text: "<%= platform_information.vendor == "TELSTRA" and "Reboot" or i18n.reboot %>", action: "confirm", callback: function () {

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
          //Timeout - allow webserver to stop first
          setTimeout(function(){
            hasBeenFactoryReset = true;
          },1000)
        }); 

      }}  
    ]   
  );  
}
function onRestoreDefaultsClick() {
  $("#restore-defaults-dialog")[0].open();
}

<% if platform_information.model == "XR1000" then %>
function bindNetgearArmor() {
  var armor_remind_check = $("#armor-reminder");
  var armor_status_light = $("#armor-enabled > granite-led");
  var armor_status_text = $("#armor-enabled > span");
  $("#ng-armor-button").click(function () {
    Q.spread([
      long_rpc_promise(configAppId,"ng_armor_status",[]),
      long_rpc_promise(configAppId,"ng_armor_remind_me",[])
    ],function(status,remind_me){
      status = status[0];
      remind_me = remind_me[0];
      armor_status_light.attr("powered",status ? true : null);
      var status_text = (status === undefined || status === null) ? "NOT ACTIVATED" : (status ? "ENABLED" : "DISABLED");
      armor_status_text.text(status_text);
      armor_remind_check.attr("checked",remind_me ? true : null);
      $("#ng-armor-dialog")[0].open();
    })
  });
  armor_remind_check.on('checked-changed',function(e){
    long_rpc_promise(configAppId,"ng_armor_remind_me",[e.detail.value]).done();
  });
}
<% end %>

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

function _firmwareDialogButtonsHidden(state){
  var divP = $("#firmware-upgrade-button").parent();
  divP.find("paper-button").attr("hidden",!!state);
  divP.prev().attr("hidden",!state);
}

function bind_updatebtn_click_generic(){
  var upgradeButton = $("#firmware-upgrade-button");

  upgradeButton.click(function () {
    if ($("#firmware-upgrade-file").prop("files").length == 1) {
      $("#firmware-upgrade-file")[0]
        .uploadFile($("#firmware-upgrade-file").prop("files")[0]);
      _firmwareDialogButtonsHidden(true);
    }
  });

  $("#firmware-upgrade-file").on("files-changed", function (event) {
    var canUpload = false;
    if(!event.detail.path && Array.isArray(event.detail.value) && event.detail.value.length === 1){
      canUpload = true;
    }else if(event.detail.path === "files.length" && event.detail.value === 1){
      canUpload = true;
    }
    upgradeButton.prop("disabled",!canUpload);
  });

  $("#firmware-upgrade-file").on("success", function (response) {
    $("#firmware-upgrade-dialog")[0].close();

    $("#confirmation-dialog")[0].open();
    $("#confirmation-dialog paper-spinner-lite").prop("active", true);
  });

  $("#firmware-upgrade-file").on("error", function (e) {

    $(this).prop("errorText", e.detail.xhr.responseText);
    _firmwareDialogButtonsHidden(false);

    e.stopPropagation();
  });
  _doUpdateFirmwareDialogBind = false;
}

function updatebtn_click_generic(){
  $("#firmware-upgrade-dialog")[0].open();
  if(_doUpdateFirmwareDialogBind) bind_updatebtn_click_generic();
  $("#firmware-upgrade-file")[0].clear();
  $("#firmware-upgrade-button").prop("disabled", true);
}

function startFirmwareCheck() {
  var firmwareInformation;
  var updateButton = $("#update-button");
  var updateButtonText = $(".update-button-text, #update-button > span");

  updateButton.click(function () {
    <% if os.implements_netgear_specification() then %>
      updatebtn_click_netgear(firmwareInformation);
    <% else %>
      updatebtn_click_generic();
    <% end %>
  });

  if(updateButton[0]){
  /* NETGEAR platforms have automatic update detection. */
  <% if os.implements_netgear_specification() then %>
    start_cycle(function () {
      return [Q.promise(function (resolve) {
        serial_netgear_soap_rpc("DeviceConfig", "GetCheckNewFirmwareResult" )
          .done(resolve, resolve);
      })];

    }, function ( firmupdate ) {
      if(firmupdate.code === "000" && firmupdate.response.NewVersion !== "") {

        updateButton.prop("disabled", null);

        updateButtonText.text("<%= i18n.updateAvailable %>");

        firmwareInformation = firmupdate.response;

      } else {
        updateButton.prop("disabled", true);

        updateButtonText.text("<%= i18n.noUpdateAvailable %>");
      }
    }, firmware_check_interval);
  <% else %>
    updateButton.prop("disabled", null);
    updateButtonText.text("<%= i18n.update %>");
  <% end %>
  }
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

var doStartTourOnNextLoad = null;
function checkStartTour() {
  if(doStartTourOnNextLoad === true){
    hopscotch.startTour(getTour(window, true)(0), 0);
    <% if platform_information.vendor == "TELSTRA" then %>
    localStorage.setItem("block-force-tour-start",true);
    <% end %>
    doStartTourOnNextLoad = false;
  }else if (doStartTourOnNextLoad === null && getUrlParameter("forceTourStart") === "true" && !blockForceTourStart) {
    doStartTourOnNextLoad = true;
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

function createRappButton(detail){
  var newButton = $('<div rapp-button></div>').text(detail.text);
  if(detail.hasOwnProperty("checkbox")){
    var newCheckbox = $(document.createElement("paper-checkbox")).attr("checked",detail.checkbox ? true : null)
    if(detail.callback){
      newCheckbox.on("checked-changed",detail.callback)
    }
    newButton.prepend(newCheckbox);
  }else if(detail.hasOwnProperty("toggle")){
    var newToggle = $(document.createElement("paper-toggle-button")).attr("checked",detail.toggle ? true : null)
    if(detail.callback){
      newToggle.on("checked-changed",detail.callback)
    }
    newButton.prepend(newToggle);
  }else if(detail.callback){
    newButton.on("click",detail.callback);
  }
  if(detail.icon){
    newButton.prepend($(document.createElement("iron-icon")).attr("icon",detail.icon));
  }
  newButton.prepend(document.createElement("paper-ripple"));
  return newButton;
}
function bindGlobalMenuIframeEvents(frame){
  var iframe = $(frame);
  var buttons = $("#user-settings-button, #help-menu-button");
  var jhtml = iframe.contents();
  jhtml.on("click",function(){
    buttons.each(function(index,elem){
      if(elem.opened) elem.close();
    });
  });
  var rappSpecificButton = $("#rappMenuButton").attr("disabled",true);
  var rappSpecificDiv = $("#rappMenu");
  rappSpecificDiv.children("[rapp-button]").remove();
  jhtml.find("html").on("add-rapp-button",function(e){
    var newButton = createRappButton(e.detail);
    rappSpecificDiv.append(newButton);
    rappSpecificButton.attr("disabled",null);
  });
  duma.type.doListeners([jhtml[0]]);
}
function triggerBandwidthChange(download,upload) {
  var conts = $("#application").find("iframe").contents().find("html");
  var send = {}
  if(download || download === 0){
    send.down = parseInt(download);
  }
  if(upload || upload === 0){
    send.up = parseInt(upload);
  }
  conts[0].dispatchEvent(new CustomEvent("network-speeds-changed", {detail:send}));
}

function bindPreferences(){
  var notiToggle = $("#notifications-toggle");
  long_rpc_promise(desktopAppId,"enable_notifications",[]).done(function(result){
    if(result[0]){
      notiToggle.attr("checked",true);
    }
  });
  notiToggle.on("checked-changed",function(e){
    long_rpc_promise(desktopAppId,"enable_notifications",[e.detail.value]).done();
  });
  <% if platform_information.model == "R2" then %>
  var teleToggle = $("#telemetry-toggle");
  long_rpc_promise(configAppId,"toggle_telemetry",[]).done(function(result){
    if(result[0]){
      teleToggle.attr("checked",true);
    }
  });
  teleToggle.on("checked-changed",function(e){
    long_rpc_promise(configAppId,"toggle_telemetry",[e.detail.value]).done();
  });
  <% end %>
}

function bindAccessibilitySettings(){
  var accessibilityModeToggle = $("#accessibility-toggle");
  var chartTableModeToggle = $("#chart-table-toggle");
  var accessDialog = $("#accessibility-dialog");

  var accessButton = $("#accessibility-button");

  var accessibilitySaveButton = accessDialog.find("#accessibility-save");
  var accessibilityCancelButton = accessDialog.find("#accessibility-cancel");

  var isSaveEnabledChecks = [];

  function updateSave(){
    for(var i = 0; i < isSaveEnabledChecks.length; i ++){
      if(isSaveEnabledChecks[i]()){
        accessibilitySaveButton.prop("disabled",null);
        return
      }
    }
    accessibilitySaveButton.prop("disabled",true);
  }

  // accessibility mode
  accessibilityModeToggle.prop("checked",top.accessibility_mode);
  isSaveEnabledChecks.push(function(){
    return accessibilityModeToggle.prop("checked") !== top.accessibility_mode;
  });
  accessibilityModeToggle.on("checked-changed",updateSave);

  // charts as tables
  chartTableModeToggle.prop("checked",top.chartsAsTables);
  isSaveEnabledChecks.push(function(){
    return chartTableModeToggle.prop("checked") !== top.chartsAsTables;
  });
  chartTableModeToggle.on("checked-changed",updateSave);


  accessibilitySaveButton.click(function(){
    // send changes to values with rpcs here
    var willReloadLater = false;
    if(accessibilityModeToggle.prop("checked") !== top.accessibility_mode){
      if(accessibilityModeToggle.prop("checked")) duma.storage("com.netdumasoftware.devicemanager", "deviceViewMode", "table");
      willReloadLater = true;
      long_rpc_promise(configAppId,"accessibility_mode",[accessibilityModeToggle.prop("checked")]).then(function(){
        location.reload();
      });
    }
    if(chartTableModeToggle.prop("checked") !== top.chartsAsTables){
      localStorage.setItem("chartsAsTables",chartTableModeToggle.prop("checked"));
      if(!willReloadLater) location.reload();
    }
    accessDialog[0].close();
  });
  accessibilityCancelButton.click(function(){
    // revert changes here
    accessibilityModeToggle.prop("checked",top.accessibility_mode);
    chartTableModeToggle.prop("checked",top.chartsAsTables);
    accessDialog[0].close();
  });

  accessDialog.on("iron-overlay-closed",function(){
    updateSave();
  });

  $("#enable-all-accessibility",accessDialog[0]).click(function(){
    // add enable all here
    accessibilityModeToggle.prop("checked",true);
  });
  
  accessButton.click(function(){
    accessDialog[0].open();
    updateSave();
  });

  duma.type.OnWord("access",accessDialog[0].open.bind(accessDialog[0]));
}

function bindDumaosSuspend(){
  $("#dumaos-suspend").click(function(){
    window.location.replace("/cgi-bin/restart.htm?cache=0&ACTION=stop")
  })
}

/**
 * Bind menu buttons on the top nav bar
 */
function bindGlobalMenuButtons() {
  setupSettingsPages();
  //Network speeds button
  $('#network-speeds-button').click(function() {
    $("#network-speeds")[0].open();
  });

  //Services Info button
  $('#services-info-button').click(function() {
    $("#services-info")[0].open();
  });

  $("#preferences-button").click(function(){
    $("#preferences-dialog")[0].open();
  });

  $("#network-speeds").on("speeds-saved",function(e){
    var vals = e.detail;
    triggerBandwidthChange(vals.download,vals.upload);
  });

};

function setupSettingsPages(){
  var buttons = $("#user-settings-button, #help-menu-button");
  // On click, does the menu close?
  buttons.each(function(index,elem){
    if(elem.close){
      var menu = $(elem).find("duma-menu");
      menu.on("menu-click",function(e){
        elem.close();
      });
    }
  });
  buttons.on("iron-overlay-closed",function(e){
    var menu = $(e.target).closest("paper-menu-button");
    if(menu[0]){
      menu.find(".dropdown-trigger").blur();
    }
  });
}

function extendCookieCycle(){
  <% if platform_information.model == "LH1000" then %>
  setInterval(function(){
    $.ajax(location.origin);
  },1000 * 60);
  <% end %>
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
    activeTheme(),
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
    bindRappOverview();
    loadThemes(themes, activeTheme);
    bindGlobalMenuButtons();
    bindPreferences();
    bindAccessibilitySettings();
    bindDumaosSuspend();

    
    history.replaceState({}, null, location.pathname + location.hash);

    <% if platform_information.sdk == "OpenWRT" then %>
      bindAccountSettings();
    <% end %>

    <% if platform_information.model == "XR1000" then %>
    bindNetgearArmor();
    <% end %>

    $("#skip-nav-focus-button").on("click",function(){
      $($("#application").find("iframe").contents()).find("duma-panel:first").find(".skip-to-next-panel").focus();
    });

    extendCookieCycle();

    removePageLoader();
  }).done();
});
