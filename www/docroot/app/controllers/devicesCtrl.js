  /***************
    devicesController
  ****************/
angular.module('fw')
  .controller('devicesCtrl', ['$scope', 'devicesService', '$q', '$filter', 'navService', function($scope, devicesService, $q, $filter, navService) {
      var filter = $filter('filter');
      
      $scope.tabSelected = $scope.tabSelected || {c: false};
      $scope.selectFamilyTab = function(){
          $scope.tabSelected.c = true;
      };

      $scope.devices = {
          online: [],
          family: []
      };

      $scope.devices_orig ={
          family: [],
          others: [],
          offline: []
      };

      $scope.duration = [
          {id:'1800' , name: '0h 30\''},
          {id:'3600' , name: '1h 00\''},
          {id:'5400' , name: '1h 30\''},
          {id:'7200' , name: '2h 00\''},
          {id:'14400', name: '4h 00\''}
      ];

      $scope.days = [
          {id:'0000011' , name: 'PAGES.DEVICES.FAMILY_DEVICES.EDIT.WEEKEND'},
          {id:'1111100' , name: 'PAGES.DEVICES.FAMILY_DEVICES.EDIT.WORKING'},
          {id:'1111111' , name: 'PAGES.DEVICES.FAMILY_DEVICES.EDIT.EVERYDAY'}
      ];

      $scope.devices.default_boost = $scope.duration[2];
      $scope.devices.default_stop = $scope.duration[2];

      $scope.getDuration = function(time) {
        var d = filter($scope.duration, function(item){return item.id == time;})[0];
        return d ? d.name : $scope.duration[2].name;
      }

      $scope.getInvervalDays = function(mask) {
        var d = filter($scope.days, function(item){return item.id == mask;})[0];
        return d ? d.name : $scope.days[2].name;
      }

      $scope.hours = [];
      for(var i = 0; i < 24; i++){
        for(var k = 0; k < 60; k += 30){
          $scope.hours.push( (i < 10 ? '0' : '') + i +':' + (k < 10 ? '0' : '') + k);
        }
      }

      $scope.refreshFamilyDevices = function() {
        $scope.isDataReadyFamily = false;
        devicesService.family_devices().then(function(data){
          $scope.devices.family = data;
          $scope.isDataReadyFamily = true;

          $scope.devices.family_orig = angular.merge($scope.devices_orig.family ,$scope.devices.family);
        });
      }
      $scope.refreshFamilyDevices();
      

      $scope.setBoost = function(dev) {
        $scope.isDataReadyOnline = false;

        var boostedDevices = filter($scope.devices.online, {boost: true});
        var promises = [];

        if(boostedDevices.length > 3){
          for(var i=0; i<boostedDevices.length; i++){
            if(dev != boostedDevices[i]){
              boostedDevices[i].boost = false;
              promises.push(devicesService.stop_device(boostedDevices[i].mac, boostedDevices[i].stop, -1));
              break;
            }
          }
        }
        if(dev.stop){
          dev.stop = false;
          promises.push(devicesService.stop_device(dev.mac, dev.stop, -1));
        }

        var boost_time = $scope.devices.default_boost.id;
        $q.all(promises)
          .then(function(data){
            return devicesService.boost_device(dev.mac, dev.boost, boost_time);
          })
          .then(function(data){
            $scope.refreshOnlineDevices();
            dev.boost_remaining = Math.floor(boost_time/60);
            $scope.isDataReadyOnline = true;
        });
      };

      $scope.setStop = function(dev) {
        $scope.isDataReadyOnline = false;

        if(dev.boost){
          dev.boost = false;
          devicesService.boost_device(dev.mac, dev.boost, -1);
        }
        var stop_time = $scope.devices.default_stop.id;
        devicesService.stop_device(dev.mac, dev.stop, stop_time).then(function(data){
            $scope.refreshOnlineDevices();
            dev.stop_remaining = Math.floor(stop_time/60);
            $scope.isDataReadyOnline = true;
        });
      };

      $scope.updateFamilyDevice = function(dev) {

      // June modify start
        $scope.isDataReadyFamily=false;
        // June modify: if never configured start
        if(dev.boost_duration=="0") dev.boost_duration=$scope.duration[2].id;
        if(dev.boost_days=="0000000") dev.boost_days=$scope.days[2].id;
        if(dev.stop_duration=="0") dev.stop_duration=$scope.duration[2].id;
        if(dev.stop_days=="0000000") dev.stop_days=$scope.days[2].id;
        // June modify: if never configured end
        devicesService.update_family_device(dev).then(function(data){
          $q.all([
            devicesService.family_devices(),
            devicesService.connected_devices()
          ]).then(function(data){
            $scope.devices.family = data[0];
            $scope.devices.online = data[1];
            $scope.isDataReadyFamily=true;

            $scope.devices.family_orig = angular.merge($scope.devices_orig.family ,$scope.devices.family);
          });
        });
      // June modify end
      };
      
      $scope.devFamIsExpanded = {index: null};
      $scope.devOtherIsExpanded = {index: null};
      $scope.devOfflineIsExpanded = {index: null};

      $scope.setDevFamIsExpanded = function(d){
        $scope.devFamIsExpanded.index = $scope.devFamIsExpanded.index == d? null : d;
      }

      $scope.setDevOtherIsExpanded = function(d){
        $scope.devOfflineIsExpanded.index = null;
        $scope.devOtherIsExpanded.index = $scope.devOtherIsExpanded.index == d? null : d;
      }

      $scope.setDevOfflineIsExpanded = function(d){
        $scope.devOtherIsExpanded.index = null;
        $scope.devOfflineIsExpanded.index = $scope.devOfflineIsExpanded.index == d? null : d;
      }

      $scope.updateGenericDevice = function(dev) {
        $scope.isDataReadyOnline = false;
        devicesService.update_generic_device(dev).then(function(){
          $scope.isDataReadyOnline = true;
          $scope.refreshOnlineDevices();
        });
      }

      $scope.refreshOnlineDevices = function(){
        $scope.isDataReadyOnline = false;
        $q.all([
            devicesService.connected_devices(),
            devicesService.device_history()])
        .then(function(result){
            var online = result[0],
                history = result[1],
                offline = [],
                others = filter(online, function(item){return !item.family;});
            
            for (var i = 0; i < history.length; i++) {         
              var found = false;
              angular.forEach(online, function(item) {            
                item.mac == history[i].mac && (found = true);
              });
              found || offline.push(history[i]);
            }            
            $scope.devices.online = online;
            $scope.devices.others = others;
            $scope.devices.offline = offline;
            $scope.isDataReadyOnline = true;

            $scope.devices.others_orig = angular.merge($scope.devices_orig.others, $scope.devices.others);
            $scope.devices.offline_orig = angular.merge($scope.devices_orig.offline, $scope.devices.offline);
        }); 
      }

      $scope.refreshOnlineDevices();

      navService.isDirty(function() {
          var checks = ['family', 'others', 'offline'];
          for(var i = 0; i < checks.length; i++) {
              if($scope.devices[checks[i]] && $scope.devices[checks[i]+'_orig']) {
                  if(angular.toJson($scope.devices[checks[i]]) != angular.toJson($scope.devices[checks[i]+'_orig'])) {
                      return true;
                  }
              }
          }
          return false;
      });

  }])
;
