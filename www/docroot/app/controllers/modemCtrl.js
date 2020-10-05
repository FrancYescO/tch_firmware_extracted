  /***************
    modemController
  ****************/
angular.module('fw')
.controller('modemCtrl', ['$timeout', '$scope', 'modemService', '$q', 'navService',
    function($timeout, $scope, modemService, $q, navService) {
        $scope.isDataReadyP1 = false;
        $scope.isDataReadyP2 = false;
        $scope.isDataReadyP3 = false;
        $scope.isDataReadyP4 = false;

        // LED STATUS
        $scope.status = {
            isDirty: true
        };
        
        $scope.init_led_status = function(){
            modemService.led_status().then(function(data){
                $scope.status = data;
                $scope.presence_orig = $scope.status.presence;
                $scope.auto_off_orig = angular.merge({}, $scope.status.auto_off);
                $scope.isDataReadyP1 = true;
            });
        };
        
        $scope.$on('modem_refresh_start', function(e, args){
            $scope.isDataReadyP1 = false;
        });
        $scope.$on('modem_refresh', function(e, args){
            $scope.status = args;
            $scope.isDataReadyP1 = true;
        });
        
        // LINE STATUS
        $scope.refresh_line_status = function(){
            $scope.isDataReadyP2 = false;

             $q.all([
                modemService.line_status(),
                modemService.ping_status()
            ]).then(function(data){
                $scope.line = data[0];
                angular.merge($scope.line, data[1]);
                $scope.isDataReadyP2 = true;
            });
        };
        
        // WIFI STATUS
        $scope.refresh_wifi_status = function(){
            $scope.isDataReadyP3 = false;
            modemService.wifi_status().then(function(data){
                $scope.wifi = data;
                $scope.isDataReadyP3 = true;
            });
        };
        
        // PORTS STATUS
        $scope.refresh_ports_status = function(){
            $scope.isDataReadyP4 = false;
            modemService.ports_status().then(function(data){
                $scope.ports = data;
                $scope.isDataReadyP4 = true;
            });
        };
        
        $q.all([
            $scope.refresh_line_status(),
            $scope.refresh_wifi_status(),
            $scope.refresh_ports_status(),
            $scope.init_led_status()
        ]).then(function(){});
        
        $scope.save_data = function(){
            $scope.isDataReadyP1 = false; 
            modemService.update_status($scope.status.presence, $scope.status.auto_off)
            .then(function(){
                return $timeout($scope.init_led_status, 1000);
            });
        };
        $scope.reset = function(){
            $scope.status.presence = $scope.presence_orig;
            $scope.status.auto_off = angular.merge({}, $scope.auto_off_orig);
        };

        navService.isDirty(function() {
            return  $scope.isDataReadyP1 &&
                    $scope.status.presence != $scope.presence_orig ||
                    angular.toJson($scope.status.auto_off) != angular.toJson($scope.auto_off_orig);
        });
        
        // June modify for led end time checking start
        $scope.checkLedEndTime = function(){
            if($scope.status.auto_off.from==$scope.status.auto_off.to){
                var index=0;
                for(var i=0; i<$scope.hh_ranges.length; i++){
                    if($scope.hh_ranges[i]==$scope.status.auto_off.to){
                        index=i;
                        break;
                    }
                }
                if(index+1>=$scope.hh_ranges.length)
                    $scope.status.auto_off.to=$scope.hh_ranges[0];
                else
                    $scope.status.auto_off.to=$scope.hh_ranges[index+1];
            }
        };
        // June modify for led end time checking end
        
        $scope.hh_ranges = [];
        for(var i = 0; i < 24; i++){
          for(var k = 0; k < 60; k += 30){
            $scope.hh_ranges.push( (i < 10 ? '0' : '') + i +':' + (k < 10 ? '0' : '') + k);
          }
        }
    }])
;
