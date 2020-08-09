/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function () {

var packageId = "com.netdumasoftware.desktop";

function postPanelInit(panel, showNoPanelsMessageIfLastPanel) {
  var panels = $("duma-panels")[0];

  $(panel).find("duma-panel").removeAttr("show-close");
  $(panel).on("pinClick", function (e, pinned) {
    if (!pinned) {
      panels.remove(panel);
      showNoPanelsMessageIfLastPanel();
    }
  });
}

function createDebounce(callback, wait) {
  var timeout;
  return function () {
    if (timeout) {
      clearTimeout(timeout);
    }

    var args = [].slice.call(arguments);

    timeout = setTimeout(function () {
      timeout = null;
      callback.apply(null, args);
    }, wait);
  }
}

function showNoPanelsMessage() {
  $("#empty-message").show();
}

function hasPosition(x, y) {
  return typeof x !== "undefined" &&
         typeof y !== "undefined" &&
         x !== null &&
         y !== null;
}

function getPanelInformation(el) {
  var panel = $(el).find("duma-panel");

  return {
    file: $(panel).prop("_file"),
    package: $(panel).prop("_package"),
    data: $(panel).prop("_data"),
  };
}

function savePanelPositions(save) {
  var panels = $("duma-panels")[0].list();

  var panelPositions = [];

  for (var i = 0; i < panels.length; i++) {
    var panel = panels[i];
    var panelInformation = getPanelInformation(panel.element);

    if (
      typeof panelInformation.file === "undefined" ||
      typeof panelInformation.package === "undefined" ||
      typeof panelInformation.data === "undefined"
    ) {
      continue;
    }

    panelPositions.push({
      height: panel.height,
      width: panel.width,
      x: panel.x,
      y: panel.y,
      file: panelInformation.file,
      package: panelInformation.package,
      data: panelInformation.data
    });
  }

  save(panelPositions)
}

function loadPinnedPanels(pinnedPanels) {
  pinnedPanels = pinnedPanels[0];

  var panels = $("duma-panels")[0];

  for (var i = 0; i < pinnedPanels.length; i++) {

    var panel = pinnedPanels[i];

    panels.add(
      panel.path, panel.package,
      panel.data == "nil" ? null : JSON.parse(panel.data),
      {
        _desktop: true,
        width: panel.colsize,
        height: panel.rowsize,
        autoPosition: !hasPosition(panel.xpos, panel.ypos),
        x: panel.xpos,
        y: panel.ypos,

        initialisationCallback: (function (panelInformation, pinnedPanels) {
          return function (panel) {

            postPanelInit(panel, function () {

              pinnedPanels.splice(
                pinnedPanels.indexOf(panelInformation), 1
              );

              if (pinnedPanels.length === 0) {
                showNoPanelsMessage();
              }
            });

          };
        })(panel, pinnedPanels)
      }
    );
  }

  if (pinnedPanels.length === 0) {
    showNoPanelsMessage();
  }
}

browserSetup.onReady(function () {
  $(document).ready(function () {

    var debounce = createDebounce(function (panels) {
      long_rpc_promise(packageId, "update_pinned", [panels]).done();
    }, 1000 * 2.5)

    $("duma-panels").on("resizestop dragstop", function () {
      setTimeout(savePanelPositions, 1, debounce);
    });

    long_rpc_promise(
      packageId,
      "get_pinned", []
    ).done(loadPinnedPanels);
  });
});

})();
