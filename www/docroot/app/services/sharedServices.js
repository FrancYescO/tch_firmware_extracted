angular.module('fw').service('api',['$http','$rootScope','$log','apiServiceUrl', function($http, $rootScope, $log, apiServiceUrl) {
  
  this.get = function(service, svc_params) {

    return $http.get(apiServiceUrl, {
        params: angular.extend({
          nvget: service,
          '_': new Date().getTime() // anti-cache for IE
        }, svc_params)
      })
      .then(
          function(response) {  //success callback
            if(service != 'login_confirm' && (response.data.login_confirm || {}).login_status == 0) {
              $log.error('USER UNAUTHORIZED', response.data);
              $rootScope.$broadcast('LOGOUT');
              return {};
            }
            $log.debug('Received ' + service, response.data[service]);
            return response.data[service];
          }, 
          function(response) { //error callback
            $log.error(response);
            $rootScope.$broadcast('SERVICE_ERROR', {serviceName: service});
          }
      );
  }

  this.set = function(service, svc_params) {
    var opts = {
      params: angular.extend({
        act: 'nvset',
        service: service,
        '_': new Date().getTime() // anti-cache for IE
      }, svc_params)
    };

    $log.debug('Calling nvset ' + service, opts);

    return $http.get(apiServiceUrl, opts)
      .then(
          function(response){  //success callback
            if(service != 'login_confirm' && (response.data.login_confirm || {}).login_status == 0) {
              $log.error('USER UNAUTHORIZED', response.data);
              $rootScope.$broadcast('LOGOUT');
              return {};
            }
            return response.data;
          },
          function(response){ //error callback
            $log.error(response);
            $rootScope.$broadcast('SERVICE_ERROR', {serviceName: service});
            return response;
          } 
      );
  }
}])

.service('navService', ['$state','$rootScope','$log','$uibModal', function($state, $rootScope, $log, $uibModal) {
  var _state = {};

  this.isDirty = function(callback) {_state.hasPendingChanges = callback;};

  this.hasPendingChanges = function() {
    return typeof(_state.hasPendingChanges) == 'function' && _state.hasPendingChanges();
  }

  this.warnUserAboutPendingChanges = function(toState, toParams) {
    $uibModal.open({
        templateUrl: 'views/modals/modal_has_pending_changes.html',
        size: 'lg'
      }).result.then(function() {
          _state.hasPendingChanges = null;
          $state.go(toState.name, toParams);
      });
  }

}]);