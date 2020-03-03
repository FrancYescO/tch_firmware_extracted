angular.module('fw')
    .controller('navCtrl', ['$translate', 'api','$scope','$rootScope', 'voiceService', '$timeout',  function($translate, api, $scope,$rootScope, voiceService, $timeout) {
        $scope.voice_available = false;
        $scope.showMenu = false;

        voiceService.get_voice_log_available().then(function(data){
            $scope.voice_available = (data == 1);
        });
        
        $scope.changeLang = function(lng) {
            lng = lng || ($translate.use() == 'it'? 'en' : 'it');
            $translate.use(lng);
            window.localStorage && localStorage.setItem("user_language", lng);
        };

        $scope.logout = function() {
            api.get('login_confirm', {cmd: 5}).then(function(data) {
                $rootScope.$broadcast('LOGOUT');
            });
        };
    }])
   // Widget LINE STATUS

   .controller('widgetLineStatusCtrl', ['$scope', 'lineService', 'fwHelpers', function($scope, lineService, fwHelpers) {
        
        $scope.speedLog_trigger = function() {
            $scope.isDataReady = false;
            lineService.speedLog_trigger().then(init);
        }        
        
        /* altrimenti vengono concatenate e non sommate */
        function sumSpeeds(a,b){return parseFloat(a)+parseFloat(b);}
        /* somma e converte */
        function byteToMBSum(a,b){return fwHelpers.byteToMB(parseFloat(a)+parseFloat(b));}
        /* Controlla se si tratta dello stesso giorno ignorando l'orario */
        function isSameDay(a,b){
            if(a === false || b === false) return false;
            return moment(a).format('yyyy-MM-DD') ===  moment(b).format('yyyy-MM-DD');
        }
        
        $scope.mode='week'; // June modify
        function init() {
            $scope.data = {day:[], week:[]};
            //$scope.mode = 'week';
            $scope.mode = $scope.mode; // June modify
            $scope.up_avg = {day:'--', week:'--'};
            $scope.down_avg = {day:'--', week:'--'};
            if(!$scope.filterHistory){
                $scope.filterHistory = {min: 0, max:0};
            }
            
            lineService.get_ip().then(function(res){
                $scope.current_ip = res;
            });
            
            var byteToMB = fwHelpers.byteToMB;
            lineService.speedLog_read().then(function(res){
                var speedLog = angular.merge([], res);
                var max = {day: 0, week: 0}, peak = {min: {day: 99999, week: 99999}, max: {day: 0, week: 0}}, up_avg = {day: 0, week: 0}, down_avg = {day: 0, week: 0};
                var tmp = {up: 0, down: 0, num: 0, pass: false};
                var now = moment();
                var avWCount = 0;
                $scope.max = {};
                
                // == DAY ==
                for (var i = 0; i < speedLog.length; i++) {
                    if(moment().format('yyyy-MM-DD') === moment(speedLog[i].date_info).format('yyyy-MM-DD')){ //  && $scope.data.day.length < 6 finchè c'è il break non è necessario
                        max.day = Math.max(max.day, speedLog[i].linerate_us, speedLog[i].linerate_ds);
                        
                        // Picchi giornalieri
                        peak.min.day = Math.min(peak.min.day, byteToMBSum(speedLog[i].linerate_us, speedLog[i].linerate_ds));
                        peak.max.day = Math.max(peak.max.day, byteToMBSum(speedLog[i].linerate_us, speedLog[i].linerate_ds));
                        
                        // Media
                        up_avg.day += parseFloat(speedLog[i].linerate_us); 
                        down_avg.day += parseFloat(speedLog[i].linerate_ds);
                        
                        $scope.data.day.push({
                            label:  moment(speedLog[i].date_info).format('HH:mm'),
                            vals: {up: byteToMB(speedLog[i].linerate_us), down: byteToMB(speedLog[i].linerate_ds), max: 300}
                        });
                    }
                }
                // Valore di fondo scala, viene arrotondato
                $scope.max.day = Math.ceil(byteToMB(max.day + 10) / 50) * 50;
                // Solo dopo aver raccolto tutti i giorni posso mettere true e false -> altro ciclo
                $scope.data.day.map(function(d){
                    d.vals.max = $scope.max.day;
                    d.vals.isMax = d.vals.up + d.vals.down === peak.max.day;
                    d.vals.isMin = d.vals.up + d.vals.down === peak.min.day;
                });
                // Media giornaliera
                if($scope.data.day.length > 0){
                    $scope.up_avg.day = Math.round(byteToMB(up_avg.day/$scope.data.day.length));
                    $scope.down_avg.day = Math.round(byteToMB(down_avg.day/$scope.data.day.length));
                }
                
                
                // == WEEK ==
                // Non ciclo i giorni presenti ma quelli effettivi
                for (var i = 0; i < 7; i++) {
                    // Vado a ritroso dalla data odierna
                    now = moment().add(-1*i, 'days');
                    
                    tmp = {up: 0, down: 0, num: 0, pass: false};
                    speedLog.map(function(aDate){
                        if(isSameDay(now, aDate.date_info)){
                            tmp.pass = true;
                            tmp.up = tmp.up + parseFloat(aDate.linerate_us);
                            tmp.down = tmp.down + parseFloat(aDate.linerate_ds);
                            tmp.num++;
                        }
                    });
                    
                    if(tmp.pass){
                        $scope.data.week.push({
                            label:  now.format('ddd').toUpperCase(), 
                            vals: {up: byteToMB(tmp.up/tmp.num), down: byteToMB(tmp.down/tmp.num), max: 300}
                        });
                        
                        max.week = Math.max(max.week, byteToMB(tmp.up/tmp.num), byteToMB(tmp.down/tmp.num)); 
                        peak.min.week = Math.min(peak.min.week, byteToMBSum(tmp.up/tmp.num, tmp.down/tmp.num));
                        peak.max.week = Math.max(peak.max.week, byteToMBSum(tmp.up/tmp.num, tmp.down/tmp.num));
                    } else {
                        $scope.data.week.push({
                            label:  now.format('ddd').toUpperCase(), 
                            vals: {up: -1, down: -1, max: 300}
                        });
                    }
                };
                for(var i = 0; i < res.length; i++){
                    if(i === 0){$scope.filterHistory.min = res[i].linerate_us;}
                    $scope.filterHistory.min = Math.min($scope.filterHistory.min, parseFloat(res[i].linerate_us), parseFloat(res[i].linerate_ds));
                    $scope.filterHistory.max = Math.max($scope.filterHistory.max, parseFloat(res[i].linerate_us), parseFloat(res[i].linerate_ds));
                }
                // Valore di fondo scala, viene arrotondato
                $scope.max.week = Math.ceil((max.week + 10) / 50) * 50;
                // Solo dopo aver raccolto tutti i giorni posso mettere true e false -> altro ciclo
                $scope.data.week.map(function(w){
                    if(w.vals.up < 0 || w.vals.down < 0) return;
                    w.vals.max = $scope.max.week;
                    w.vals.isMax = w.vals.up + w.vals.down === peak.max.week;
                    w.vals.isMin = w.vals.up + w.vals.down === peak.min.week;
                    up_avg.week += w.vals.up;
                    down_avg.week += w.vals.down;
                    avWCount++;
                });
                // Media settimanale
                if(avWCount > 0){
                    $scope.up_avg.week = Math.round(up_avg.week/avWCount);
                    $scope.down_avg.week = Math.round(down_avg.week/avWCount);
                }
                
                if($scope.line_status){
                    $scope.line_status.history = res; 
                }                
                $scope.isDataReady = true;
            });
        };
        init();

    }])
   // Widget LED STATUS
   .controller('widgetLedStatusCtrl',['$scope', 'modemService', '$rootScope', function($scope, modemService, $rootScope) {
        $scope.isDataReady = true;

        if(!$scope.status) {
            init();
        }

        function notifyRefresh(data) {
            var isCompleted = !!data;
            if($scope.isDataReady != isCompleted) {
                $scope.isDataReady = isCompleted;
                $rootScope.$broadcast('modem_refresh' + (isCompleted ? '' : '_start'), data);
            }
        }
        
        function init() {
            notifyRefresh();
            modemService.led_status().then(function(data){
                $scope.status = data;
                notifyRefresh(data);
            });
        }
        
        $scope.refresh = function() {
            notifyRefresh();
            modemService.led_status_refresh().then(init);
        }
    }])

   // Widget ONLINE DEVICES
   .controller('widgetOnlineDevicesCtrl', ['$scope','devicesService', function($scope, devicesService) {
        $scope.device_num = 0;
        $scope.device_family = 0;
        $scope.device_other = 0;

        $scope.filter = $scope.filter || {};
        $scope.filter.boost = true;
        $scope.filter.stop = true;

        if(!$scope.devices){
            devicesService.connected_devices().then(function(data){
                $scope.devices = $scope.devices || {};
                $scope.devices.online = data;
                init($scope.devices.online);
                $scope.isDataReadyOnline = true;
            });
        }
        else {
            $scope.$watch('devices.online | json', function(data){
                init($scope.devices.online);
            });
        }
        
        function init(data){
            $scope.device_num  = data.length;
            $scope.device_family = 0;
            $scope.device_other = 0;

            for(var i in data){
                if(data[i].family)
                    $scope.device_family++;
                else
                    $scope.device_other++;
            }
            
            $scope.paths = [
                {d: 'M 200, 220 m -180, 0 a 150,150 0 0,1 360,0', s: {'stroke': '#000000', 'stroke-width': 1, 'fill': 'none'}}
            ];
            $scope.icons = [];
            
            // Raggio fissato nel file svg
            var r = 180; 
            // Grad to rad
            function rad(alpha){ return alpha * (Math.PI / 180); };
            // Posizione x sulla circonferenza
            function getX(r, alpha){ return Math.round(r*Math.cos(rad(alpha))); };
            // Posizione y sulla circonferenza
            function getY(r, alpha){ return -1 * Math.round(r*Math.sin(rad(alpha))); };
            // Dimensione del tratto in gradi
            function getChunkAlpha(num){ return (180 - (num * 2) + 2 ) / num; };
            // Path del tratto dato un punto di partenza e un angolo
            function getChunk(alpha, startX, startY, ra){
                ra = ra || r;
                var newX = getX(ra, alpha);
                var newY = getY(ra, alpha);
                return {d: 'M 200, 220 m '+startX+', '+startY+' a 180,180 0 0,0 '+(newX - startX)+','+(newY - startY), x: newX, y: newY};
            };

            var startX = r;
            var startY = 0;
            var alpha = getChunkAlpha(data.length);
            var chunk = {x: r, y: 0};
            var iconPos = {x: r, y: 0};
            
            for(var i = data.length-1; i >= 0; i--){
                chunk = getChunk(alpha, chunk.x, chunk.y);
                $scope.paths.push({d: chunk.d, s: {'stroke': data[i].family? '#FFC10E' : '#FFFFFF', 'stroke-width': '10px', 'fill': 'none'}});
                
                if(data[i].boost){
                    iconPos = getChunk(alpha-(getChunkAlpha(data.length)/2), chunk.x, chunk.y, 150);
                    $scope.icons.push({src: 'css/img/rocket.svg', class: 'rocket', s: {left: iconPos.x+190+'px', bottom: 220-10+iconPos.y+'px'}});
                }
                if(data[i].stop){
                    iconPos = getChunk(alpha-(getChunkAlpha(data.length)/2), chunk.x, chunk.y, 150);
                    $scope.icons.push({src: 'css/img/halt.svg', class: 'stop', s: {left: iconPos.x+190+'px', bottom: 220-10+iconPos.y+'px'}});
                }
                
                alpha = alpha + 2;
                chunk.x = getX(r, alpha);
                chunk.y = getY(r, alpha);
                
                alpha = alpha + getChunkAlpha(data.length);
            }
        }

        
    }])
   // Widget WIFI Channel
   //.controller('widgetWifiChannelCtrl', ['$translate','$scope', function($translate, $scope) {
   .controller('widgetWifiChannelCtrl', ['lineService', '$translate','$scope', function(lineService, $translate, $scope) { // June modify
       
        $scope.data = {};
       
        $scope.$watch('wifi_channel_list', function(newValue, oldValue){
            $scope.data.freq2_4 = get_channel_list('freq2_4', newValue);
            $scope.data.freq5 = get_channel_list('freq5', newValue);
        });

        var get_channel_list = function(type, channel_list){
            var array = [];
           
            if(typeof channel_list != 'undefined' && typeof channel_list.channel_in_use_list != 'undefined'){                
                for (var i = 0; i <  channel_list.channel_in_use_list[type].length; i++) {
                    var obj = {label : channel_list.channel_in_use_list[type][i], vals : {num : 0, max : 7}, current : false};
                    for (var j = 0; j < channel_list[type].length; j++) {                        
                        if(channel_list[type][j][0].channel == channel_list.channel_in_use_list[type][i]){
                            obj.vals.num = channel_list[type][j].length; 
                            if(channel_list[type+'_in_use'] == channel_list[type][j][0].channel)  obj.current = true;                  
                        }                        
                    }
                    array.push(obj);                    
                }                
            }
            return array;
        }

        $scope.isChannelBusy = function () {
            if(!$scope.wifi_channel_list)
                return false;
            
            var ch = $scope.wifi_channel_list[$scope.commons.filter + '_channel_to_use'],
                data = $scope.data[$scope.commons.filter] || [];
            
            for(var i = 0; i<data.length; i++) {
                if(ch == data[i].label) {
                    return (data[i].vals.num > 2);
                }
            }
            return false;
        }   
        // June modify for wifi channel refresh start
        $scope.refresh_channel = function(){
            $scope.wifi.isDataReady = false;
            $scope.wifi.channelReady = false;
            lineService.wlssid_list(1).then(function(data){
                $scope.init_wifi_channel_settings();
            });
        }
        // June modify for wifi channel refresh end
    }])
   // Widget PARENTAL CONTROL
   .controller('widgetParentalControlCtrl', ['$scope', '$uibModal', 'advancedService', 'devicesService', function($scope, $uibModal, advancedService, devicesService) {
        $scope.parental = $scope.parental || {};
        function init() {
            advancedService.pc_list().then(function(data) {
                $scope.parental.parental_enabled = data.parental_enabled;
                $scope.parental.single_devices = data.single_devices;
                $scope.parental.blocks_list_uri = data.blocks_list_uri;
                $scope.parental.blocks_list_dev = data.blocks_list_dev;
                $scope.isDataReady = true;
            });
        }

        $scope.openAddDevices = function() {
            var modalInstance = $uibModal.open({
              templateUrl: 'views/modals/modal_add_parental_device.html',
              size: 'lg',
              controller: 'modalAddParentalControlDevCtrl',
              controllerAs: 'ctrl'
            });

            modalInstance.result.then(function(selectedItems) {
                $scope.isDataReady = false;
                advancedService.add_parental_devices(selectedItems).then(init);
            });
        };

        $scope.openRemoveDevices = function() {
            var modalInstance = $uibModal.open({
              templateUrl: 'views/modals/modal_remove_parental_device.html',
              size: 'lg',
              controller: 'modalRemoveParentalControlDevCtrl',
              controllerAs: 'ctrl'
            });

            modalInstance.result.then(function(selectedItems) {
                $scope.isDataReady = false;
                advancedService.remove_parental_devices(selectedItems).then(init);
            });
        };

        init();     
    }])

      .controller('modalAddParentalControlDevCtrl',['devicesService', '$uibModalInstance', '$filter', function (devicesService, $uibModalInstance, $filter) {
        var ctrl = this,
            filter = $filter('filter');

        ctrl.modes = ['AUTO', 'MANUAL'],
        ctrl.mode = ctrl.modes[0];

        devicesService.connected_devices().then(function(data){
            ctrl.devices = data;
            ctrl.isDataReady = true;
        });

        ctrl.ok = function(){
            var res = ctrl.mode == 'AUTO' ? filter(ctrl.devices, {selected: true}) : [{name: ctrl.manualHostName, mac: ctrl.manualHostMAC}];
            $uibModalInstance.close(res);
        };
        ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
    }])

   .controller('modalRemoveParentalControlDevCtrl',['advancedService', '$uibModalInstance', '$filter', function (advancedService, $uibModalInstance, $filter) {
        var $ctrl = this;

        advancedService.pc_list().then(function(data){
            $ctrl.devices = data.blocks_list_dev;
            $ctrl.isDataReady = true;
        });

        $ctrl.ok = function(){$uibModalInstance.close($filter('filter')($ctrl.devices, {selected: true}));};
        $ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
    }])

   // Widget FAMILY DEVICES
   .controller('widgetFamilyDevicesCtrl', ['devicesService', '$uibModal', '$scope', '$state', '$timeout', function(devicesService, $uibModal, $scope, $state, $timeout) {
        $scope.family_online = [];
        $scope.family_offline = [];

        function loadFamilyDevices() {
            devicesService.family_devices().then(function(data){
                $scope.devices = $scope.devices || {};
                $scope.devices.family = data;
                init();
                $scope.isDataReadyFamily = true;
            });
        }

        function init() {
            $scope.family_online = [];
            $scope.family_offline = [];
            $scope.family_boost = [];
            $scope.family_boost_count = 0;
            $scope.family_stop = [];
            $scope.family_stop_count = 0;

            for (var i = 0; i < $scope.devices.family.length; i++) {
                if($scope.devices.family[i].online == 1){
                    $scope.family_online.push($scope.devices.family[i]);
                } else {
                    $scope.family_offline.push($scope.devices.family[i]);
                }
                
                if($scope.devices.family[i].routine == 1){
                    if($scope.devices.family[i].boost_scheduled == 1){
                        $scope.family_boost.push($scope.devices.family[i]);
                    }
                    if($scope.devices.family[i].stop_scheduled == 1){
                        $scope.family_stop.push($scope.devices.family[i]);
                    }
                }
                $scope.family_boost_count = $scope.family_boost.length;
                $scope.family_stop_count = $scope.family_stop.length;
            }
        }

        if($scope.devices && $scope.devices.family && $scope.devices.family.length >= 0) {
            $scope.$watch('devices.family | json', function(data){
                init();
            });
        }
        else {
            loadFamilyDevices();
        }

        $scope.openAddDevices = function (cb) {
            cb = cb || function(){};
            var modalInstance = $uibModal.open({
                templateUrl: 'modal_add_family_device.html',
                size: 'lg',
                controller: 'modalAddFamilyDevCtrl',
                controllerAs: 'ctrl',
                resolve: {
                    dev_family: function() {
                        return $scope.devices.family;
                    }
                }
            });

            modalInstance.result.then(function(selectedItems) {
                devicesService.add_family_devices(selectedItems).then(function(res){
                    $state.reload().then(cb);
                });
            });
        };

        $scope.openRemoveDevices = function (cb) {
            cb = cb || function(){};
            var modalInstance = $uibModal.open({
              templateUrl: 'modal_remove_family_device.html',
              size: 'lg',
              controller: 'modalRemoveFamilyDevCtrl',
              controllerAs: 'ctrl'
            });

            modalInstance.result.then(function(selectedItems) {
                devicesService.remove_family_devices(selectedItems).then(function(res){
                    $state.reload().then(cb);
                });
            });
        };

    }])

   .controller('modalAddFamilyDevCtrl',['devicesService','$uibModalInstance','$filter','$q','dev_family', function(devicesService,$uibModalInstance,$filter,$q,dev_family) {
        var ctrl = this,
            filter = $filter('filter');

        ctrl.modes = ['ONLINE', 'OFFLINE'],
        ctrl.mode = ctrl.modes[0];
        ctrl.devices = {};

        $q.all([
            devicesService.connected_devices(),
            devicesService.device_history()
        ]).then(function(data){
            ctrl.devices.ONLINE = filter(data[0], {family: false});
            // we need to remove devices already in "family group"
            ctrl.devices.OFFLINE = filter(data[1], function(dev) {
                var isInFamily = false;
                angular.forEach(dev_family, function(fam){
                    isInFamily |= (dev.mac == fam.mac);
                });
                return !isInFamily;
            });
            // OFFLINE devices need to remove the ONLINE devices.
            ctrl.devices.OFFLINE = filter(ctrl.devices.OFFLINE, function(dev){
                var isOnlineDev = false;
                angular.forEach(ctrl.devices.ONLINE, function(online_dev){
                    isOnlineDev |= (dev.mac == online_dev.mac);
                });
                return !isOnlineDev;
            });
            ctrl.isDataReady = true;
        });

        ctrl.ok = function(){
            $uibModalInstance.close(filter(ctrl.devices[ctrl.mode], {selected: true}));
        };
        ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
    }])

   .controller('modalRemoveFamilyDevCtrl',['devicesService', '$uibModalInstance', '$filter', function (devicesService, $uibModalInstance, $filter) {
        var $ctrl = this;

        devicesService.family_devices().then(function(data){
            $ctrl.devices = data;
            $ctrl.isDataReady = true;
        });

        $ctrl.ok = function(){$uibModalInstance.close($filter('filter')($ctrl.devices, {selected: true}));};
        $ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
    }])
;

