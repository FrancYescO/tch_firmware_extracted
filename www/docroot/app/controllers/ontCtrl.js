angular.module('fw')

    .controller('ontCtrl', ['$translate','$scope', 'ontService', function($translate, $scope, ontService) {
        ontService.sysinfo().then(function(data){
          //console.log(data);
            angular.extend($scope, data);
            $scope.ont_checks = {enabled:false};
            //console.log($scope);
            $scope.isDataReady = true;
            if (data.enable==1){
              $scope.ont_checks.enabled=true;
            }
            else{
              $scope.ont_checks.enabled=false;
            }
            $scope.original_data = angular.merge({}, data);
        });

        ontService.get_ont_available().then(function(data){
          //console.log(data);
          //console.log($scope.ont_available);
          $scope.ont_available = (data.enable_ont == 1);
          //console.log($scope.ont_available);
        });

        $scope.save_ont_changes = function(){
          //console.log($scope.ont_available);
          if ($scope.ont_available == 1){
            //console.log("inside if");
            $scope.saving_auto_checks = true;
            $scope.auto_checks_orig = angular.merge({}, $scope.auto_checks);
            ontService.reset($scope).then(function(data){
                $scope.saving_auto_checks = false;
                $scope.original_data.enable = $scope.ont_checks.enabled ? 1 : 0;
            })
          }
          else{
              $scope.ont_checks.enabled=false;
            }
        }

        $scope.revert_ont_changes = function(){
          //console.log($scope.original_data.enable);
          if ($scope.original_data.enable == "1"){
            $scope.ont_checks.enabled=true;
          }
          else{
            $scope.ont_checks.enabled=false;
          }
          //console.log($scope.ont_checks.enabled);
          //console.log($scope.original_data);
        }
        //console.log($scope);
    }])
;
