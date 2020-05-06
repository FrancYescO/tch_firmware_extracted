/***************
   advancedService
****************/
angular.module('fw').service('advancedService',['$q','$log','$filter','api','devicesService', 'fwHelpers', function($q, $log, $filter, api, devicesService, fwHelpers) {
    
    /* ---------------------------
     PARENTAL CONTROL
     ---------------------------*/

    function pc_list() {
        return api.get('pc_list').then(function(data) {        
            var block_list_devices = [];

            for(var i = 0; i < data.total_dev; i++){
                block_list_devices.push({
                    name: data['dev_'+i+'_name'],
                    mac: data['dev_'+i+'_mac'],
                    icon: data['dev_'+i+'_icon'],
                    active: data['dev_'+i+'_enabled'] == '1'
                });
            }
            
            var block_list_sites = [];
            for(var i = 0; i < data.total_addr; i++){
                block_list_sites.push({
                    url: data['addr_'+i+'_uri'],
                    active: data['addr_'+i+'_enabled'] == '1'
                });
            }
            return {
                parental_enabled: data.enabled == '1',
                single_devices: data.mode_all == '1', // {0: all devices, 1: listed}
                blocks_list_uri: block_list_sites,
                blocks_list_dev: block_list_devices
            };
        });
    };
    
    this.pc_list = function() {
      return $q.all([pc_list(), devicesService.family_devices()])
        .then(function(data) {
          var filter = $filter('filter');
          for(var i = 0; i < data[0].blocks_list_dev.length; i++) {
            if( filter(data[1], {mac: data[0].blocks_list_dev[i].mac}).length > 0 ) {
              data[0].blocks_list_dev[i].family = true;
            }
          }
          return data[0];
        });
    }

    this.add_parental_devices = function(devices) {
      var promises = [];
      for(var i = 0; i< devices.length; i++){
        var dev = devices[i];
        promises.push(api.set('pc_device_set', {
          mac: dev.mac,
          enabled: 1
        }));
      }
      return $q.all(promises).then(function(result){return result;});
    }

    this.remove_parental_devices = function(devices) {
        var promises = [];
        for(var i = 0; i< devices.length; i++){
          var dev = devices[i];
          promises.push(api.set('pc_device_del', {
            mac: dev.mac
          }));
        }
        return $q.all(promises).then(function(result){return result;});
    }
    
    this.add_pc_url = function(uri, enabled){
        return api.set('pc_address_set', {
            'uri' : uri,
            'enabled' : enabled ? '1' : '0'
        });
    };

    this.remove_pc_url = function(uri){
        return api.set('pc_address_del', {
            'uri' : uri
        });
    };

    this.set_parental_status = function(enabled, mode) {
         return api.set('pc_list', {
            'enabled' : enabled ? '1' : '0',
            'mode_all' : mode ? '1' : '0' // {0 -> all, 1 -> only listed}
        });
    }
    

    /* ---------------------------
     ACCESS RESTRICTIONS
     ---------------------------*/
    
    this.get_restrictions = function() {
        return api.get('bl_conf').then(function(data) {        
            var devices = [];
            for(var i = 0; i < data.total_num; i++){
                devices.push({
                    name: data['dev_'+i+'_name'],
                    mac: data['dev_'+i+'_mac'],
                    active: data['dev_'+i+'_enabled'] == '1'
                });
            }
            
            return {
                enabled: data.enabled == '1',
                behaviour: data.mode == 'allow',
                devices: devices
            };
        });
    };

    this.set_restrictions = function(bl_conf){
        var promises = []; 

        for(var i = 0; i< bl_conf.devices.length; i++){
            var dev = bl_conf.devices[i];
            promises.push(api.set('bl_device_set', {
                mac: dev.mac,
                enabled: dev.active ? '1' : '0'
            }));
        }

        return $q.all(promises).then(function(result){return result;});
    }

    // June modify start for block list add 1 rule only.
    this.set_bl_behavior = function(mode){
        return api.set('bl_conf', {
            mode: mode ? 'allow' : 'block'
        });
    };
    this.add_bl_res = function(dev){
        return api.set('bl_device_set', {
            mac: dev.mac,
            enabled: dev.active='1'
        });
    };
    this.del_bl_res = function(mac){
        return api.set('bl_device_del', {
            mac: mac
        });
    };
    // June modify end

    /* ---------------------------
     UPNP
     ---------------------------*/

    this.upnp_status = function(){
        return api.get('upnp_conf').then(function(data) {
            return {
                enabled : data.enabled == '1',
                rules : fwHelpers.objectToArray(data, 'rule', data.total_num, ['id','descr','ext_port','int_port','proto', 'ip'])
            };
       });
    }

    this.upnp_update_status = function(enabled) {
        return api.set('upnp_conf', {enabled: enabled ? 1 : 0});
    }


    /* ---------------------------
     MANUAL PORT SETTINGS
     ---------------------------*/          
    this.firewall_conf = function(){
        return api.get('firewall_conf').then(function(data) {
            data.enabled = data.enabled == '1'? true : false;
            return data;
        });
    }

    this.set_firewall_conf = function(data){
        var firewall = {
            enabled : data.enabled ? '1' : '0',
            level : data.level
        }       
        return api.set('firewall_conf', firewall);
    }  

    this.dmz_conf = function(){
        return api.get('dmz_conf').then(function(data) {
            data.enabled = data.enabled == '1'? true : false;
            return data;
        });
    }

    this.set_dmz_conf = function(data){
        var dmz_conf = {
            enabled: data.enabled ? '1' : '0',
            server: data.server
        };
        return api.set('dmz_conf', dmz_conf);
    }

    var virtual_server_props = [
        'id',
        'code',
        'enabled',
        'descr',
        'ext_port_start',
        'ext_port_end',
        'int_port_start',
        'proto',
        'hostname', // June modify
        'ip'
    ];

    this.virtual_server_list = function(){
        return api.get('virtual_server_list').then(function(data) {
            var res = [];
            for(var i = 0; i < data.total_num; i++) {
                var item = {};
                for(var k=0; k < virtual_server_props.length; k++) {
                    if(virtual_server_props[k].search('port') > -1) item[virtual_server_props[k]] = parseInt(data['svc_'+i+'_'+virtual_server_props[k]]);
                    else item[virtual_server_props[k]] = data['svc_'+i+'_'+virtual_server_props[k]];
                }
                res.push(item);
            }
            return res;            
        });
    }

    this.virtual_server_set = function(data){
        return api.set('virtual_server_set', data);      
    }

    // now takes an array of rule id to remove
    this.virtual_server_del = function(id_array){
        return api.set('virtual_server_del', {
            total_num: id_array.length,
            id: id_array.join(',')
        });
    }
    

    /* ---------------------------
     LAN SETTINGS
     ---------------------------*/       

    this.lan_status = function(){
        return api.get('lan_status').then(function(data) {
            var lan = {
                ip : data.ip, 
                netmask: data.netmask, 
                DHCP: {
                    enabled:    data['DHCP_enabled'] == '1',
                    start:      data['DHCP_start'],
                    end:        data['DHCP_end'],
                    duration:   parseInt(data['DHCP_duration']) / 3600
                }, 
                IPV6: {
                    on_LAN:     data['IPV6_on_LAN'] == '1',
                    prefix_6rd: data['IPV6_prefix_6rd'],
                },
                DHCP_list: []
            };
           
            var i = 0;
            while(typeof(data['DHCP_'+i+'_mac']) != 'undefined'){
                lan.DHCP_list.push({ip : data['DHCP_'+i+'_ip'], mac : data['DHCP_'+i+'_mac']});
                i++;
            }

            return lan;
        });
    }

    this.set_lan_status = function(lan_status){
        var promises = []; 

        promises.push(api.set('lan_status',{
            ip: lan_status.ip,
            netmask : lan_status.netmask,
            IPV6_on_LAN : lan_status.IPV6.on_LAN  ? '1' : '0',
            DHCP_enabled : lan_status.DHCP.enabled ? '1' : '0',
            DHCP_start : lan_status.DHCP.start,
            DHCP_end : lan_status.DHCP.end,
            DHCP_duration : lan_status.DHCP.duration * 3600 
        })); 

        return $q.all(promises).then(function(result){return result;});
    }

    // June modify start for dhcp add 1 rule only.
    this.add_dhcp_res = function(dev){
        return api.set('dhcp_set', {
            mac: dev.mac,
            ip: dev.ip
        });
    };
    this.del_dhcp_res = function(mac){
        return api.set('dhcp_del', {
            mac: mac
        });
    };
    // June modify end

    /* ---------------------------
     USB SETTINGS
     ---------------------------*/
     
    this.get_usb_status = function() {
        return api.get('usb_status').then(function(data) {
            var prop = fwHelpers.propHelper(data, 'disk');
            data.disks = [];

            for(var i = 0; i< data.total_disks; i++) {
                data.disks.push({
                    disk_id:    i,
                    mount:      prop.get(i,'mount'), // June modify
                    name:       prop.get(i,'name'),
                    fs:         prop.get(i,'fs'),
                    size:       prop.get(i,'size'),
                    available:  prop.get(i,'available')
                });
            }

            data.dlna_enabled = data.dlna_enabled == '1';
            data.printserver_enabled = data.printserver_enabled == '1';
            data.samba_enabled = data.samba_enabled == '1';
            data.disk_protected = data.disk_protected == '1';
            data['3g_fallback'] = data['3g_fallback'] == '1';
            data['3g_connection_status'] = data['3g_connection_status'] == '1';
            
            // set 'first time' defaults for UI:
            if(data['3g_activation'] == '')
                data['3g_activation'] = '0';

            if(data['3g_timeout'] == '')
                data['3g_timeout'] = '30';

            return data;
        });
    }

    this.set_usb_status = function(data) {
        return api.set('usb_status', {
            dlna_enabled:           data.dlna_enabled ? 1 : 0,            
            printserver_enabled:    data.printserver_enabled ? 1 : 0,

            samba_enabled:          data.samba_enabled ? 1 : 0,
            samba_server:           data.samba_server,
            samba_workgroup:        data.samba_workgroup,
            samba_share_on:         data.samba_share_on, // this is newly added (allowed values: 'lan', 'wan')

            disk_protected:         data.disk_protected ? 1 : 0,
            disk_username:          data.disk_username,
            disk_password:          data.disk_password, // this is newly added
            
            '3g_fallback':          data['3g_fallback'] ? 1 : 0,
            '3g_connection_status': data['3g_connection_status'] ? 1 : 0,
            '3g_activation':        data['3g_activation'],
            '3g_timeout':           data['3g_timeout'],
            '3g_pin':               data['3g_pin'],
            '3g_apn':               data['3g_apn'],
            '3g_username':          data['3g_username'],
            '3g_password':          data['3g_password']
        });
    }

    this.enable_3g = function(data) {
        return api.set('usb_status', {            
            '3g_fallback':      1,
            '3g_activation':    data['3g_activation'],
            '3g_timeout':       data['3g_timeout'],
            '3g_pin':           data['3g_pin'],
            '3g_apn':           data['3g_apn'],
            '3g_username':      data['3g_username'],
            '3g_password':      data['3g_password']
        });
    }

    this.umount_usb_device = function(disk) {
        return api.set('usb_remove', {diskId: disk.disk_id, mount: disk.mount});
    }
}]);

