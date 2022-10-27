/***************
   wifiService
****************/
angular.module('fw').service('wifiService',['$q','$log','api','settingsService', function($q, $log, api, settingsService) {

    var day_mask_hash = {
      '0000000': 'NONE',
      '0000011': 'WEEK_END',
      '1111100': 'WEEKDAYS',
      '1111111': 'ALL'
    };

    var hh_ranges = [];
    for(var i = 0; i < 24; i++){
      for(var k = 0; k < 60; k += 30){
        hh_ranges.push( (i < 10 ? '0' : '') + i +':' + (k < 10 ? '0' : '') + k);
      }
    }

    var hotspot_limits = [
      ['1800' , '0h 30\''],
      ['3600' , '1h 00\''],
      ['5400' , '1h 30\''],
      ['7200' , '2h 00\''],
      ['14400', '4h 00\''],
      ['-1',    'Nessuno']
    ];

    function main_network_2G() {
      return api.get('wl2g_sec').then(function(data){
        return {
          enabled:   data.wl1_enabled == '1',
          SSID:      data.wl1_ssid,
          broadcast: data.wl1_broadcast_ssid == '1',
          security:  (data.wl1_security||'').toUpperCase(),
          auth_key:  data.wl1_key,
          radius_authentication_ipaddr:   data.wl1_radius_authentication_ipaddr,
          radius_authentication_port:     data.wl1_radius_authentication_port,
          radius_authentication_key:      data.wl1_radius_authentication_key,
          radius_accounting_ipaddr:       data.wl1_radius_accounting_ipaddr,
          radius_accounting_port:         data.wl1_radius_accounting_port,
          radius_accounting_key:          data.wl1_radius_accounting_key
        }
      });
    };

    function save_main_network_2G(net) {
      return api.set('wl2g_sec', {
          wl1_enabled:            net.enabled ? 1 : 0,
          wl1_ssid:               net.SSID,
          wl1_broadcast_ssid:     net.broadcast ? 1 : 0,
          wl1_security:           net.security,
          wl1_key:                net.auth_key,
          wl1_radius_authentication_ipaddr:   net.radius_authentication_ipaddr,
          wl1_radius_authentication_port:     net.radius_authentication_port,
          wl1_radius_authentication_key:      net.radius_authentication_key,
          wl1_radius_accounting_ipaddr:       net.radius_accounting_ipaddr,
          wl1_radius_accounting_port:         net.radius_accounting_port,
          wl1_radius_accounting_key:          net.radius_accounting_key
        });
    };

    function main_network_5G() {
      return api.get('wl5g_sec').then(function(data){
        return {
          enabled:   data.wl0_enabled == '1',
          SSID:      data.wl0_ssid,
          broadcast: data.wl0_broadcast_ssid == '1',
          security:  (data.wl0_security||'').toUpperCase(),
          auth_key:  data.wl0_key,
          radius_authentication_ipaddr:   data.wl0_radius_authentication_ipaddr,
          radius_authentication_port:     data.wl0_radius_authentication_port,
          radius_authentication_key:      data.wl0_radius_authentication_key,
          radius_accounting_ipaddr:       data.wl0_radius_accounting_ipaddr,
          radius_accounting_port:         data.wl0_radius_accounting_port,
          radius_accounting_key:          data.wl0_radius_accounting_key
        }
      });
    };

    function save_main_network_5G(net) {
      return api.set('wl5g_sec', {
          wl0_enabled:            net.enabled ? 1 : 0,
          wl0_ssid:               net.SSID,
          wl0_broadcast_ssid:     net.broadcast ? 1 : 0,
          wl0_security:           net.security,
          wl0_key:                net.auth_key,
          wl0_radius_authentication_ipaddr:   net.radius_authentication_ipaddr,
          wl0_radius_authentication_port:     net.radius_authentication_port,
          wl0_radius_authentication_key:      net.radius_authentication_key,
          wl0_radius_accounting_ipaddr:       net.radius_accounting_ipaddr,
          wl0_radius_accounting_port:         net.radius_accounting_port,
          wl0_radius_accounting_key:          net.radius_accounting_key
        });
    };

    function guest_network() {
      return api.get('wl_guestaccess').then(function(data){

        var filtering = (data.hotspot_filtering||'all').toLowerCase();

        return {
          enabled:   data.hotspot_enable == '1',
          SSID:      data.hotspot_ssid,
          broadcast: data.hotspot_broadcast_ssid == '1',
          security:  (data.hotspot_security||'').toUpperCase(),
          auth_key:  data.hotspot_password,
          timeout:   14400,     // this is the default value proposed to user when restrictions are enabled 
          filtering: filtering,
          restrictions: (data.hotspot_timeout > 0 || filtering != 'all'),
          limit_ranges: hotspot_limits,
          remaining_time: data.hotspot_timeout >= 0 ? Math.round(data.hotspot_timeout / 60) : -1,
          filtering_values: ['all','web']
        }
      });
    };

    function save_guest_network(net) {
      return api.set('wl_guestaccess', {
          hotspot_enable:             net.enabled ? 1 : 0,
          hotspot_ssid:               net.SSID,
          hotspot_broadcast_ssid:     net.broadcast ? 1 : 0,
          hotspot_security:           net.security,
          hotspot_filtering:          net.restrictions ? net.filtering : 'all',
          hotspot_timeout:            net.restrictions ? net.timeout : '-1'
        });
    };

    function wps_status() {
      return api.get('wl_WPS_status').then(function(data){
        return {
          gui_wps_enabled: data.gui_enabled, // June modify
          enabled: data.enabled == '1'
        }
      });
    };

    function save_wps_status(status) {
      return api.set('wl_triggerWPS', {
        activate: status.enabled ? '1' : '0'
      });
    };

    function trigger_wps() {
      return api.set('wl_triggerWPS', {
        activate: '1',
        trigger: '1'
      });
    };

    // June modify start
    function cancel_wps_proc() {
      return api.set('wl_triggerWPS', {
        activate: '1',
        trigger: '0'
      });
    };
    // June modify end

    function generate_password_for_guest() {
      return api.set('wl_guestaccess', { hotspot_enable: 1 });
    }

    function eco(data) {
      return api.get('wl_eco').then(function(data){
        return {
          enabled:    data.eco_dis == 1,
          //start_time: data.eco_start_time, // June modify
          start_time: data.eco_start_time==""?"00:00":data.eco_start_time, // June modify
          //end_time:   data.eco_end_time, // June modify
          end_time:   data.eco_end_time==""?"00:30":data.eco_end_time, // June modify
          selected_days : '' +
            data.eco_mon +
            data.eco_tue +
            data.eco_wed +
            data.eco_thu +
            data.eco_fri +
            data.eco_sat +
            data.eco_sun,
          selected_days_label : function(day_mask){ return day_mask_hash[day_mask] || 'CUSTOM' },
          day_ranges: ['0000000','0000011','1111100','1111111'],
          hh_ranges: hh_ranges
        };
      });
    }

    function save_eco(data) {
      var days = data.selected_days;

      return api.set('wl_eco', {
          eco_dis:          data.enabled ? 1 : 0,
          eco_start_time:   data.start_time,
          eco_end_time:     data.end_time,
          eco_mon:  days[0],
          eco_tue:  days[1],
          eco_wed:  days[2],
          eco_thu:  days[3],
          eco_fri:  days[4],
          eco_sat:  days[5],
          eco_sun:  days[6]
        });
    }

    function authRequiresRadius(aut_type){
      switch(aut_type) {
          case 'WPA2ENT':
          case 'WPAWPA2ENT':
              return true;
          default:
              return false;
      }
    }

    function areSettingsShared(a, b) {
      return (
        a.enabled   == b.enabled &&
        a.broadcast == b.broadcast &&
        a.security  == b.security &&
        a.auth_key  == b.auth_key &&
        (!authRequiresRadius(a.auth_key) || (
          a.radius_authentication_ipaddr == a.radius_authentication_ipaddr &&
          a.radius_authentication_port == a.radius_authentication_port &&
          a.radius_authentication_key == a.radius_authentication_key &&
          a.radius_accounting_ipaddr == a.radius_accounting_ipaddr &&
          a.radius_accounting_port == a.radius_accounting_port &&
          a.radius_accounting_key == a.radius_accounting_key))
      );
    }
   
    return {
      all_networks: function() {
        return $q.all([
            main_network_2G(),
            main_network_5G(),
            guest_network(),
            eco(),
            wps_status(),
            settingsService.get('w_split_networks')
          ]).then(function(result){
            return {
              main_network_2G: result[0],
              main_network_5G: result[1],
              guest_network: result[2],
              eco: result[3],
              shared_settings: angular.merge({},result[0]),
              wifi_status: {enabled: (result[0].enabled || result[1].enabled)},
              wps_enabled: result[4],
              gui_wps_enabled: result[4].gui_wps_enabled, // June modify
              split_networks: {active: result[5] == '1'} // in settings now
            }
        });
      },
      main_network_2G: main_network_2G,
      main_network_5G: main_network_5G,
      guest_network: guest_network,

      save_main_network_2G: save_main_network_2G,
      save_main_network_5G: save_main_network_5G,
      save_guest_network: save_guest_network,
      generate_password_for_guest: generate_password_for_guest,
      save_eco: save_eco,
      save_wps_status: save_wps_status,
      trigger_wps: trigger_wps,
      cancel_wps_proc: cancel_wps_proc, // June modify
      wps_proc_status: function wps_proc_status(){return api.get('wps_proc_status').then(function(d){return d.status})},

      authRequiresRadius: authRequiresRadius
    }
  }]);

