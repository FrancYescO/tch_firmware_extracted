angular.module('fw')
  .controller('errorsCtrl', ['$log','$scope','$rootScope','$uibModal', function($log, $scope, $rootScope, $uibModal) {

    var modalInstance = null;

    $rootScope.$on('SERVICE_ERROR', function(e, data){
        if(modalInstance == null) {
            $scope.errorInfo = data;
            modalInstance = $uibModal.open({
              templateUrl: 'modal_errors',
              controller: 'modalErrorsCtrl',
              controllerAs: 'ctrl',
              scope: $scope,
              size: 'error'
            });

            modalInstance.result.then(function(){},
              function(e) {
                modalInstance = null;
            });
        }
    });
}])

.controller('modalErrorsCtrl',['$uibModalInstance', '$scope', function ($uibModalInstance, $scope) {
    var ctrl = this;
    ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
}]);