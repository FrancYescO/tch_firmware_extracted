angular.module('fw')
// June modify
.controller('lineCtrl', ['$timeout', 'fwHelpers','$scope','$log','$q','lineService','$filter','navService',
  function($timeout, fwHelpers, $scope, $log, $q, lineService, $filter, navService) {

    $scope.commons = {filter : 'freq2_4'};
    $scope.line_status = {};
    $scope.filterHistoryTable = 'all';
    $scope.filterHistory = {min: 0, max:0};

    $scope.hours = [];
    for(var i = 0; i < 24; i++){
      for(var k = 0; k < 60; k += 30){
        $scope.hours.push( (i < 10 ? '0' : '') + i + (k < 10 ? '0' : '') + k);
      }
    }
    var auto_check_freq = [
        {code:'1' , name: 'FREQ_1'},
        {code:'6' , name: 'FREQ_6'}
    ];

    $scope.auto_checks = {
        enabled: false,
        freq: auto_check_freq,
        selected_freq: auto_check_freq[0],
        selected_time: '0000'
    }

    lineService.speedLog_schedule().then(function(data){
        $scope.auto_checks.enabled = data.enabled;
        $scope.auto_checks.selected_freq = $filter('filter')($scope.auto_checks.freq, {code: data.freq})[0];
        $scope.auto_checks.selected_time = data.time;

        $scope.auto_checks_orig = angular.merge({}, $scope.auto_checks);
    });

    $scope.badge = {max: 0, min: 0};

    $scope.byteToMB = fwHelpers.byteToMB;

    $scope.byteToMBString = function(byte){return fwHelpers.byteToMB(byte) + ' Mb/s';};

    $scope.applyFilter = function(value, filter){
        if(filter == 'all') return true;
        return $scope.filterHistory[filter] == Math[filter](parseFloat(value.linerate_us), parseFloat(value.linerate_ds));
    }

    var getBadge = function(history){
        var badge = {max:0, min:0};
        for (var i = 0; i < history.length; i++) {
            $scope.filterHistory.max == Math.max(parseFloat(history[i].linerate_us), parseFloat(history[i].linerate_ds)) && badge.max++;
            $scope.filterHistory.min == Math.min(parseFloat(history[i].linerate_us), parseFloat(history[i].linerate_ds)) && badge.min++;
        }
        return badge;
    }

    $scope.$watch('line_status.history', function(newValue){
        if(typeof newValue != 'undefined'){
            $scope.badge = getBadge(newValue);
        }
    });

    $scope.revert_speedLog_schedule = function(){
        $scope.auto_checks = angular.merge({}, $scope.auto_checks_orig);
    }

    $scope.save_speedLog_schedule = function(){
        $scope.saving_auto_checks = true;
        $scope.auto_checks_orig = angular.merge({}, $scope.auto_checks);
        lineService.speedLog_schedule($scope.auto_checks).then(function(data){
            $scope.saving_auto_checks = false;
        });
    }

    /* ----- CANALE WIFI -----*/
    $scope.search_channel = {
        freq2_4: false,
        freq5: false
    }


    $scope.bandwidth_list = {
        freq2_4 : [
            {id:'1' , name: '20 MHz',           value: '20MHz'},
            {id:'2' , name: '20-40 MHz',        value: '40MHz'}
        ],
        freq5 : [
            {id:'1' , name: '20 MHz',           value: '20MHz'},
            {id:'2' , name: '20-40 MHz',        value: '40MHz'},
            {id:'3' , name: '20-40-80 MHz',     value: '80MHz'}
            //Remove 160MHz due to not supported
            //{id:'4' , name: '20-40-80-160 MHz', value: '160MHz'}
        ]
    }

    $scope.init_freq5_band = {}

    $scope.init_wifi_channel_settings = function() { // June modify
        $q.all([lineService.getChannelInfo_5G(),
                lineService.getChannelInfo_2G(),
                lineService.wlssid_list(0), // June modify; 1=scan, 0=non-scan
                lineService.speedLog_schedule()
            ]).then(function(data) {
                $scope.search_channel.freq5 = data[0].auto_channel;
                //$scope.search_channel.freq5_band =  $filter('filter')($scope.bandwidth_list, {value: data[0].bandwidth})[0] || $scope.bandwidth_list[0];
                // June modify
                $scope.search_channel.freq5_band =  $filter('filter')($scope.bandwidth_list['freq5'], {value: data[0].bandwidth})[0] || $scope.bandwidth_list_freq5[0];

                $scope.init_freq5_band = $scope.search_channel.freq5_band

                $scope.search_channel.freq2_4 = data[1].auto_channel;
                //$scope.search_channel.freq2_4_band = $filter('filter')($scope.bandwidth_list, {value: data[1].bandwidth})[0] || $scope.bandwidth_list[0];
                // June modify
                $scope.search_channel.freq2_4_band = $filter('filter')($scope.bandwidth_list['freq2_4'], {value: data[1].bandwidth})[0] || $scope.bandwidth_list_freq2_4[0];

                $scope.wifi_channel_list = data[2];
                $scope.wifi_channel_list.channel_in_use_list = {
                    freq2_4 : lineService.twogchannel_list,
                    freq5 : lineService.fivegchannel_list["20MHz"]

                };
                $scope.wifi_channel_list.channel_band_list = {
                    freq2_4 : lineService.twogchannel_list,
                    freq5 : lineService.fivegchannel_list[$scope.search_channel.freq5_band.value]
                };
                $scope.wifi_channel_list.freq2_4_channel_to_use = $scope.wifi_channel_list.freq2_4_in_use;
                $scope.wifi_channel_list.freq5_channel_to_use = $scope.wifi_channel_list.freq5_in_use;
                $scope.wifi = $scope.wifi || {};
                $scope.wifi.isDataReady = true;
                $scope.wifi.channelReady = true; // June modify

                $scope.search_channel_orig = angular.merge({}, $scope.search_channel);
        });
    } // June modify
    $scope.init_wifi_channel_settings(); // June modify

    $scope.applyWifiChanges = function() {
        $scope.wifi.isDataReady = false;
        $scope.wifi.channelReady = false; // June modify
        return $q.all([
            lineService.setChannelInfo_5G({
                auto: $scope.search_channel.freq5,
                channel: $scope.wifi_channel_list.freq5_channel_to_use,
                bandwidth:  $scope.search_channel.freq5_band.value // please check values in $scope.bandwidth_list; we assumed (20MHz, 20+40MHz, 40+80MHz)
            }),
            lineService.setChannelInfo_2G({
                auto: $scope.search_channel.freq2_4,
                channel: $scope.wifi_channel_list.freq2_4_channel_to_use,
                bandwidth: $scope.search_channel.freq2_4_band.value // please check values in $scope.bandwidth_list; we assumed (20MHz, 20+40MHz, 40+80MHz)
            })])
        //.then(function(data){$scope.wifi.isDataReady = true;});
        // June modify start
        .then(function(data){
            return $timeout(function(){
                $q.all([
                    lineService.getChannelInfo_5G(),
                    lineService.getChannelInfo_2G(),
                    lineService.wlssid_list(0)
                ]).then(function(data){
                    $scope.wifi_channel_list = data[2];
                    $scope.wifi_channel_list.freq5_in_use = data[0].channel;
                    $scope.wifi_channel_list.freq5_channel_to_use = data[0].channel;
                    $scope.wifi_channel_list.freq2_4_in_use = data[1].channel;
                    $scope.wifi_channel_list.freq2_4_channel_to_use = data[1].channel;
                    $scope.wifi_channel_list.channel_in_use_list = {
                        freq2_4 : lineService.twogchannel_list,
                        freq5 : lineService.fivegchannel_list["20MHz"]
                    };
                    $scope.wifi_channel_list.channel_band_list = {
                        freq2_4 : lineService.twogchannel_list,
                        freq5 : lineService.fivegchannel_list[$scope.search_channel.freq5_band.value]
                    };
                    //$scope.wifi_channel_list.freq2_4_channel_to_use = $scope.wifi_channel_list.freq2_4_in_use;
                    //$scope.wifi_channel_list.freq5_channel_to_use = $scope.wifi_channel_list.freq5_in_use;
                    $scope.wifi = $scope.wifi || {};
                    $scope.wifi.isDataReady = true;
                    $scope.wifi.channelReady = true;

                    $scope.search_channel_orig = angular.merge({}, $scope.search_channel);
                });
            }, 20000);
        });
        // June modify end
    }

    $scope.changeChannelBand = function(filter, band) {
      $scope.search_channel[filter+'_band'] = band;
      if (filter == "freq5") {
        $scope.wifi_channel_list.channel_band_list["freq5"] = lineService.fivegchannel_list[band.value];
        $scope.wifi_channel_list.freq5 = $scope.wifi_channel_list["freq5_" + band.value];
        if (band.value == $scope.init_freq5_band.value) {
          $scope.wifi_channel_list.freq5_channel_to_use = $scope.wifi_channel_list.freq5_in_use
        } else {
          $scope.wifi_channel_list.freq5_channel_to_use = 36;
        }
      }
    }

    $scope.revert_search_channel_schedule = function() {
        $scope.wifi_channel_list.channel_in_use_list["freq5"] = lineService.fivegchannel_list["20MHz"];
        $scope.search_channel = angular.merge({}, $scope.search_channel_orig);
    }

    navService.isDirty(function(){
        var checks = ['auto_checks', 'search_channel'];
        for(var i = 0; i < checks.length; i++) {
            if($scope[checks[i]] && $scope[checks[i]+'_orig']) {
                if(angular.toJson($scope[checks[i]]) != angular.toJson($scope[checks[i]+'_orig'])) {
                    return true;
              }
            }
        }
        return false;
    });
}])
;
