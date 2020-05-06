angular.module('fw').controller('advancedCtrl', ['$timeout','$scope','$q','advancedService','$uibModal','$state','$filter','PortForwardingConf','navService',
    function($timeout, $scope, $q, advancedService, $uibModal, $state, $filter, PortForwardingConf, navService) {
    // Parental
    $scope.parental = {};

    var filter = $filter('filter');

    $scope.init_parental_status = function(){
        advancedService.pc_list().then(function(data){
            $scope.parental.parental_enabled = data.parental_enabled;
            $scope.parental.single_devices = data.single_devices;
            $scope.parental.blocks_list_uri = data.blocks_list_uri;
            $scope.parental.blocks_list_dev = data.blocks_list_dev;

            $scope.parental_orig = angular.merge({}, $scope.parental);
            $scope.pc_dataReady=true;
        });
    };

    $scope.portMappingIsExpanded = {index: null};
    $scope.setPortMappingIsExpanded = function(d){
        $scope.portMappingIsExpanded.index = $scope.portMappingIsExpanded.index == d? null : d;
    };

    $scope.openParentalAddUrl = function() {
      var modalInstance = $uibModal.open({
        templateUrl: 'views/modals/modal_parental_add_url.html',
        controller: 'modalAddParentalUrlCtrl',
        controllerAs: 'ctrl'
      });

      modalInstance.result.then(function(uri) {
        // this is to avoid duplicate uri:
        var prevItem = filter($scope.parental.blocks_list_uri, {url: uri})[0];

        if(prevItem != null) {
            prevItem.active = true;
        }
        else {
          $scope.parental.blocks_list_uri.push({
              url: uri,
              active: true
          });
        }
      });
    };

    $scope.deleteParentalUrl = function(item) {
        var bl = $scope.parental.blocks_list_uri,
            idx = bl.indexOf(item);

        if(idx >= 0)
            bl.splice(idx, 1);
    };

    $scope.revertParentalStatus = function() {
        angular.merge($scope.parental, $scope.parental_orig);
    };

    $scope.updateParentalChanges = function() {
        $scope.pc_dataReady=false; // June modify
        var promises = [],
            vm = $scope.parental,
            old = $scope.parental_orig;

        // update parental status
        promises.push(advancedService.set_parental_status(vm.parental_enabled, vm.single_devices));

        // update changed / newly added values
        angular.forEach(vm.blocks_list_uri, function(item, key){
            var oldItem = filter(old.blocks_list_uri, {url: item.url})[0];
            if(!oldItem || oldItem.active != item.active) {
                promises.push(advancedService.add_pc_url(item.url, item.active));
            }
        });

        // remove deleted items
        angular.forEach(old.blocks_list_uri, function(oldItem, key){
            var newItem = filter(vm.blocks_list_uri, {url: oldItem.url})[0];
            if(!newItem) {
                promises.push(advancedService.remove_pc_url(oldItem.url));
            }
        });

        $scope.parental_orig = angular.merge({}, $scope.parental);
        $timeout($scope.init_parental_status, 2000); // June modify
    }
    $scope.init_parental_status();


    /*   Restrictions  */
    $scope.restrict = {};
    $scope.init_restrictions_status = function(){
        advancedService.get_restrictions().then(function(data){
            $scope.restrict = data;
            $scope.restrict_orig = angular.merge({}, $scope.restrict);
            $scope.rs_dataReady=true; // June modify
        });
    };

    //open modal in order to add devices to the block list
    $scope.openRestrictionsAddDevices = function () {
        var modalInstance = $uibModal.open({
          templateUrl: 'views/modals/modal_restrictions_add_device.html',
          size: 'lg',
          controller: 'modalAddRestrictionsDevCtrl',
          controllerAs: 'ctrl'
        });

        modalInstance.result.then(function(selectedItems) {
          for (var i = 0; i < selectedItems.length; i++) {
            selectedItems[i].restrict_action = 'add';
            selectedItems[i].active = true;
            $scope.restrict.devices.push(selectedItems[i]);
          }

          $scope.rs_dataReady=false; // June modify
          $scope.update_restrictions($scope.restrict);
        });
    };

    $scope.update_restrictions = function(devices){
        $scope.rs_dataReady=false; // June modify
        advancedService.set_restrictions(devices).then(function(ret){
            return $timeout(function(){
                advancedService.set_bl_behavior(devices.behaviour);
                $timeout($scope.init_restrictions_status, 5000);
            }, 1000);
        });
    }

    $scope.delete_device = function(mac){
        for (var i = 0; i < $scope.restrict.devices.length; i++) {
            if( mac == $scope.restrict.devices[i].mac ) {
              if(!$scope.restrict.devices[i].restrict_action || $scope.restrict.devices[i].restrict_action != 'add') $scope.restrict.devices[i].restrict_action = 'delete';
              if($scope.restrict.devices[i].restrict_action && $scope.restrict.devices[i].restrict_action == 'add') $scope.restrict.devices[i].restrict_action = 'none';
            }
        }
        advancedService.del_bl_res(mac); // June modify
        $scope.rs_dataReady=false; // June modify
        $timeout($scope.init_restrictions_status, 5000); // June modify
    }

    $scope.revertRestrictions = function(){
        $scope.restrict = angular.merge({}, $scope.restrict_orig);
    }

    $scope.init_restrictions_status();

/*  Simple port configuration (SPC) */


    $scope.init_spc = function() {
        $scope.spc_dataReady = false;

        $q.all([
          advancedService.virtual_server_list(),
          advancedService.upnp_status()
        ])
        .then(function(data) {

          /* We need to group rules based on IP and service_code, because some services requires more then one rule */

          var vs_list = data[0],
              upnp_stat = data[1],
              consoles_start_rule  = PortForwardingConf.consoles_codes.start,
              consoles_end_rule    = PortForwardingConf.consoles_codes.end,
              services_start_rule  = PortForwardingConf.services_codes.start,

              consoles_map = {},
              services_map = {},

              consoles = [],
              services = [];

          for(var i = 0; i< vs_list.length; i++) {
            var item = vs_list[i],
                map = (item.code >= consoles_start_rule && item.code <= consoles_end_rule) ? consoles_map : ((item.code >= services_start_rule) ? services_map : null);

            if(map){
              var key = item.ip+'-'+item.code;
              map[key] = map[key] || [];
              map[key].push(item);
            }
          }

          angular.forEach(consoles_map, function(value, key){
            consoles.push({
              name: value[0].descr,       // description is the same for each rule
              hostname: value[0].hostname, // June modify
              ip: value[0].ip,
              active: value[0].enabled,
              rules: value
            });
          });

          angular.forEach(services_map, function(value, key){
            services.push({
              name: value[0].descr,
              hostname: value[0].hostname, // June modify
              ip:  value[0].ip,
              active: value[0].enabled,
              rules: value
            });
          });

          $scope.spc = {
                upnp: upnp_stat.enabled,
                upnp_details: upnp_stat.rules,
                consoles: consoles,
                services: services
            }

            $scope.spc_orig = angular.merge({}, $scope.spc);
            $scope.spc_dataReady = true;
        });
    }

    $scope.revert_spc = function() {
        $scope.spc = angular.merge({}, $scope.spc_orig);
    }

    $scope.update_upnp_status = function() {
      $scope.spc_dataReady = false;
      advancedService.upnp_update_status($scope.spc.upnp).then(function(){
        return advancedService.upnp_status();
      }).then(function(data){
        $scope.spc.upnp = data.enabled;
        $scope.spc.upnp_details = data.rules;
        $scope.spc_dataReady = true;
      });

      $scope.spc_orig = angular.merge({}, $scope.spc);
    }

    $scope.removeSpcRule = function(ruleset, type) {
      var old_rules = [];

      for(var i = 0; i < ruleset.rules.length; i++) {
        old_rules.push(ruleset.rules[i].id);
      }

      $scope.spc_dataReady = false;

      advancedService.virtual_server_del(old_rules).then(function(){
        $scope.spc[type].splice($scope.spc[type].indexOf(ruleset), 1);
        // just wait 4 seconds then reload rules to have the correct id
        $timeout($scope.init_spc, 4000);
      });

    }

    $scope.updateSpcRuleStatus = function(ruleset) {
      $scope.spc_dataReady = false;

      var rules = {
        total_num:  ruleset.rules.length
      }

      for(var i = 0; i < ruleset.rules.length; i++) {
        rules['id_'+i] = ruleset.rules[i].id;
        rules['enabled_'+i] =            ruleset.active;
        rules['descr_' + i] =            ruleset.rules[i].descr;
        rules['ext_port_start_' + i] =   ruleset.rules[i].ext_port_start;
        rules['ext_port_end_' + i] =     ruleset.rules[i].ext_port_end;
        rules['int_port_start_' + i] =   ruleset.rules[i].int_port_start;
        rules['proto_' + i] =            ruleset.rules[i].proto;
        rules['ip_' + i] =               ruleset.rules[i].ip;
      }

      advancedService.virtual_server_set(rules).then(function(){
        //$scope.spc_dataReady = true;
        // just wait 4 seconds then reload rules to have the correct id
        $timeout($scope.init_spc, 4000);
      });
    }

    /*
      Open a modal dialog allowing user to add SPC rules for consoles / services
      The parameter "type" can be 'consoles' or 'services'
    */
    $scope.openSpcModalAddRule = function(type) {
      var modalInstance = $uibModal.open({
          templateUrl: 'views/modals/modal_add_spc_rule.html',
          size: 'lg',
          controller: 'modalSpcAddRuleCtrl',
          controllerAs: 'ctrl',
          resolve: {
            typeOfRules: function(){
              return type;
            }
          }
        });

        modalInstance.result.then(function(res) {
          $scope.spc_dataReady = false;

            var rule = {
              svc_code:   res.ruleset.code,
              total_num:  res.ruleset.rules.length
            }

          for(var i = 0; i < res.ruleset.rules.length; i++) {
            var rule_conf = res.ruleset.rules[i];
            rule['enabled_' + i] =          '1';
            rule['descr_' + i] =            res.ruleset.name;
            rule['ext_port_start_' + i] =   rule_conf.port_start;
            rule['ext_port_end_' + i] =     rule_conf.port_end;
            rule['int_port_start_' + i] =   rule_conf.port_start;
            rule['proto_' + i] =            rule_conf.proto;
            rule['ip_' + i] =               res.ip;
          }

          // June modify start: can not add same services or consoles.
          var console_rule_exist=false, service_rule_exist=false;
          for(var i=0; i<$scope.spc.consoles.length; i++){
              if($scope.spc.consoles[i].name == res.ruleset.name)
                  console_rule_exist=true;
          }
          for(var i=0; i<$scope.spc.services.length; i++){
              if($scope.spc.services[i].name == res.ruleset.name)
                  service_rule_exist=true;
          }
          if(console_rule_exist || service_rule_exist){
              $scope.init_spc();
              return;
          }
          // June modify end: can not add same rule for the same IP.
          advancedService.virtual_server_set(rule).then(function(){
            // just wait 4 seconds then reload rules to have the correct id
            $timeout($scope.init_spc, 4000);
          });

        });
    }
    $scope.init_spc();

    /*   MANUAL PORT SETTINGS */
    $scope.mpc = {dmz:{}, mapping:[]};
    $scope.mpc_orig = angular.merge({}, $scope.mpc);
    $scope.port_range = {min:1, max:65535};


    $scope.init_port_settings = function() {
      $scope.mpc_dataReady = false;
      advancedService.firewall_conf().then(function(firewall_conf_data) {
          $q.all([
            advancedService.dmz_conf(),
            advancedService.virtual_server_list()
          ]).then(function(data) {

            $scope.mpc = firewall_conf_data;
            $scope.mpc.level_list = ['1','2'];
            $scope.mpc_orig = angular.merge({}, $scope.mpc);

            $scope.mpc.dmz = data[0];
            $scope.mpc_orig.dmz = angular.merge({}, $scope.mpc.dmz);

            $scope.mpc.mapping = filter(data[1], {code:'0'});
            $scope.mpc_orig.mapping = angular.merge([], $scope.mpc.mapping);

            $scope.mpc_dataReady = true;
          });
      });
    }

    $scope.dmzcfg_valid = function(){
      if ($scope.mpc.dmz.server != undefined) {
        if ($scope.mpc.dmz.server == $scope.lan.ip ||
           $scope.lan.ip.split(".")[0]!=$scope.mpc.dmz.server.split(".")[0] ||
           $scope.lan.ip.split(".")[1]!=$scope.mpc.dmz.server.split(".")[1] ||
           $scope.lan.ip.split(".")[2]!=$scope.mpc.dmz.server.split(".")[2]) {
          return false
        }
      }
      return true;
    }

    //open modal in order to add manual rules
    $scope.openPortSettingsAddPortMapping = function () {
        var modalInstance = $uibModal.open({
          templateUrl: 'views/modals/modal_add_port_mapping.html',
          size: 'lg',
          controller: 'modalPortSettingsAddPortMappingCtrl',
          controllerAs: 'ctrl',
          scope: $scope
        });

        modalInstance.result.then(function(selectedItem) {
          selectedItem.enabled = '1';
          selectedItem.svc_code = '0';
          $scope.mpc.mapping.push(selectedItem);
        });
    };

    $scope.port_mapping_delete = function(item){
        var bl = $scope.mpc.mapping,
            idx = bl.indexOf(item);

        if(idx >= 0)
            bl.splice(idx, 1);
    };

    $scope.update_port_settings = function(mpc){
      $scope.mpc_dataReady = false;

      var promises = [],
          vm = $scope.mpc,
          old = $scope.mpc_orig,
          rules_to_update = {svc_code: 0},
          rules_to_delete = [];

      //update firewall
      promises.push(advancedService.set_firewall_conf(vm));
      //update dmz
      promises.push(advancedService.set_dmz_conf(vm.dmz));

      var idx = 0;

      // update changed / newly added values
      angular.forEach(vm.mapping, function(item, key) {
          var oldItem = filter(old.mapping, {id: item.id || 0}, true)[0];

          if(item.id){
            rules_to_update['id_' + idx] =               item.id;
          }
          rules_to_update['enabled_' + idx] =          item.enabled;
          rules_to_update['descr_' + idx] =            item.descr;
          rules_to_update['ext_port_start_' + idx] =   item.ext_port_start;
          rules_to_update['ext_port_end_' + idx] =     item.ext_port_end;
          rules_to_update['int_port_start_' + idx] =   item.int_port_start;
          rules_to_update['proto_' + idx] =            item.proto;
          rules_to_update['ip_' + idx] =               item.ip;

          idx++;
          item.isModified = false;
      });

      rules_to_update.total_num = idx;

      // remove deleted items
      angular.forEach(old.mapping, function(oldItem, key) {
          if(!filter(vm.mapping, {id: oldItem.id})[0]) {
            rules_to_delete.push(oldItem.id.toString());
          }
      });

      $q.all(promises).then(function() {
        advancedService.virtual_server_set(rules_to_update);

        if(rules_to_delete.length > 0) {
          advancedService.virtual_server_del(rules_to_delete);
        }
      });

      $timeout($scope.init_port_settings, 4000);
    };

    $scope.port_settings_cancel = function(){
        $scope.mpc = angular.merge({}, $scope.mpc_orig);
    };

    $scope.getPortMappingEndPort = function(pm){
      if(pm.int_port_start > 0 && pm.ext_port_end > 0 && pm.ext_port_start) {
        var res = pm.int_port_start + (pm.ext_port_end - pm.ext_port_start);
        return res > 0 ? res : null;
      }
      return null;
    };

// June modify start: auto fill internal start port which is copied from external start port
    $scope.autoFillIntPort = function(pm){
        pm.int_port_start=pm.ext_port_start;
    };

    $scope.isReservedPort = function(pm) {
      var reservedPorts = [30006, 5060, 23];

      for(var i = 0; i<reservedPorts.length; i++) {
        if(pm.ext_port_start == reservedPorts[i] ||
           pm.ext_port_end == reservedPorts[i] ||
          (pm.ext_port_start <=  reservedPorts[i] && pm.ext_port_end >= reservedPorts[i]) ||
           pm.int_port_start == reservedPorts[i]) {
            return true;
        }
      }
      return false;
    }

    $scope.checkPortValid = function(expandIndex){
        if(expandIndex!=null) {
          return !$scope.isReservedPort($scope.mpc.mapping[expandIndex]);
        }
        return true;
    };

    $scope.checkPortValidAll = function(){
      if($scope.mpc.mapping) {
        for(var i = 0; i < $scope.mpc.mapping.length; i++) {
            if($scope.isReservedPort($scope.mpc.mapping[i]))
              return false;
        }
      }
      return true;
    };

    $scope.checkPortRangeAll = function(){
        // if ext port is range, the int port range should be same as ext port range value. [500-600, 500-600]
        // if [500-600, 550-660], it can not save.
        if($scope.mpc.mapping){
            for(var i=0; i<$scope.mpc.mapping.length; i++){
                var pm=$scope.mpc.mapping[i];
                if(pm.ext_port_end-pm.ext_port_start!=0){
                    if(pm.int_port_start!=pm.ext_port_start){
                        return false;
                    }
                }
            }
        }
        return true;
    };

    $scope.init_port_settings();

    // USB CONFIGURATION
    $scope.init_usb_status = function(){
      advancedService.get_usb_status().then(function(data){
        $scope.usb = data;
        $scope.usb_orig = angular.merge({}, $scope.usb);
        $scope.usb_dataReady=true; // June modify
        $scope.mobile_dataReady=true;
      });
    };

    $scope.revert_usb_status = function(){
      $scope.usb = angular.merge({}, $scope.usb_orig);
    };

    $scope.update_usb_status = function(){
      $scope.usb_dataReady=false; // June modify
      advancedService.set_usb_status($scope.usb).then(function(data){
          $scope.init_usb_status(); // June modify

      });
    };
    $scope.connect_to_mobile_data = function(){
      $scope.usb.connecting = true;
      $scope.mobile_dataReady=false;
      advancedService.enable_3g($scope.usb)
        .then(function(data){
          return $timeout(function(){
            return advancedService.get_usb_status().then(function(){
              $scope.usb.connecting = false;
              $scope.usb_orig['3g_connection_status'] = $scope.usb['3g_connection_status'] = data['3g_connection_status'];
              $scope.init_usb_status();
            });
          }, 5000);
        });
    };

    $scope.umount_usb_device = function(disk){
      $scope.usb.umounting = true; // disable button in UI

      //advancedService.umount_usb_device(disk.disk_id).then(function(){
      advancedService.umount_usb_device(disk).then(function(){ // June modify

        $scope.usb.disks.splice($scope.usb.disks.indexOf(disk), 1);
        //this will affect original data too:
        $scope.usb_orig.disks.splice($scope.usb_orig.disks.indexOf(disk), 1);
        $scope.usb.umounting = false; // enable button in UI
      });
    };

// June modify for samba password start
    var regex = [
        "[A-Z]",        //Uppercase Alphabet.
        "[a-z]",        //Lowercase Alphabet.
        "[0-9]",        //Digit.
        "[$@$!%*#?&]"   //Special Character.
    ];

    $scope.calSmbPwdStrength = function(pwd) {
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
// June modify end

    $scope.init_usb_status();


    /*   LAN CONFIGURATION  */
    $scope.lan = {};
    $scope.init_lan_status = function(){
        advancedService.lan_status().then(function(data){
            $scope.lan = data;
            $scope.lan.validity_options = [1, 2, 6, 8, 12, 24, 48]
            $scope.lan_orig = angular.merge({}, $scope.lan);
            $scope.lan_dataReady=true; // June modify
            // June modify for static DHCP list limitation start
            if($scope.lan.DHCP_list.length>=64)
                $scope.addDHCPbtn_disabled=true;
            else
                $scope.addDHCPbtn_disabled=false;
            // June modify for static DHCP list limitation end
        });
    };

    $scope.getLanStatusDHCPDuration = function(seconds){return parseInt(seconds) / 3600 };

    //apertura modale
    $scope.openLanStatusAddDHCP = function () {
        var modalInstance = $uibModal.open({
          templateUrl: 'views/modals/modal_lan_status_add_dhcp.html',
          size: 'lg',
          controller: 'modalAddLanStatusDHCPCtrl',
          controllerAs: 'ctrl'
        });

        modalInstance.result.then(function(selectedItems) {

            for (var i = 0; i < selectedItems.length; i++) {
                selectedItems[i].restrict_action = 'add';
                selectedItems[i].active = true;
                $scope.lan.DHCP_list.push(selectedItems[i]);
            }

            $scope.lan_dataReady=false; // June modify
            $timeout($scope.init_lan_status, 1000); // June modify
        });
    };

    $scope.deleteLanStatusDHCP = function(mac){
        for (var i = 0; i < $scope.lan.DHCP_list.length; i++) {
            if( mac == $scope.lan.DHCP_list[i].mac ) {
              if(!$scope.lan.DHCP_list[i].restrict_action || $scope.lan.DHCP_list[i].restrict_action != 'add') $scope.lan.DHCP_list[i].restrict_action = 'delete';
              if($scope.lan.DHCP_list[i].restrict_action && $scope.lan.DHCP_list[i].restrict_action == 'add') $scope.lan.DHCP_list[i].restrict_action = 'none';
            }
        }
        advancedService.del_dhcp_res(mac); // June modify
        $scope.lan_dataReady=false; // June modify
        $timeout($scope.init_lan_status, 1000); // June modify
    }

    $scope.revertLanStatus = function(){
        $scope.lan = angular.merge({}, $scope.lan_orig);
    }

    $scope.update_lan_status = function(lan_status){
        $scope.lan_dataReady=false; // June modify

        advancedService.set_lan_status(lan_status).then(function(res){
            $timeout($scope.init_lan_status, 15000);
        });
    }

    // June modify start
    // form validation
    $scope.lancfg_valid = function(){
        if($scope.lan.ip!==undefined && $scope.lan.DHCP.start!==undefined && $scope.lan.DHCP.end!==undefined){
            if($scope.lan.ip.split(".")[3]=="0" || $scope.lan.ip.split(".")[3]=="255"){
                return false;
            }
            if($scope.lan.DHCP.start == $scope.lan.ip || $scope.lan.DHCP.end == $scope.lan.ip || // DHCP lease IP is same as LAN IP.
               // subnet is not the same.
               $scope.lan.ip.split(".")[0]!=$scope.lan.DHCP.start.split(".")[0] ||
               $scope.lan.ip.split(".")[1]!=$scope.lan.DHCP.start.split(".")[1] ||
               $scope.lan.ip.split(".")[2]!=$scope.lan.DHCP.start.split(".")[2] ||
               $scope.lan.ip.split(".")[0]!=$scope.lan.DHCP.end.split(".")[0] ||
               $scope.lan.ip.split(".")[1]!=$scope.lan.DHCP.end.split(".")[1] ||
               $scope.lan.ip.split(".")[2]!=$scope.lan.DHCP.end.split(".")[2] ||
               // DHCP lease Start is bigger then End
               parseInt($scope.lan.DHCP.start.split(".")[3])>parseInt($scope.lan.DHCP.end.split(".")[3]) ||
               $scope.lan.DHCP.start.split(".")[3]=="0" || $scope.lan.DHCP.end.split(".")[3]=="0" ||
               $scope.lan.DHCP.start.split(".")[3]=="255" || $scope.lan.DHCP.end.split(".")[3]=="255")
            {
                return false;
            }else{
                return true;
            }
        }else{
            return true;
        }
    }
    // June modify end

    $scope.init_lan_status();

    navService.isDirty(function() {
      var checks = ['parental', 'restrict', 'spc', 'mpc', 'usb', 'lan'];
      for(var i = 0; i < checks.length; i++) {
        if($scope[checks[i]] && $scope[checks[i]+'_orig']) {
          if(angular.toJson($scope[checks[i]]) != angular.toJson($scope[checks[i]+'_orig'])) {
              return true;
          }
        }
      }
      return false;
    });


    /* Apertura modale copiata dal widget */
    $scope.openAddDevices = function() {
        var modalInstance = $uibModal.open({
          templateUrl: 'views/modals/modal_add_parental_device.html',
          size: 'lg',
          controller: 'modalAddParentalControlDevCtrl',
          controllerAs: 'ctrl'
        });

        modalInstance.result.then(function(selectedItems) {
            advancedService.add_parental_devices(selectedItems).then(init);
        });
    };
    /* Apertura modale copiata dal widget */
    $scope.openRemoveDevices = function() {
        var modalInstance = $uibModal.open({
          templateUrl: 'views/modals/modal_remove_parental_device.html',
          size: 'lg',
          controller: 'modalRemoveParentalControlDevCtrl',
          controllerAs: 'ctrl'
        });

        modalInstance.result.then(function(selectedItems) {
            advancedService.remove_parental_devices(selectedItems).then(init);
        });
    };
}])

    .controller('modalAddRestrictionsDevCtrl',['advancedService', 'devicesService', '$uibModalInstance', '$filter', function (advancedService, devicesService, $uibModalInstance, $filter) {
        var ctrl = this,
            filter = $filter('filter');

        ctrl.modes = ['AUTO', 'MANUAL'],
        ctrl.mode = ctrl.modes[0];

        devicesService.connected_devices().then(function(data){
            ctrl.devices = data;
            ctrl.isDataReady = true;
        });


        ctrl.ok = function(){
            //var res = ctrl.mode == 'AUTO' ? filter(ctrl.devices, {selected: true}) : [{name: ctrl.manualHostName, mac: ctrl.manualHostMAC}];
            var res = ctrl.mode == 'AUTO' ? ctrl.selected : {name: ctrl.manualHostName, mac: ctrl.manualHostMAC}; // June modify
            $uibModalInstance.close(res);
            advancedService.add_bl_res(res); // June modify
        };
        ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
    }])

    .controller('modalAddParentalUrlCtrl',['$uibModalInstance', function ($uibModalInstance) {
        var ctrl = this;
        ctrl.url = '';

        ctrl.ok = function(){
            $uibModalInstance.close(ctrl.url);
        };
        ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
    }])

    .controller('modalAddLanStatusDHCPCtrl',['advancedService', 'devicesService', '$uibModalInstance', '$filter', function (advancedService, devicesService, $uibModalInstance, $filter) {
        var ctrl = this,
            filter = $filter('filter');

        ctrl.modes = ['AUTO', 'MANUAL'],
        ctrl.mode = ctrl.modes[0];

        devicesService.connected_devices().then(function(data){
            ctrl.devices = data;
            ctrl.isDataReady = true;
        });


        ctrl.ok = function(){
            //var res = ctrl.mode == 'AUTO' ? filter(ctrl.devices, {selected: true}) : [{ip: ctrl.manualIP, mac: ctrl.manualHostMAC}];
            var res = ctrl.mode == 'AUTO' ? ctrl.selected : {ip: ctrl.manualIP, mac: ctrl.manualHostMAC}; // June modify
            $uibModalInstance.close(res);
            advancedService.add_dhcp_res(res); // June modify
        };
        ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};

        advancedService.lan_status().then(function(data){
            ctrl.lan_config=data;
        });

        ctrl.validIP = function(){
            var ip1, ip2, ip3, ip4;
            var lan_ip1, lan_ip2, lan_ip3, lan_ip4;
            if(ctrl.manualIP!==undefined && ctrl.lan_config.ip!==undefined){
                ip1=ctrl.manualIP.split(".")[0];
                ip2=ctrl.manualIP.split(".")[1];
                ip3=ctrl.manualIP.split(".")[2];
                ip4=ctrl.manualIP.split(".")[3];
                lan_ip1=ctrl.lan_config.ip.split(".")[0];
                lan_ip2=ctrl.lan_config.ip.split(".")[1];
                lan_ip3=ctrl.lan_config.ip.split(".")[2];
                lan_ip4=ctrl.lan_config.ip.split(".")[3];
                if(ip1!=lan_ip1 || ip2!=lan_ip2 || ip3!=lan_ip3 || ip4=="0" || ip4=="255" || ip4==lan_ip4){
                    // if not in the same subnet, or is same as lanip
                    return false;
                }else{
                    return true;
                }
            }else{
                return false;
            }
        };
        // June modify end
    }])

    .controller('modalPortSettingsAddPortMappingCtrl',['$uibModalInstance','$scope', function ($uibModalInstance, $scope) {
        var ctrl = this;
        ctrl.port_range = {min:1, max:65535};
        ctrl.port_mapping = {};
        ctrl.port_mapping.proto = 'TCP';

        ctrl.isConflicting = function(){
          for(var i = 0; i < $scope.mpc.mapping.length; i++) {
            var pm = $scope.mpc.mapping[i];
            if (ctrl.port_mapping.proto == pm.proto && (
                ctrl.port_mapping.ext_port_start == pm.ext_port_start || ctrl.port_mapping.ext_port_start == pm.ext_port_end ||
                ctrl.port_mapping.ext_port_end == pm.ext_port_start || ctrl.port_mapping.ext_port_end == pm.ext_port_end ||
                (ctrl.port_mapping.ext_port_start <= pm.ext_port_start && ctrl.port_mapping.ext_port_end >= pm.ext_port_end))) {
              return true;
            }
          }
          return false;
        }

        ctrl.ok = function(){
            $uibModalInstance.close(ctrl.port_mapping);
        };
        ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};

        ctrl.checkPortValid = function() {
          return !$scope.isReservedPort(ctrl.port_mapping);
        };

        ctrl.checkPortRange = function() {
            // if ext port is range, the int port range should be same as ext port range value. [500-600, 500-600]
            // if [500-600, 550-660], it can not save.
            if(ctrl.port_mapping.ext_port_end-ctrl.port_mapping.ext_port_start!=0){
                if(ctrl.port_mapping.int_port_start!=ctrl.port_mapping.ext_port_start){
                    return false;
                }
            }
            return true;
        };
    }])

    .controller('modalSpcAddRuleCtrl',['devicesService', 'PortForwardingConf', '$uibModalInstance', 'typeOfRules', function (devicesService, PortForwardingConf, $uibModalInstance, typeOfRules) {
        var ctrl = this;
        ctrl.typeOfRules = typeOfRules;
        ctrl.modes = ['AUTO', 'MANUAL'];
        ctrl.mode = ctrl.modes[0];
        ctrl.rules = PortForwardingConf[typeOfRules];
        ctrl.selected_ruleset = ctrl.rules[0];

        devicesService.connected_devices().then(function(data){
            ctrl.devices = data;
            ctrl.isDataReady = true;
        });

        ctrl.ok = function(){
            $uibModalInstance.close({
            ip : ctrl.mode == 'AUTO' ? ctrl.selected_device.ip : ctrl.manualHostIP,
            ruleset: ctrl.selected_ruleset
          });
        };
        ctrl.cancel = function(){$uibModalInstance.dismiss('cancel');};
    }])


;
