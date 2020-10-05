/***************
  infoService
****************/
angular.module('fw').service('infoService',['$q','$log','api', 'appSoftwareVersion', function($q, $log, api, appSoftwareVersion) {

  this.sysinfo = function() {
    return api.get('sysinfo').then(function(data){
      angular.extend(data, {
          sw_version: appSoftwareVersion
      })
      return  data;
    });
  }

  this.restart = function() {
    return api.set('reset');
  }

}]);

