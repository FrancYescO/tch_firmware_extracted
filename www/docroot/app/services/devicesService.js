/***************
  devicesService
****************/
angular.module('fw').service('devicesService',['$q','$log','api', 'fwHelpers', function($q, $log, api, fwHelpers) {
  
  var days = ['mon','tue','wed','thu','fri','sat','sun'];
  var family_device_props = [
    'name',
    'mac',
    'icon',
    'online',
    'last_connection',
    'ip',
    'type_of_connection',
    'network',
    'parental',
    'routine',
    'boost_scheduled',
    'boost_mon',
    'boost_tue',
    'boost_wed',
    'boost_thu',
    'boost_fri',
    'boost_sat',
    'boost_sun',
    'boost_duration',
    'boost_start',
    'stop_scheduled',
    'stop_mon',
    'stop_tue',
    'stop_wed',
    'stop_thu',
    'stop_fri',
    'stop_sat',
    'stop_sun',
    'stop_duration',
    'stop_start'
  ];

  var history_device_props = [
    'name',
    'mac',
    'last_connection',
    'ip',
    'icon'
  ];

  var orderByLastConnection = function(a, b) {
    // sorting by last connection (latest to oldest)
    // using moment because Date.parse() is not reliable across browsers.
    var diff = moment(b.last_connection) - moment(a.last_connection);
    if(diff > 0) return 1;
    if(diff < 0) return -1;
    return 0;
  }

  this.connected_devices = function() {
    return api.get('connected_device_list').then(function(data) {
      var prop = fwHelpers.propHelper(data, 'dev'),
          devices = [],
          devices_notFamily = [];

      // pushing the "Family" devices first
      for(var i = 0; i < data.total_num; i++) {
        var dev = {
          name:   prop.get(i,'name'),
          icon:   prop.get(i,'icon'),
          mac:    prop.get(i,'mac'),
          ip:     prop.get(i,'ip'),
          family: prop.get(i,'family') == 1,
          boost:  prop.get(i,'boost') == 1,
          stop:   prop.get(i,'stop') == 1,
          boost_remaining: Math.floor(prop.get(i, 'boost_remaining')/60),
          stop_remaining:  Math.floor(prop.get(i, 'stop_remaining')/60),
          last_connection: prop.get(i, 'last_connection'),
          online : true
        }
        if(prop.get(i,'family')==1) {
          devices.push(dev);
        }
        else {
          devices_notFamily.push(dev);
        }
      }
      // sorting the "Family" devices by last connection time.
      devices.sort(orderByLastConnection);

      return devices.concat(devices_notFamily);
    });
  }, 

  this.family_devices = function() {
    return api.get('family_device_list').then(function(data) {
      var devs = fwHelpers.objectToArray(data, 'dev', data.total_num, family_device_props);
      for(var i = 0; i< devs.length; i++) {
        devs[i].boost_days = '';
        devs[i].stop_days = '';
        for(var k = 0; k<days.length; k++ ){
          devs[i].boost_days += devs[i]['boost_'+days[k]];
          devs[i].stop_days += devs[i]['stop_'+days[k]];
        }
      }

      devs.sort(function(a, b){
        // sorting "online/offline" devices, online first then by last connection, latest to oldest
        if(b.online != a.online)
          return b.online - a.online;

        // sorting by last connection, latest to oldest
        return orderByLastConnection(a, b);
      });

      return devs;
    });
  },

  this.add_family_devices = function(devices) {
    var promises = [];
    for(var i = 0; i< devices.length; i++){
      var dev = devices[i];
      promises.push(api.set('family_device_add', {
        mac: dev.mac,
        family_name: dev.name
      }));
    }

    return $q.all(promises).then(function(result){return result;});
  },

  this.remove_family_devices = function(devices) {
    var promises = [];
    for(var i = 0; i< devices.length; i++){
      var dev = devices[i];
      promises.push(api.set('family_device_del', {
        mac: dev.mac
      }));
    }

    return $q.all(promises).then(function(result){return result;});
  },

  this.update_family_device = function(dev) {
    return api.set('family_device_add', {
        mac : dev.mac,
        family_name : dev.name,
        icon_id : dev.icon,
        routine: dev.routine,
        boost_scheduled: dev.boost_scheduled,
        boost_duration : dev.boost_duration,
        boost_start : dev.boost_start,
        boost_mon : dev.boost_days[0],
        boost_tue : dev.boost_days[1],
        boost_wed : dev.boost_days[2],
        boost_thu : dev.boost_days[3],
        boost_fri : dev.boost_days[4],
        boost_sat : dev.boost_days[5],
        boost_sun : dev.boost_days[6],
        stop_scheduled : dev.stop_scheduled,
        stop_duration : dev.stop_duration,
        stop_start : dev.stop_start,
        stop_mon : dev.stop_days[0],
        stop_tue : dev.stop_days[1],
        stop_wed : dev.stop_days[2],
        stop_thu : dev.stop_days[3],
        stop_fri : dev.stop_days[4],
        stop_sat : dev.stop_days[5],
        stop_sun : dev.stop_days[6],
        parental_ctl : dev.parental
      }
    )
  },

  this.update_generic_device = function(dev) {
    var params = {
        mac : dev.mac,
        name : dev.name
    };

    if(typeof(dev.icon) != 'undefined')
      params.icon_id = dev.icon;

    return api.set('generic_device_edit', params);
  },

  this.device_history = function() {
    return api.get('device_history_list').then(function(data) {
      return fwHelpers.objectToArray(data, 'dev', data.total_num, history_device_props).sort(orderByLastConnection);
    });
  },

  this.boost_device = function(mac, enable, timeout) {
    return api.set('boost_device', {
      mac: mac,
      activate: enable ? 1 : 0,
      counter: enable ? timeout : -1
    });
  },

  this.stop_device = function(mac, enable, timeout) {
    return api.set('stop_device', {
      mac: mac,
      activate: enable ? 1 : 0,
      counter: enable ? timeout : -1
    });
  }

}]);
