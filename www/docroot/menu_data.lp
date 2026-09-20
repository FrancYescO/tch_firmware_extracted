--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local content_helper = require("web.content_helper")
local content = {
  variant = "uci.env.var.vodafone_variant",
  DeviceNumberOfEntries = "rpc.mobiled.DeviceNumberOfEntries",
}
content_helper.getExactContent(content)

local filepath
if content.variant ~= "VHA" then
  filepath = "/modals/settings/wan.lp"
else
  filepath = "/modals/settings/pppoa.lp"
end

local mobileshow
if content.DeviceNumberOfEntries == '1' then
  mobileshow = 33
else
  mobileshow = 35
end

local menuTbl = {
    mainmenu = {
        {
            id = "1",
            label = T "Overview",
            linkgeneric = "modals/overview.lp",
            pid = "Overview",
            allowedcountry = "ALL"
        }, {
            id = "2",
            label = T "Phone",
            linkgeneric = "modals/phone/callLog.lp",
            pid = "Phone",
            allowedcountry = "NZ,ES,VHA"
        }, {
            id = "3",
            label = T "Internet",
            linkgeneric = "modals/internet/mobile.lp",
            linkvox = "modals/internet/firewall.lp",
            pid = "Internet",
            allowedcountry = "ES,NZ,VHA,VF-UK"
        }, {
            id = "4",
            label = T "Wi-Fi",
            linkgeneric = "modals/wifi/general.lp",
            pid = "WiFi",
            allowedcountry = "ES,VF-UK,NZ,VHA"
        },{
            id = "5",
            label = T "Sharing",
            linkgeneric = "modals/sharing/sharing.lp",
            pid = "Sharing",
            allowedcountry = "VF-UK"
        },{
            id = "6",
            label = T "Settings",
            linkgeneric = "modals/settings/password.lp",
            pid = "Settings",
            allowedcountry = "ES,VF-UK,NZ,VHA"
        }, {
            id = "7",
            label = T "Status & Support",
            linkgeneric = "modals/status-support/status.lp",
            pid = "StatusSupport",
            allowedcountry = "ES,VF-UK,NZ,VHA"
        }
    },
    menu = {
            Overview = {
                    {
                        idgeneric = "1",
                        parentidgeneric = "-1",
                        textgeneric = T "Overview",
                        link = "modals/overview.lp",
                        pid = "Overview"
                    }
                },
                Phone = {
                    {
                        idgeneric = "1",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Call Log",
                        link = "modals/phone/callLog.lp",
                        pid = "call-log",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "2",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "Ringing Schedule",
                        link = "modals/phone/ringingSchedule.lp",
                        pid = "ringing-schedule",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "3",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "Phone Numbers",
                        link = "modals/phone/numbers.lp",
                        pid = "phone-numbers",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "4",
                        parentidgeneric = "3",
                        parentidnz = "-1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "Phone Settings",
                        link = "modals/phone/settings.lp",
                        pid = "phone-settings",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "5",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        modenz = "35",
                        textgeneric = T "Call Settings",
                        link = "modals/phone/callSettings.lp",
                        pid = "call-settings",
                        allowedcountry = "VHA,NZ,ES"
                    }
                },
                Internet = {
                    {
                        idgeneric = "1",
                        idvox = "5",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        modevox = "34",
                        textgeneric = T "Mobile",
                        textvox = T "Mobile Data (3G/4G)",
                        link = "modals/internet/mobile.lp",
                        pid = "mobile",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "2",
                        idvox = "1",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modevox = "33",
                        modenz = "34",
                        textgeneric = T "Firewall",
                        link = "modals/internet/firewall.lp",
                        pid = "firewall",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "3",
                        idvox = "2",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "Port Mapping",
                        link = "modals/internet/portMapping.lp",
                        pid = "port-mapping",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "4",
                        idvox = "3",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "DMZ",
                        textvox = T "Static NAT/DMZ",
                        link = "modals/internet/dmz.lp",
                        pid = "dmz",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "5",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "Parental Control",
                        link = "modals/internet/parentalControl.lp",
                        pid = "parental-ctrl",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "6",
                        idvox = "4",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "DNS & DDNS",
                        link = "modals/internet/dns_ddns.lp",
                        pid = "dns-ddns",
                        allowedcountry = "VHA,NZ,ES,VF-UK"
                    }, {
                        idgeneric = "7",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "UPnP",
                        link = "modals/internet/upnp.lp",
                        pid = "upnp",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                    idgeneric= "9",
                    parentidgeneric= "-1",
                    modegeneric= "33",
                    text= T"ADSL Configuration",
                    textgeneric = "ADSL Configuration",
                    link = "modals/settings/pppoa.lp",
                    pid="pppoa",
                    allowedcountry = "NZ"
                    }
                },
                WiFi = {
                    {
                        idgeneric = "1",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "General",
                        link = "modals/wifi/general.lp",
                        pid = "wifi-general",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "2",
                        idnz = "3",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Power Saving Mode",
                        textvox = T "Schedule",
                        link = "modals/wifi/powerSaving.lp",
                        pid = "power-saving-mode",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "3",
                        idnz = "4",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "WPS",
                        link = "modals/wifi/wps.lp",
                        pid = "wps",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "4",
                        idnz = "5",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "MAC Filter",
                        link = "modals/wifi/macFilter.lp",
                        pid = "mac-filter",
                        allowedcountry = "VHA,NZ,ES,VF-UK"
                    }, {
                        idgeneric = "5",
                        idnz = "6",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modevox = "34",
                        modenz = "34",
                        textgeneric = T "Settings",
                        link = "modals/wifi/settings.lp",
                        pid = "settings",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "6",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "VF WiFi network",
                        link = "modals/wifi/vf_wifi_network.lp",
                        pid = "wifi-network",
                        allowedcountry = "VHA,ES"
                    }, {
                        idgeneric = "7",
                        idnz = "7",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "33",
                        textgeneric = T "Analyser",
                        link = "modals/wifi/analyser.lp",
                        pid = "analyser",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "8",
                        idnz = "8",
                        parentidgeneric = "7",
                        modegeneric = "35",
                        modenz = "33",
                        textgeneric = T "2.4GHz",
                        link = "modals/wifi/analyser.lp",
                        pid = "analyser24",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "9",
                        idnz = "9",
                        parentidgeneric = "7",
                        modegeneric = "35",
                        modenz = "33",
                        textgeneric = T "5GHz",
                        link = "modals/wifi/analyser.lp",
                        pid = "analyser5",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "10",
                        idnz = "10",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "Client Monitoring",
                        link = "modals/wifi/clientMonitoring.lp",
                        pid = "client-monitor",
                        allowedcountry = "VHA,NZ,ES"
                   }, {
                        idgeneric = "11",
                        parentidgeneric = "-1",
                        modegeneric= "33",
                        modenz = "33",
                        textgeneric= T"Band Steering",
                        link= "modals/wifi/bandSteer.lp",
                        pid="wifi-bandSteer",
                        allowedcountry = "VHA,ES"
                    }, {
                        idgeneric = "12",
                        idnz = "2",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        modenz = "33",
                        textnz = T "Reminder Card",
                        link = "modals/wifi/reminderCard.lp",
                        pid = "reminder-card",
                        allowedcountry = "NZ"
                   }
                },
                Settings = {
                    {
                        idgeneric = "1",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Password",
                        link = "modals/settings/password.lp",
                        pid = "password",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "2",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modevox = "34",
                        modenz = "34",
                        textgeneric = T "Firmware Update",
                        link = "modals/settings/firmwareUpdate.lp",
                        pid = "firmware-update",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "3",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Energy Settings",
                        textgeneric = T "LED Settings",
                        link = "modals/settings/energySettings.lp",
                        pid = "energy-settings",
                        allowedcountry = "VHA,VF-UK,ES"
                    }, {
                        idgeneric = "4",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        modevox = "34",
                        textgeneric = T "Configuration",
                        link = "modals/settings/configuration.lp",
                        pid = "configuration",
                        allowedcountry = "VHA,NZ,ES,VF-UK"
                    }, {
                        idgeneric = "5",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "Public Subnet",
                        link = "modals/settings/publicSubnet.lp",
                        pid = "publicSubnet",
                        allowedcountry = "VF-UK"
                    }, {
                        idgeneric = "6",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "LAN",
                        textvox = T "Local Network",
                        link = "modals/settings/lan.lp",
                        pid = "lan",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "7",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        textgeneric = T "QoS",
                        link = "modals/settings/qos.lp",
                        pid = "qos",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "8",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "Internet Time",
                        link = "modals/settings/internetTime.lp",
                        pid = "internet-time",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "9",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        textgeneric = T "TR-069",
                        link = "modals/settings/tr069.lp",
                        pid = "tr-069",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "10",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "35",
                        textgeneric = T "Access Control",
                        link = "modals/settings/accessControl.lp",
                        pid = "acces-control",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "11",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        textgeneric = T "xDSL",
                        link = "modals/settings/xdsl.lp",
                        pid = "xdsl",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "12",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "WAN",
                        link = filepath,
                        pid = "wan",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "13",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "Ipv6 Basic Configuration",
                        link = "modals/settings/ipv6Configuration.lp",
                        pid = "ipv6-basic-config",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "14",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "Static Routing",
                        link = "modals/settings/staticRouting.lp",
                        pid = "static-routing",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "15",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "Policy Routing",
                        link = "modals/settings/policyRouting.lp",
                        pid = "policy-routing",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "16",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Content Sharing",
                        link = "modals/settings/contentSharing.lp",
                        pid = "content-sharing",
                        allowedcountry = "VHA,ES"
                    }, {
                        idgeneric = "17",
                        parentidgeneric = "16",
                        parentidnz = "-1",
                        modegeneric = "33",
                        modegeneric = "34",
                        textgeneric = T "DLNA",
                        link = "modals/settings/dlna.lp",
                        pid = "DLNA",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "18",
                        parentidgeneric = "16",
                        parentidnz = "-1",
                        modegeneric = "34",
                        textgeneric = T "Samba",
                        link = "modals/settings/samba.lp",
                        pid = "samba",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "19",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        modenz = "34",
                        textgeneric = T "Printer Sharing",
                        link = "modals/settings/printerSharing.lp",
                        pid = "printer-sharing",
                        allowedcountry = "VHA,ES,NZ"
                    }, {
                        idgeneric = "20",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Mobile",
                        link = "modals/settings/mobile.lp",
                        pid = "mobile-settings",
                        allowedcountry = "VHA,ES"
                    }, {
                        idgeneric = "21",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        modenz = "34",
                        textgeneric = T "USB",
                        link = "modals/settings/usb.lp",
                        pid = "usb",
                        allowedcountry = "VHA,ES,NZ"
                    }, {
                        idgeneric = "22",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        textgeneric = T "TV Settings",
                        link = "modals/settings/tvSettings.lp",
                        pid = "tv-settings",
                        allowedcountry = "VHA,ES"
                    }, {
                        idgeneric = "23",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "Assistance",
                        link = "modals/settings/assistance.lp",
                        pid = "assistance",
                        allowedcountry = "NZ"
                    }, {
                        idgeneric = "24",
                        parentidgeneric = "-1",
                        modegeneric = "34",
                        textgeneric = T "MAC Filter",
                        link = "modals/settings/macFilter.lp",
                        pid = "mac-filter",
                        allowedcountry = "VF-UK"
                     }
                },
                Sharing = {
                    {
                        idgeneric = "1",
                        parentidvox = "-1",
                        modevox = "33",
                        textvox = T"Sharing",
                        link = "modals/sharing/sharing.lp",
                        pid ="sharing",
                        allowedcountry = "VF-UK"
                    }, {
                        idgeneric = "2",
                        parentidvox = "-1",
                        modevox = "34",
                        textvox = T"Sharing-Settings",
                        link = "modals/sharing/settings.lp",
                        pid ="sharingSettings",
                        allowedcountry = "VF-UK"
                    }
                },
                StatusSupport = {
                    {
                        idgeneric = "1",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Status",
                        link = "modals/status-support/status.lp",
                        pid = "status",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "2",
                        parentidgeneric = "1",
                        modegeneric = "33",
                        textgeneric = T "Voice Status",
                        link = "modals/status-support/voiceStatus.lp",
                        pid = "voice-status",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "3",
                        parentidgeneric = "1",
                        modegeneric = "35",
                        modenz = "33",
                        modevox = "33",
                        textgeneric = T "VDSL Status",
                        textnz = T "xDSL Status",
                        textvox = T "DSL Status",
                        link = "modals/status-support/vdslStatus.lp",
                        pid = "adsl-status",
                        allowedcountry = "VHA,NZ,ES,VF-UK"
                    }, {
                        idgeneric = "4",
                        parentidgeneric = "1",
                        modegeneric = "35",
                        modenz = "33",
                        textgeneric = T "WAN Status",
                        link = "modals/status-support/wanStatus.lp",
                        pid = "wan-status",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "5",
                        parentidgeneric = "1",
                        modegeneric = "35",
                        modenz = "33",
                        textgeneric = T "LAN Status",
                        link = "modals/status-support/lanStatus.lp",
                        pid = "lan-status",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "6",
                        parentidgeneric = "1",
                        modegeneric = "35",
                        modenz = "34",
                        textgeneric = T "Routing",
                        link = "modals/status-support/routing.lp",
                        pid = "routing",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "7",
                        parentidgeneric = "1",
                        modegeneric = "35",
                        modevox = "34",
                        textgeneric = T "Fibre Status",
                        link = "modals/status-support/fibreStatus.lp",
                        pid = "fibre-status",
                        allowedcountry = "VHA,VF-UK,ES"
                    }, {
                        idgeneric = "8",
                        parentidgeneric = "1",
                        modegeneric = "35",
                        modevox = "34",
                        modenz = mobileshow,
                        textgeneric = T "Mobile Status",
                        link = "modals/status-support/mobileStatus.lp",
                        pid = "mobile-status",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "9",
                        idvox = "10",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Diagnostic Utility",
                        link = "modals/status-support/diagnosticUtility.lp",
                        pid = "diagnostic-utility",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "10",
                        idvox = "11",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modevox = "34",
                        modenz = "34",
                        textgeneric = T "Event Log",
                        link = "modals/status-support/eventLog.lp",
                        pid = "event-log",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "11",
                        idvox = "12",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "Restart",
                        link = "modals/status-support/restart.lp",
                        pid = "restart",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "12",
                        idvox = "9",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        modevox = "34",
                        modenz = "34",
                        textgeneric = T "NAT Mapping Table",
                        link = "modals/status-support/natMappingTable.lp",
                        pid = "nat-mapping",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }, {
                        idgeneric = "13",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        textgeneric = T "VOIP Diagnostic",
                        link = "modals/status-support/voipDiagnostic.lp",
                        pid = "voip-diagnostic",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "14",
                        parentidgeneric = "-1",
                        modegeneric = "35",
                        textgeneric = T "Port Mirroring",
                        link = "modals/status-support/portMirroring.lp",
                        pid = "port-mirroring",
                        allowedcountry = "VHA,NZ,ES"
                    }, {
                        idgeneric = "15",
                        parentidgeneric = "-1",
                        modegeneric = "33",
                        textgeneric = T "About",
                        link = "modals/status-support/about.lp",
                        pid = "about",
                        allowedcountry = "VHA,NZ,VF-UK,ES"
                    }
                }
        }
}
if content.variant == "VHA" then
  menuTbl.menu.Internet[#menuTbl.menu.Internet + 1 ] = {id= "2",  parentidgeneric= "-1", modegeneric=  "", textgeneric= T"DSL",  link= "modals/internet/dsl.lp", pid="dsl"}
elseif content.variant == "VF-UK" then
  menuTbl.menu.Settings[#menuTbl.menu.Settings + 1 ] = {idgeneric = "2",parentidgeneric = "-1", modegeneric = "35", modevox = "34", modenz = "34", textgeneric = T "Firmware Version",link = "modals/settings/firmwareUpdate.lp",pid = "firmware-version",allowedcountry = "VF-UK"}
end
local json = require("dkjson")
local buffer = {}
json.encode (menuTbl, {indent = false, buffer = buffer })
ngx.print(buffer)
ngx.exit(ngx.HTTP_OK)
  ngx.print('\
'); 
