/***************
  settingsService
****************/
angular.module('fw').service('settingsService',['$q','$log','api', function($q, $log, api) {
  var settingsVars = {
      'widget_order': 'key_00',
      'w_split_networks': 'key_01'
      // Eventually add up to key_19
  };


  this.get = function(key) {
    return api.get('fw_settings').then(function(data){
      return data[settingsVars[key] || null] || data[key] || null;
    });
  };

  this.set = function(key, val) {
    key = settingsVars[key] || key;
    var o = {};
    o[key] = val;
    return api.set('fw_settings', o);
  };

}]);

