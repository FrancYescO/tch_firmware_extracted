angular.module('fw')

    .controller('infoCtrl', ['$translate','$scope', 'infoService', function($translate, $scope, infoService) {
        infoService.sysinfo().then(function(data){
            angular.extend($scope, data);
            $scope.isDataReady = true;
        });
        $scope.restart = infoService.restart;
    }])
;