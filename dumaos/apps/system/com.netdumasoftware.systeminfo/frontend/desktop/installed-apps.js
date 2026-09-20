/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var packageId = "com.netdumasoftware.procmanager";

function onAppPlayPauseClick(app, button) {
  var method;
  if ($(button).prop("icon") == playIcon) {
    method = "start";
  } else {
    method = "stop";
  }

  long_rpc(packageId, method, [app.id], function () {
    if ($(button).prop("icon") == playIcon) {
      $(button).prop("icon", stopIcon);
    } else {
      $(button).prop("icon", playIcon);
    }
  });
}

function onAppRunOnStartupChange(app, button) {
  long_rpc_promise(packageId, "prop_boot", [
    app.id,
    $(button).prop("checked")
  ]).done();
}

function loadApp(app) {
  var promise = long_rpc_promise(packageId, "rapp_diskusage", [app.id]);
    
  promise.done(function (usage) {
    if (typeof app.name != "undefined") {
      if (!app.icon) {
        app.icon = "/apps/com.netdumasoftware.systeminfo/shared/default.svg";
      }

      var stopIcon = "av:pause-circle-outline";
      var playIcon = "av:play-circle-outline";

      $("#installed-apps-table", context).append($("<tr></tr>")
        .append($("<td></td>")
          .append($("<duma-image></duma-image>")
            .attr("src", app.icon)))
        .append($("<td></td>")
          .text(app.name))
        .append($("<td></td>")
          .text(binary_format(usage)))
        .append($("<td></td>")
          .append($("<paper-icon-button></paper-icon-button>")
            .prop("icon", (function () {
              if (app.running) {
                return stopIcon;
              } else {
                return playIcon;
              }
            })())
            .click((function (app) {
              return function () {
                onAppPlayPauseClick(app, this);
              };
            })(app))
            .prop("disabled", (function () {
              if (app.system) {
                return true;
              } else {  /* allowing users this is a support bomb waiting to explode! */
                return true;  // false;
              }
            })())
          )
        ).append($("<td></td>")
          .append($("<paper-checkbox><%= i18n.runOnStartup %></paper-checkbox>")
            .prop("disabled", (function () {
              if (app.system) {
                return true;
              } else {  /* allowing users this is a tech support bomb waiting to explode! */
                return true;
              }
            })())
            .prop("checked", (function () {
              if (app.boot || app.system) {
                return true;
              } else {
                return false;
              }
            })())
            .change((function (app) {
              return function () {
                onAppRunOnStartupChange(app, this);
             };
            })(app))
          )
        )
      );
    }
  });

  return promise;
}

function updateInstalledRapps(installedRapps) {
  $("#installed-apps-table", context).empty();

  var promises = [];

  for (var i = 0; i < installedRapps.length; i++) {
    promises.push(loadApp(installedRapps[i]));
  }

  Q.spread(promises, function () {
    $("duma-panel", context).prop("loaded", true);
  });
}

function saveRetry(retry) {
  long_rpc_promise(packageId, "prop_retry", [retry]).done();
}

function loadRetry(retry) {
  $("#restart-retry", context).prop("value", retry);
}

Q.spread([
  long_rpc_promise(packageId, "installed_rapps", []),
  long_rpc_promise(packageId, "prop_retry", [])
], function (installedRapps, retry) {
  updateInstalledRapps(installedRapps[0]);
  loadRetry(retry[0]);
});

$("#restart-retry", context).change(function () {
  if ($(this)[0].validate()) {
    saveRetry($(this).prop("value"));
  }
});

})(this);

//# sourceURL=installed-apps.js
