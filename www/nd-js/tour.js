/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
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
    reloadTourButton: function(){
      if(top !== window){
        fireTop("reload-tours");
      }else if(typeof appHelpVisibleRefresh === "function"){
        appHelpVisibleRefresh();
      }
    },

    fireTourFoundHere: function(){
      fireTop("show-tour-found-here");
    },

    setTour: function (appId, tour, desktop) {
      if (desktop === true) {
        desktopTour = function (start) {
          start = typeof start === "undefined" ? 0 : start;
          var ret = processTour(tour(start), appId);
          return ret;
        }
      } else {
        savedTour = function (start) {
          start = typeof start === "undefined" ? 0 : start;
          var ret = processTour(tour(start), appId);
          return ret;
        };
      }
      duma.tour.reloadTourButton();
    },

    getTour: function (desktop) {
      return desktop === true ? desktopTour : savedTour;
    },

    addOnEndShowTooltip: function(){
      hopscotch.listen("end",duma.tour.fireTourFoundHere);
      hopscotch.listen("close",duma.tour.fireTourFoundHere);
    },
    removeOnEndShowTooltip: function(){
      hopscotch.unlisten("end",duma.tour.fireTourFoundHere);
      hopscotch.unlisten("close",duma.tour.fireTourFoundHere);
    },
  };
})();
