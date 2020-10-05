/***************
  ontService
****************/
angular.module('fw').service('ontService',['$q','$log','api', 'appSoftwareVersion', function($q, $log, api, appSoftwareVersion) {

  this.sysinfo = function() {
    return api.get('ont_value').then(function(data){
      return  data;
    });
  }

  this.get_ont_available = function() {
    return api.get('ont_available').then(function(data){
      return data;
    });
  }

  this.reset = function(net) {
    return api.set('ont_value',{
      enable: net.ont_checks.enabled ? 1 : 0
    });
  }

}]);
