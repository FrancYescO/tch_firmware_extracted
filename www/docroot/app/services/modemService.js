/***************
   modemService
****************/
angular.module('fw').service('modemService', ['$q','$log','api', 'fwHelpers', function($q, $log, api, fwHelpers) {
    
    this.led_status = function() {
        return api.get('led_status').then(function(data) {
            var status = {
                line: {
                    status: data.led_0 == '1'? 'ON' : 'OFF',
                    last_verification: data.led_0_date
                },
                wifi: {
                    status: data.led_1 == '1'? 'ON' : 'OFF',
                    last_verification: data.led_1_date
                },
                wps: {
                    status: data.led_2 == '1'? 'ON' : 'OFF', // 'CON' status will show a blinking green light
                    last_verification: data.led_2_date
                },
                presence: data.background_enabled == '1',
                auto_off: {
                    active: data.background_schedule == '1',
                    from: data.background_start==""?"00:00":data.background_start,
                    to: data.background_end==""?"00:30":data.background_end
                }
            };

            status.isBackgroundActiveNow = function() {
                if(status.presence && status.auto_off.active) {
                    var dtStart = moment(status.auto_off.from, 'HH:mm'),
                        dtStop = moment(status.auto_off.to, 'HH:mm');
                    if(dtStop.isBefore(dtStart)) {
                        return !(moment().isAfter(dtStart) || moment().isBefore(dtStop));
                    }
                    return !moment().isBetween(dtStart, dtStop);
                }
                return status.presence;
            }

            return status;
        });
    };

    this.led_status_refresh = function() {
        return api.get('led_status_refresh');
    }
    
    this.update_status = function(background, auto_off){
        return api.set('led_status', {
            'background_enabled' : background? '1' : '0',
            'background_schedule' : auto_off.active? '1' : '0', 
            'background_start': auto_off.from, 
            'background_end': auto_off.to
        });
    };
    
    this.line_status = function(){
        return api.get('diagnostic').then(function(data) {
            return {
                status: data.wan_link == '1',
                details: {
                    line: data.wan_link == '1'? 'OK' : 'NOK',
                    ipv4: data.wanip,
                    hop_ping: data.next_hop_ping == '1'? 'OK' : 'NOK',
                    dns_ping: data.next_dns_ping == '1'? 'OK' : 'NOK'
                }
            };
        });
    };
    
    this.wifi_status = function(){
        return api.get('diagnostic').then(function(data) {
            return {
                status: data.wl0_enabled == '1' || data.wl1_enabled == '1',
                f5ghz: {
                    status: data.wl0_enabled == '1', security: data.wl0_security
                },
                f24ghz: {
                    status: data.wl1_enabled == '1', security: data.wl1_security
                }
            };
        });
    };
    
    this.ports_status = function(){
        return api.get('diagnostic').then(function(data) {
            return {
                eth: [
                    {name: 'Ethernet 1', status: data.eth1_link == '1', speed: data.eth1_media_type},
                    {name: 'Ethernet 2', status: data.eth2_link == '1', speed: data.eth2_media_type},
                    {name: 'Ethernet 3', status: data.eth3_link == '1', speed: data.eth3_media_type},
                    {name: 'Ethernet 4', status: data.eth4_link == '1', speed: data.eth4_media_type}
                ],
                usb: [
                    {name: 'USB 1', status: data.usb_port1 == 'Connected', speed: ''},
                    {name: 'USB 2', status: data.usb_port2 == 'Connected', speed: ''}
                ]
            };
        });
    };

    this.ping_status = function(){
        return api.get('ping_status').then(function(data) {
            return {
                details: {
                    hop_ping: data.next_hop_ping == '1'? 'OK' : 'NOK',
                    dns_ping: data.next_dns_ping == '1'? 'OK' : 'NOK'
                }
            };
        });
    };
}]);

