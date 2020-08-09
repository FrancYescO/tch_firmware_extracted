/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

var duma = duma || {};

duma.tour = (function () {
  var savedTour;
  var desktopTour;

  function processTour(tour, appId) {
    tour.id = ("tour." + appId).replace(/\./g, "_");
    
    tour.i18n = {
      nextBtn: "<%= i18n.next %>",
      prevBtn: "<%= i18n.previous %>",
      doneBtn: "<%= i18n.done %>",
      skipBtn: "<%= i18n.skip %>",
      closeTooltip: "<%= i18n.close %>",
    };

    var steps = tour.steps;

    for (var i = 0; i < steps.length; i++) {
      var step = steps[i];

      if (typeof step.target === "function") {
        step.target = step.target();
      }
    }

    return tour;
  }

  return {
    setTour: function (appId, tour, desktop) {
      if (desktop === true) {
        desktopTour = function (start) {
          start = typeof start === "undefined" ? 0 : start;
          return processTour(tour(start), appId);
        }
      } else {
        savedTour = function (start) {
          start = typeof start === "undefined" ? 0 : start;
          return processTour(tour(start), appId);
        };
      }
    },

    getTour: function (desktop) {
      return desktop === true ? desktopTour : savedTour;
    }
  };
})();
