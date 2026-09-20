/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

var duma = duma || {};
duma.devices = duma.devices || {};

var rappid_dev_man = "com.netdumasoftware.devicemanager";
var stale_time = 60; // In seconds.
var last_update;
var database = {};

duma.devices.is_nonempty_string = function( x ){
  return typeof( x ) == "string" && x != "";
}
function is_nonempty_string( x ){
  return duma.devices.is_nonempty_string( x );
}

duma.devices.emptyDatabase = function(database) {
  for (var id in database) {
    if (database.hasOwnProperty(id) && id != 0) {
      delete database[id];
    }
  } 
}
function emptyDatabase(database) {
  return duma.devices.emptyDatabase(database);
}

duma.devices.processDevice = function(raw_device, online_interfaces) {
  var device = {
    id: raw_device.devid,
    name: raw_device.uhost,
    type: raw_device.utype,
    blocked: raw_device.block,
    interfaces: []
  };

  for (var p = 0; p < online_interfaces.length; p++) {
    var online_interface = online_interfaces[p];
    var found_interface = raw_device.interfaces.find(function (device_interface) {
      return device_interface.mac === online_interface.mac;
    });


    if (found_interface) {
      var processed_interface = {
        ips: online_interface.ips,
        mac: online_interface.mac,
        name: found_interface.ghost,
        type: found_interface.gtype,
        pinned: found_interface.pinned === 1,
        wifi: found_interface.wifi === 1,
        ssid: online_interface.ssid,
        freq: online_interface.freq,
        signal: online_interface.signal
      };

      device.interfaces.push(processed_interface);
    }
  }

  /* added retrospectively so that offline interfaces are available */
  for( var p = 0; p < raw_device.interfaces.length; p++ ){
    var inf = raw_device.interfaces[p];
    var exist = device.interfaces.find( function( d ) {
      return inf.mac === d.mac
    });
    if( !exist ){
      device.interfaces.push({
        mac: inf.mac,
        name: inf.ghost,
        type: inf.gtype,
        pinned: inf.pinned === 1,
        wifi: inf.wifi === 1,
        ips: []
      })
    }
  }

  for( var p = 0; p < raw_device.interfaces.length; p++ ){
    var found_interface = raw_device.interfaces[p];

    if( !duma.devices.is_nonempty_string ( device.name ) ){
      if( duma.devices.is_nonempty_string( found_interface.dhost ) ){
        device.name = found_interface.dhost;
      } else if( duma.devices.is_nonempty_string( found_interface.ghost ) ){
        device.name = found_interface.ghost;
      }
    }
    
    if( !duma.devices.is_nonempty_string ( device.type ) ){
      if( duma.devices.is_nonempty_string( found_interface.atype ) ){
        device.type = found_interface.atype;
      } else if( duma.devices.is_nonempty_string( found_interface.gtype ) ){
        device.type = found_interface.gtype;
      }
    }
  }
  
  database[raw_device.devid] = device;
}
function processDevice(raw_device, online_interfaces) {
  return duma.devices.processDevice(raw_device, online_interfaces);
}

duma.devices.defer = function(callback) {
  return Q.spread([
    long_rpc_promise(rappid_dev_man, "get_all_devices", []),
    long_rpc_promise(rappid_dev_man, "get_valid_online_interfaces", [])
  ], function (devices, online_interfaces) {
    devices = devices[0];
    online_interfaces = online_interfaces[0];

    last_update = new Date();

    duma.devices.emptyDatabase( database );

    for (var i = 0; i < devices.length; i++) {
      var raw_device = devices[i];
      duma.devices.processDevice(raw_device, online_interfaces);
    }

    duma.devices.processDevice({
      devid: 0,
      utype: "null",
      uhost: "null",
      interfaces: [{
        mac: "00:00:00:00:00:00",
        pinned: 0,
        wifi: 0,
        dhost: "null",
        ghost: "null",
        gtype: "null"
      }]
    }, online_interfaces);

    return callback();
  });
}
function defer(callback) {
  return duma.devices.defer(callback);
}

duma.devices.check_is_stale = function() {
  if (last_update) {
    if ((new Date() - last_update) / 1000 > stale_time) {
      return true;
    } else {
      return false;
    }
  } else {
    return true;
  }
}
function check_is_stale() {
  return duma.devices.check_is_stale();
}

duma.devices.get_devices = function() {
  function do_work() {
    return database;
  }
  if (duma.devices.check_is_stale()) {
    return duma.devices.defer(do_work);
  } else {
    return Q.fcall(do_work);
  }
}
function get_devices() {
  return duma.devices.get_devices();
}

duma.devices.getDeviceIconPath = function(file) {
  return "duma-icons:" + file;
}
duma.devices.type_to_device_icons_array =  {
  camera: duma.devices.getDeviceIconPath("camera"),
  computer: duma.devices.getDeviceIconPath("desktop"),
  laptop: duma.devices.getDeviceIconPath("laptop"),
  modem: duma.devices.getDeviceIconPath("modem"),
  phone: duma.devices.getDeviceIconPath("mobile"),
  nintendo_wii: duma.devices.getDeviceIconPath("nintendowii"),
  printer: duma.devices.getDeviceIconPath("printer"),
  playstation: duma.devices.getDeviceIconPath("playstation"),
  router: duma.devices.getDeviceIconPath("router"),
  tablet: duma.devices.getDeviceIconPath("tablet"),
  tv: duma.devices.getDeviceIconPath("tv"),
  wired: duma.devices.getDeviceIconPath("wired"),
  wireless: duma.devices.getDeviceIconPath("wireless"),
  xbox: duma.devices.getDeviceIconPath("xbox"),
  offline: duma.devices.getDeviceIconPath("offline"),
  nintendoswitch: duma.devices.getDeviceIconPath("nintendoswitch"),
  av_receiver: duma.devices.getDeviceIconPath("av_receiver"),
  amazon_echo: duma.devices.getDeviceIconPath("amazon_echo"),
  arlo: duma.devices.getDeviceIconPath("arlo"),
  dvd_player: duma.devices.getDeviceIconPath("dvd_player"),
  google_home: duma.devices.getDeviceIconPath("google_home"),
  // harmony_remote: duma.devices.getDeviceIconPath("Harmony_Remote.svg"),
  media_device: duma.devices.getDeviceIconPath("media_device"),
  nas: duma.devices.getDeviceIconPath("nas"),
  thermostat: duma.devices.getDeviceIconPath("thermostat"),
  nintendo_ds: duma.devices.getDeviceIconPath("nintendods"),
  other: duma.devices.getDeviceIconPath("other-device"),
  scanner: duma.devices.getDeviceIconPath("scanner"),
  security_camera: duma.devices.getDeviceIconPath("securitycamera"),
  set_top_box: duma.devices.getDeviceIconPath("set_top_box"),
  speaker: duma.devices.getDeviceIconPath("speaker"),
  voip_phone: duma.devices.getDeviceIconPath("voip_phone"),
  smart_home_device: duma.devices.getDeviceIconPath("smart_home_device"),
};
duma.devices.get_devices_icon = function(type) {
  if(typeof type !== "string") return null;
  return duma.devices.type_to_device_icons_array[type.toLowerCase()] || duma.devices.type_to_device_icons_array.other;
}
function get_devices_icon(type) {
  return duma.devices.get_devices_icon(type);
}

duma.devices.flush_devices_cache = function(){
  last_update = new Date(0);
}
function flush_devices_cache(){
  return duma.devices.flush_devices_cache();
}

duma.devices.find_device_by_ip = function(ip) {
  var out;
  for (var id in database) {
    if (database.hasOwnProperty(id)) {
      var device = database[id];
      var matched = device.interfaces.find(function (device_interface) {
        return device_interface.ips.find(function (interface_ip) {
          if (interface_ip == ip) {
            return true;
          }
        });
      });

      if (matched) {
        out = id;
        if (id != 0) {
          break;
        }
      }
    }
  }
  return out;
}
function find_device_by_ip(ip) {
  return duma.devices.find_device_by_ip(ip);
}

/*
* Output:
*   1) IP to Dev mappings in array
*   2) need to do retry because
*       a) could not find?
*       b) nulldev
*/
duma.devices.do_map_ips = function( ips, out, isdefer ){
  var missing = 0;
  var nulldev = 0;

  for( var i = 0; i < ips.length; i++ ){
    var devid = duma.devices.find_device_by_ip( ips[i] );
    if( is_defined( devid ) ){
      out[i] = devid;
      if( devid == 0 )
        nulldev++;

    } else {
      if( isdefer )
        console.log("Missing IP " + ips[i] );
      missing++;

      /*
      * Some routers clear ARP cache quickly. You may
      * end up with lingering TCP connection that can't
      * be mapped. So now we assume if it can't be mapped
      * it is nulldev.
      */
      out[i] = 0;

    }
  }

  if( missing )
    return missing;
  else if( nulldev )
    return -nulldev;
  else
    return 0;
}
function do_map_ips( ips, out, isdefer ){
  return duma.devices.do_map_ips(ips, out, isdefer)
}


duma.devices.map_ips = function(ips, second_try) {
  output = {}
  if( duma.devices.do_map_ips( ips, output ) ){
    return duma.devices.defer( function(){
      duma.devices.do_map_ips( ips, output, true );
      return output;
    });
  }
  
  return Q.fcall( function(){ return output; } );
}
function map_ips(ips, second_try) {
  return duma.devices.map_ips(ips, second_try)
}

duma.devices.is_online = function(id, second_try) {
  function do_work() {
    if (database[id]) {
      for (var i = 0; i < database[id].interfaces.length; i++) {
        var device_interface = database[id].interfaces[i];
        if (device_interface.ips.length > 0) {
          return true;
        } else {
          return false;
        }
      }
     return false; 
    } else if (!second_try) {
      return duma.devices.defer(function () {
        return duma.devices.is_online(id, true);
      });
    } else {
      throw "Device with that ID not found.";
    }
  }

  if (duma.devices.check_is_stale()) {
    return duma.devices.defer(do_work);
  } else {
    return Q.fcall(do_work);
  }
}
function is_online(id, second_try) {
  return duma.devices.is_online(id, second_try);
}
