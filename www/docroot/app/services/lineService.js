/***************
   lineService
****************/
angular.module('fw').service('lineService',['$q','$log','api', 'fwHelpers', function($q, $log, api, fwHelpers) {

  var lineService = {}

  var wlssid_list_props = [
    'ssid',
    'bssid',
    'rssi'
  ];

  var speedLog_read_props = [
    'date_info',
    'linerate_us',
    'linerate_ds'
  ];

    lineService.twogchannel_list = [];
    lineService.fivegchannel_list = [];

    function channelsToMultiArray(object, prefix, channel, props) {
      var res = [];
      for(var i = 0; i < channel.length; i++) {
        var item = [];
        var j = 0;

        while(typeof object[prefix+'_'+channel[i]+'_'+props[0]+'_'+j] != 'undefined'){
          var obj = {};
          for(var k=0; k < props.length; k++) {
            obj[props[k]] = object[prefix+'_'+channel[i]+'_'+props[k]+'_'+j];
          }
          obj.channel = channel[i];
          item.push(obj);
          j++;
        }
        if(item.length > 0) res.push(item);
      }
      return res;
    };

    function checkChannel40MHz(ch) {
      return ((ch != 116) && (ch <= 132) && ((ch-36) % 8 == 0));
    }

    function checkChannel80MHz(ch) {
      return (ch == 36 || ch == 52 || ch == 100);
    }

    //lineService.wlssid_list = function() {
    lineService.wlssid_list = function(scan) {
      //return api.get('wlssid_list').then(function(data) {
      return api.get('wlssid_list', {do_scan:scan}).then(function(data) { // June modify

        lineService.twogchannel_list = data.wl1_possible_channel_list.split(',');
        lineService.fivegchannel_list["20MHz"] = data.wl0_possible_channel_list.split(',');
        lineService.fivegchannel_list["40MHz"] = lineService.fivegchannel_list["20MHz"].filter(checkChannel40MHz);
        lineService.fivegchannel_list["80MHz"] = lineService.fivegchannel_list["20MHz"].filter(checkChannel80MHz);

        var channel = {};
        channel['freq2_4'] = channelsToMultiArray(data, '2g_channel', lineService.twogchannel_list, wlssid_list_props);
        channel['freq5'] = channelsToMultiArray(data, '5g_channel', lineService.fivegchannel_list["20MHz"], wlssid_list_props);
        channel['freq5_20MHz'] = channel['freq5'];
        channel['freq5_40MHz'] = channelsToMultiArray(data, '5g_channel', lineService.fivegchannel_list["40MHz"], wlssid_list_props);
        channel['freq5_80MHz'] = channelsToMultiArray(data, '5g_channel', lineService.fivegchannel_list["80MHz"], wlssid_list_props);
        channel['freq2_4_in_use'] = data['2g_channel_in_use'];
        channel['freq5_in_use'] = data['5g_channel_in_use'];
        return channel;
      });
  };


    lineService.get_ip = function(){
        return api.get('diagnostic').then(function(data) {
            return data.wanip;
        });
    };


  lineService.speedLog_read = function(){
    return api.get('speedLog_read').then(function(data) {

      var res = [];
      for(var i = 1; i <= data.counter; i++) {
            var item = {};
            for(var k=0; k < speedLog_read_props.length; k++) {

              item[speedLog_read_props[k]] = data[speedLog_read_props[k]+'_'+i];
            }
            res.push(item);

        }
        return res;
    });
  };

  lineService.speedLog_schedule = function(value){
    if(value) {   // is setter
      return api.set('speedLog_set', {
        speedLog_enable:  value.enabled ? 1 : 0,
        speedLog_freq:    'day',
        speedLog_time:    value.selected_freq.code == 1 ? value.selected_time : 9999,
        speedLog_mon:     1,
        speedLog_tue:     1,
        speedLog_wed:     1,
        speedLog_thu:     1,
        speedLog_fri:     1,
        speedLog_sat:     1,
        speedLog_sun:     1
      });
    }

    else {      // is getter
      return api.get('speedLog_set').then(function(data) {
        return {
          enabled:  data.speedLog_enable == '1',
          //time:     data.speedLog_time, // June modify
          time:     data.speedLog_time==""?"0000":data.speedLog_time, // June modify
          freq:     data.speedLog_time == '9999' ? 6 : 1 // 9999 means six log for day: 00:00, 04:00, 08:00, 12:00, 16:00, 20:00
            };
      });
    }
  };

  lineService.speedLog_trigger = function(){
    return api.set('speedLog_trigger', {activate:1});
  };

  lineService.getChannelInfo_5G = function(){
    return api.get('wl5g_adv').then(function(data) {
      return {
        auto_channel:   data.wl0_auto_channel == 'Auto',
        channel:    data.wl0_channel,
        bandwidth:    data.wl0_bandwidth
      };
    });
  };

  lineService.getChannelInfo_2G = function(){
    return api.get('wl2g_adv').then(function(data){
      return {
        auto_channel:   data.wl1_auto_channel == 'Auto',
        channel:    data.wl1_channel,
        bandwidth:    data.wl1_bandwidth
      };
    });
  };

  lineService.setChannelInfo_5G = function(data){
    return api.set('wl5g_adv', {
      wl0_auto_channel:   data.auto    ? 'Auto' : '0',
      wl0_channel:    data.channel,
      wl0_bandwidth:    data.bandwidth
    });
  };

  lineService.setChannelInfo_2G = function(data){
    return api.set('wl2g_adv', {
      wl1_auto_channel:   data.auto    ?  'Auto' : '0',
      wl1_channel:    data.channel,
      wl1_bandwidth:    data.bandwidth
    });
  };

  return lineService;

}]);
