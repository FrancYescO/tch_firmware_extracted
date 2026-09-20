--pretranslated: do not change this file

--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local content_helper = require("web.content_helper")

local mobiled = {
	DeviceNumberOfEntries = "rpc.mobiled.DeviceNumberOfEntries",
}
content_helper.getExactContent(mobiled)
local mobileshow
if mobiled.DeviceNumberOfEntries == '1' then
  mobileshow = 33
else
  mobileshow = 35
end

local menuTbl = {
  menu = {
    Overview = {
      {
        id= "1",
        parentid= "-1",
        text= T"Overview",
        link= "modals/overview.lp",
        pid="overview"
      }
    },
    Phone = {
      {
        id = "1",
        parentid = "-1",
        mode = "33",
        text = T"Call Log",
        link = "modals/call-log.lp",
        pid="call-log"
      },{
        id = "2",
        parentid = "-1",
        mode = "34",
        text = T"Ringing Schedule",
        link = "modals/ringing-schedule.lp",
        pid= "ringing-schedule"
      },{
        id = "3",
        parentid = "-1",
        mode = "34",
        text = T"Phone Numbers",
        link = "modals/phone-numbers.lp",
        pid="phone-numbers"
      },{
        id = "4",
        parentid = "3",
        mode = "34",
        text = T"Phone Settings",
        link = "modals/phone-settings.lp",
        pid="phone-settings"
      },{
        id = "5",
        parentid = "-1",
        mode = "35",
        text = T"Call Settings",
        link = "modals/call-settings.lp",
        pid="call-settings"
      }
    },
    Internet = {
      {
        id = "1",
        parentid = "-1",
        mode = "34",
        text = T"Firewall",
        link = "modals/firewall.lp",
        pid="firewall"
      },{
        id= "2",
        parentid= "-1",
        mode= "33",
        text= T"Mobile",
        link= "modals/mobile.lp",
        pid="mobile"
      },{
        id= "3",
        parentid= "-1",
        mode= "34",
        text= T"Port Mapping",
        link= "modals/port-mapping.lp",
        pid="port-mapping"
      },{
        id= "4",
        parentid= "-1",
        mode= "34",
        text= T"DMZ",
        link= "modals/dmz.lp",
        pid="dmz"
      },{
        id= "5",
        parentid= "-1",
        mode= "34",
        text= T"Parental Control",
        link= "modals/parental-control.lp",
        pid="parental-ctrl"
      },{
        id= "6",
        parentid= "-1",
        mode= "34",
        text= T"DNS & DDNS",
        link= "modals/dns-ddns.lp",
        pid="dns-ddns"
      },{
        id= "7",
        parentid= "-1",
        mode= "34",
        text= T"UPnP",
        link= "modals/upnp.lp",
        pid="upnp"
      }, {
        id= "8",
        parentid= "-1",
        mode= "33",
        text= T"ADSL Configuration",
        link= "modals/pppoa.lp",
        pid="pppoa"
      }
    },
    WiFi = {
      {
        id= "1",
        parentid= "-1",
        mode= "33",
        text= T"General",
        link= "modals/wifi-general.lp",
        pid="wifi-general"
      },{
        id= "2",
        parentid= "-1",
        mode= "33",
        text= T"Power Saving Mode",
        link= "modals/schedule.lp",
        pid="power-saving-mode"
      },{
        id= "3",
        parentid= "-1",
        mode= "33",
        text= T"WPS",
        link= "modals/wps.lp",
        pid="wps"
      },{
        id= "4",
        parentid= "-1",
        mode= "34",
        text= T"MAC Filter",
        link= "modals/mac-filter.lp",
        pid="mac-filter"
      },{
        id= "5",
        parentid= "-1",
        mode= "34",
        text= T"Settings",
        link= "modals/settings.lp",
        pid="settings"
      },{
        id= "7",
        parentid= "-1",
        mode= "33",
        text= T"Analyser",
        link= "modals/analyser.lp",
        pid="analyser"
      },{
        id= "8",
        parentid= "7",
        mode= "33",
        text= T"2.4GHz",
        link= "modals/analyser.lp",
        pid="analyser24"
      },{
        id= "9",
        parentid= "7",
                mode= "33",
        text= T"5GHz",
        link= "modals/analyser.lp",
        pid="analyser5"
      },{
        id= "10",
        parentid= "-1",
        mode= "34",
        text= T"Client Monitoring",
        link= "modals/client-monitoring.lp",
        pid="client-monitor"
      }
    },
    Settings = {
      {
        id= "1",
        parentid= "-1",
        mode= "33",
        text= T"Password",
        link= "modals/password.lp",
        pid="password"
      },{
        id= "2",
        parentid= "-1",
        mode= "34",
        text= T"Firmware Update",
        link= "modals/upgrade.lp",
        pid="firmware-update"
      },{
        id= "3",
        parentid= "-1",
        mode= "33",
        text= T"Configuration",
        link= "modals/configuration.lp",
        pid="configuration"
      },{
        id= "4",
        parentid= "-1",
        mode= "34",
        text= T"LAN",
        link= "modals/ipv4.lp",
        pid="lan"
      },{
        id= "5",
        parentid= "-1",
        mode= "35",
        text= T"QoS",
        link= "modals/qos.lp",
        pid="qos"
      },{
        id= "6",
        parentid= "-1",
        mode= "34",
        text= T"Internet Time",
        link= "modals/internet-time.lp",
        pid="internet-time"
      },{
        id= "7",
        parentid= "-1",
        mode= "35",
        text= T"TR-069",
        link= "modals/tr-069.lp",
        pid="tr-069"
      },{
        id= "8",
        parentid= "-1",
        mode= "35",
        text= T"Access Control",
        link= "modals/access-control.lp",
        pid="acces-control"
      },{
        id= "9",
        parentid= "-1",
        mode= "35",
        text= T"xDSL",
        link= "modals/xdsl.lp",
        pid="xdsl"
      },{
        id = "10",
        parentid= "-1",
        mode= "34",
        text= T"WAN",
        link= "modals/wan.lp",
        pid="wan"
      },{
        id= "11",
        parentid= "-1",
        mode= "34",
        text= T"Ipv6-Basic-Configuration",
        link= "modals/ipv6-basic-configuration.lp",
        pid="ipv6-basic-config"
      },{
        id= "12",
        parentid= "-1",
        mode= "34",
        text= T"Static Routing",
        link= "modals/static-routing.lp",
        pid="static-routing"
      },{
        id= "13",
        parentid= "-1",
        mode= "34",
        text= T"Policy Routing",
        link= "modals/policy-routing.lp",
        pid="policy-routing"
      },{
        id= "14",
        parentid= "-1",
        mode= "34",
        text= T"Assistance",
        link= "modals/assistance.lp",
        pid="assistance"
      },{
        id= "16",
        parentid= "-1",
        mode= "34",
        text= T"DLNA",
        link= "modals/dlna.lp",
        pid="DLNA"
      },{
        id= "17",
        parentid= "-1",
        mode= "34",
        text= T"Samba",
        link= "modals/samba.lp",
        pid="samba"
      },{
        id= "18",
        parentid= "-1",
        mode= "34",
        text= T"Printer Sharing",
        link= "modals/printer-sharing.lp",
        pid="printer-sharing"
      },{
        id= "19",
        parentid= "-1",
        mode= "34",
        text= T"USB",
        link= "modals/usb.lp",
        pid="usb"
      }
    },
    StatusSupport = {
      {
        id= "1",
        parentid= "-1",
        mode= "33",
        text= T"Status",
        link= "modals/status.lp",
        pid="status"
      },{
        id= "2",
        parentid= "1",
        mode= "33",
        text= T"Voice Status",
        link= "modals/voice-status.lp",
        pid="voice-status"
      },{
        id= "3",
        parentid= "1",
        mode= "33",
        text= T"xDSL Status",
        link= "modals/adslStatus.lp",
        pid="adsl-status"
      },{
        id= "4",
        parentid= "1",
        mode= "33",
        text= T"WAN Status",
        link= "modals/wan-status.lp",
        pid="wan-status"
      },{
        id= "5",
        parentid= "1",
        mode= "33",
        text= T"LAN Status",
        link= "modals/lan-status.lp",
        pid="lan-status"
      },{
        id= "6",
        parentid= "1",
        mode= mobileshow,
        text= T"Mobile Status",
        link= "modals/mobile-status.lp",
        pid="mobile-status"
      },{
        id= "7",
        parentid= "1",
        mode= "34",
        text= T"Routing",
        link= "modals/routing.lp",
        pid="routing"
      },{
        id= "8",
        parentid= "-1",
        mode= "33",
        text= T"Diagnostic Utility",
        link= "modals/diagnostic-utility.lp",
        pid="diagnostic-utility"
      },{
        id= "9",
        parentid= "-1",
        mode= "34",
        text= T"Event Log",
        link= "modals/event-log.lp",
        pid="event-log"
      },{
        id= "10",
        parentid= "-1",
        mode= "33",
        text= T"Restart",
        link= "modals/restart.lp",
        pid="restart"
      },{
        id= "11",
        parentid= "-1",
        mode= "33",
        text= T"About",
        link= "modals/about.lp",
        pid="about"
      },{
        id= "12",
        parentid= "-1",
        mode= "34",
        text= T"NAT Mapping Table",
        link= "modals/nat-mapping-table.lp",
        pid="nat-mapping"
      },{
        id= "13",
        parentid= "-1",
        mode= "35",
        text= T"VOIP Diagnostic",
        link= "modals/voip-diagnostic.lp",
        pid="voip-diagnostic"
      },{
        id= "14",
        parentid= "-1",
        mode= "35",
        text= T"Port Mirroring",
        link= "modals/port-mirroring.lp",
        pid="port-mirroring"
      }
    }
  }
}

local json = require("dkjson")
local buffer = {}
json.encode (menuTbl, {indent = false, buffer = buffer })
ngx.print(buffer)
ngx.exit(ngx.HTTP_OK)
  ngx.print('\
');
