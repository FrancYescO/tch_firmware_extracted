angular.module('fw').controller('wifiCtrl', ['$log','$scope','wifiService','settingsService','$q','$uibModal','$timeout','navService',
  function($log, $scope, wifiService, settingsService, $q, $uibModal, $timeout, navService) {

    $scope.auth_types = ['NONE','WEP','WPA2PSK','WPAWPA2PSK','WPA2ENT','WPAWPA2ENT'];
    $scope.guest_auth_types = ['WPA2PSK']; // June modify
    $scope.show_qrcode = {visible: false};
    $scope.show_qrcode_toggle = function(){ $scope.show_qrcode.visible = !$scope.show_qrcode.visible; };
    $scope.qrcode_string_security = function(){
        return $scope.guest_network.security === 'WEP'? 'WEP' : 'WPA';
    };
    $scope.qrcode_string = function(){
        return 'WIFI:S:'+$scope.guest_network.SSID+';T:'+($scope.guest_network.security === 'WEP'? 'WEP' : 'WPA')+';P:'+$scope.guest_network.auth_key+';';
    };

    wifiService.all_networks().then(function(data) {
        // store original data cloning objects into a variable (merge performs a deep copy)
        $scope.original_data = angular.merge({}, data);

        angular.merge($scope, data);
        $scope.isDataReady = true;
        $scope.wifi_dataReady = true; // June modify
        $scope.wifi_guest_dataReady = true; // June modify
        // June modify start
        // If "gui_wps_enabled=0", the WPS switch button should be "off".
        // If "gui_wps_enabled=1", the WPS switch button is based on "wps_enabled"(wl*_wps_mode).
        if(data.gui_wps_enabled==0) {
            $scope.wps_enabled.enabled=false;
            $scope.original_data.wps_enabled=false;
        }
        $scope.wps_org_enabled = data.wps_enabled.enabled; // June modify for WPS orginal status.
        // June modify end
    });

    function _canEnableWPS(security){
        switch(security) {
            case 'NONE':
            case 'WPA2PSK':
                return true;
            default:
                return false;
        }
    }

    $scope.canEnableWPS = function(){
        // June modify start
        //return _canEnableWPS($scope.split_networks.active ? $scope.main_network_2G.security : $scope.shared_settings.security);
        var enableWPS_2G=0, enableWPS_5G=0;
        if(!$scope.split_networks.active){
            if($scope.shared_settings.broadcast && _canEnableWPS($scope.shared_settings.security)){
                return true;
            }else{
                return false;
            }
        }else{
            if($scope.main_network_2G.enabled && $scope.main_network_2G.broadcast){
                if(_canEnableWPS($scope.main_network_2G.security)){
                    enableWPS_2G=1;
                }
            }
            if($scope.main_network_5G.enabled && $scope.main_network_5G.broadcast){
                if(_canEnableWPS($scope.main_network_5G.security)){
                    enableWPS_5G=1;
                }
            }
        }
        if(enableWPS_2G || enableWPS_5G){
            return true;
        }
        // June modify end
    };

    $scope.canTriggerWPS = function(){
        // June modify start
        //return _canEnableWPS($scope.original_data.main_network_2G.security);
        var canTriggerWPS_2G=0, canTriggerWPS_5G=0;
        if(_canEnableWPS($scope.original_data.main_network_2G.security)){
            canTriggerWPS_2G=1;
        }
        if(_canEnableWPS($scope.original_data.main_network_5G.security)){
            canTriggerWPS_5G=1;
        }
        if((canTriggerWPS_2G || canTriggerWPS_5G) && $scope.wps_org_enabled==true){
            return true;
        }else{
            return false;
        }
        // June modify end
    };

    $scope.setSecurity = function(net_type, aut_type){
        $scope[net_type].security = aut_type;
    };

    $scope.authRequiresPassword = function(aut_type){
       switch(aut_type){
            case 'WEP':
            case 'WPA2PSK':
            case 'WPAWPA2PSK':
                return true;
            default:
                return false;
        }
    };

    $scope.authRequiresRadius = wifiService.authRequiresRadius;

    var regex = [
        "[A-Z]",        //Uppercase Alphabet.
        "[a-z]",        //Lowercase Alphabet.
        "[0-9]",        //Digit.
        "[$@$!%*#?&]"   //Special Character.
    ];

    $scope.calcStrength = function(pwd) {
        var passed = 0;
 
        if(typeof(pwd) ==='string' && pwd.length > 0) {
            //Validate for each Regular Expression.
            for (var i = 0; i < regex.length; i++) {
                if (new RegExp(regex[i]).test(pwd)) {
                    passed++;
                }
            }
            //Validate for length of Password.
            if (passed > 2 && pwd.length > 10) {
                passed++;
            }
        }

        switch (passed) {
            case 0: return "NONE";
            case 1: return "LOW";
            case 2: return "MEDIUM";
            case 3:
            case 4: return "HIGH";
            default: return "VERY_HIGH";
        }
    }

    $scope.warnUserAndSubmitMainNetworkChanges = function() {

        function startCountdown() {
            var modalInstance = $uibModal.open({
              templateUrl: 'views/modals/modal_wifi_restart.html',
              size: 'lg',
              controller: 'modalWifiRestartCtrl',
              controllerAs: 'ctrl',
              scope: $scope,
              backdrop: 'static'
            });
        }

        if((!$scope.wifi_status.enabled) ||
            ($scope.split_networks.active && !$scope.main_network_5G.enabled && !$scope.main_network_2G.enabled)) {

            var modalInstance = $uibModal.open({
              templateUrl: 'views/modals/modal_wifi_disabled.html',
              size: 'lg',
              controller: 'modalWifiWarnUserCtrl',
              controllerAs: 'ctrl'
            });

            modalInstance.result.then(function(res) {
                return (res && res.confirm && startCountdown());
            });
        }
        else {
            startCountdown();
        }
    }

    $scope.submitMainNetworkChanges = function(){
        $scope.wifi_dataReady = false; // June modify
         if(!$scope.split_networks.active) {
            angular.merge($scope.main_network_5G, $scope.shared_settings);
            angular.merge($scope.main_network_2G, $scope.shared_settings);
        };

        if(!$scope.wifi_status.enabled) {
            $scope.main_network_5G.enabled = false;
            $scope.main_network_2G.enabled = false;
            $scope.wps_enabled.enabled = false; // June modify
        }
        // June modify start
        else{
            if(!$scope.split_networks.active) {
                $scope.main_network_5G.enabled = true;
                $scope.main_network_2G.enabled = true;
            }
        }
        // If wifi radio disabled, the "gui_wps_enabled" will be "0", but "wl*_wps_mode" is "enabled".
        if($scope.gui_wps_enabled==0 && $scope.wifi_status.enabled) {
            // If gui_wps_enabled=0, means 2.4G/5G radio are disabled.
            // When wifi radio switch button trun from "off" to "on",
            // it will save the "enabled" to "wl*_wps_mode".
            $scope.wps_enabled.enabled = true;
        }
        // June modify end

        $scope.guest_network.SSID = 'GUEST-' + $scope.main_network_2G.SSID; // June modify
        return $q.all([
            wifiService.save_wps_status($scope.wps_enabled),
            wifiService.save_eco($scope.eco),
            wifiService.save_main_network_5G($scope.main_network_5G),
            settingsService.set('w_split_networks', $scope.split_networks.active ? '1' : '0')
        ]).then(function(data){
            return wifiService.save_main_network_2G($scope.main_network_2G);
        }).then(function(data){
            return $timeout(function(){
                // June modify start
                return wifiService.all_networks().then(function(data){
                    $scope.original_data = angular.merge({}, data);
                    angular.merge($scope, data);
                    $scope.wifi_dataReady = true;
                    if(data.gui_wps_enabled==0){
                        $scope.wps_enabled.enabled=false;
                        $scope.original_data.wps_enabled=false;
                    }
                    $scope.wps_org_enabled=data.wps_enabled.enabled; // June modify for WPS orginal status.
                });
                // June modify end
            }, 12000); // June modify
        });
    };

    $scope.triggerWPS = function(){

        var modalInstance = $uibModal.open({
          templateUrl: 'modal_trigger_wps.html',
          size: 'lg',
          controller: 'modalTriggerWPS',
          controllerAs: 'ctrl'
        });
    };

    // June modify for eco end time checking start
    $scope.checkEndTime = function(){
        if($scope.eco.start_time==$scope.eco.end_time){
            var index=0;
            for(var i=0; i<$scope.eco.hh_ranges.length; i++){
                if($scope.eco.hh_ranges[i]==$scope.eco.end_time){
                    index=i;
                    break;
                }
            }
            if(index+1>=$scope.eco.hh_ranges.length)
                $scope.eco.end_time=$scope.eco.hh_ranges[0];
            else 
                $scope.eco.end_time=$scope.eco.hh_ranges[index+1];
        }
    };
    // June modify for eco end time checking end

    $scope.submitGuestNetworkChanges = function() {
        $scope.wifi_guest_dataReady = false; // June modify
        $scope.guest_network.SSID = 'GUEST-' + $scope.main_network_2G.SSID;
        wifiService.save_guest_network($scope.guest_network).then(function(data){
            return $timeout(function(){
                return wifiService.guest_network();
            }, 3000);
        }).then(function(data){
            $scope.guest_network = data;
            $scope.wifi_guest_dataReady = true; // June modify

            $scope.original_data.guest_network = angular.merge({}, data);
        });
    };


    $scope.revertMainNetworkChanges = function() {
        angular.merge($scope.main_network_2G,   $scope.original_data.main_network_2G);
        angular.merge($scope.main_network_5G,   $scope.original_data.main_network_5G);
        angular.merge($scope.eco,               $scope.original_data.eco);
        angular.merge($scope.shared_settings,   $scope.original_data.shared_settings);
        angular.merge($scope.wifi_status,       $scope.original_data.wifi_status);
        angular.merge($scope.wps_enabled,       $scope.original_data.wps_enabled);
        angular.merge($scope.split_networks,    $scope.original_data.split_networks);
    }

    $scope.revertGuestNetworkChanges = function() {
        angular.merge($scope.guest_network, $scope.original_data.guest_network);
    }

    navService.isDirty(function() {
        var checks = ['main_network_2G', 'main_network_5G', 'eco', 'shared_settings', 'wifi_status', 'wps_enabled', 'split_networks', 'guest_network'];
        for(var i = 0; i < checks.length; i++) {
            if($scope.original_data[checks[i]] && $scope[checks[i]]) {
                if(angular.toJson($scope.original_data[checks[i]]) != angular.toJson($scope[checks[i]])) {
                    return true;
                }
            }
        }
        return false;
    });

    $scope.generate_password_for_guest = function(){
        $scope.generating_password = true;
        wifiService.generate_password_for_guest()
        .then(function(data) {
            return $timeout(function(){
                return wifiService.guest_network()
            }, 4000);
        }).then(function(data){
            $scope.guest_network = data;
            $scope.generating_password = false;

            $scope.original_data.guest_network = angular.merge({}, data);
        })
    }

}])

.controller('modalTriggerWPS',['wifiService','$log','$uibModalInstance','$scope','$timeout', function (wifiService, $log, $uibModalInstance, $scope, $timeout) {
    var ctrl = this,
        chkTimer = null;

    ctrl.is_timer_expired = false;

    ctrl.onTimerExpire = function() {
        ctrl.is_timer_expired = true;
        $scope.$apply();
    }

    function chkClientAssociation(){
        wifiService.wps_proc_status().then(function(status){
            if(status == 2){
                ctrl.has_client_assoc = true;
                ctrl.is_timer_expired = true;
            }

            if(!ctrl.is_timer_expired && chkTimer) {
                chkTimer = $timeout(chkClientAssociation, 2000);
            }
            else
                chkTimer = null;
        });
    }

    wifiService.trigger_wps().then(function(data) {
        chkTimer = $timeout(chkClientAssociation, 2000);
    });

    $scope.$on('modal.closing', function() {
        wifiService.cancel_wps_proc(); // June modify
        ctrl.is_timer_expired = true;
        if(chkTimer) {
            $timeout.cancel(chkTimer);
            chkTimer = null;
        }
    });

    ctrl.cancel = function(){
        $uibModalInstance.dismiss('cancel'); // this will fire 'modal.closing', so cancel_wps_proc() will be also called.
    };
}])

.controller('modalWifiWarnUserCtrl',['wifiService','$log','$uibModalInstance','$scope','$timeout', function (wifiService, $log, $uibModalInstance, $scope, $timeout) {
    var ctrl = this;
    ctrl.ok = function(){$uibModalInstance.close({confirm: true})};
    ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
}])

.controller('modalWifiRestartCtrl',['wifiService','$log','$uibModalInstance','$scope','$timeout', function (wifiService, $log, $uibModalInstance, $scope, $timeout) {
    var ctrl = this;
    ctrl.ok = function(){
        $scope.submitMainNetworkChanges().then(ctrl.close);
    };
    ctrl.close = function(){$uibModalInstance.dismiss('cancel');};
}])
;
