-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT, runFunc, uci, ubus, print, get_depending_led, is_WiFi_LED_on_if_NSC, is_show_remote_mgmt, xdsl_status = timerLed, staticLed, netdevLed, netdevLedOWRT, runFunc, uci, ubus, print, get_depending_led, is_WiFi_LED_on_if_NSC, is_show_remote_mgmt, xdsl_status
local wl1_ifname = get_wl1_ifname()
local itf_depending_led

local function find_itf_depending_led(parms)
   local led=get_depending_led(parms.itf)
   if led then
      itf_depending_led=(led..":"..parms.color or "green")
   else
      itf_depending_led=nil
   end
end

local function get_itf_depending_led()
   return itf_depending_led
end

local wifi_led_nsc = is_WiFi_LED_on_if_NSC()

local function WiFiLedIfNoStationsConnected()
   return wifi_led_nsc
end


local WiFi_2p4G_sta_con = false
local WiFi_5G_sta_con = false
local WiFi_2p4G_on = false
local WiFi_5G_on = false
local WiFi_err = false

local function WiFiItfs()
   local netdev_itfs = 'none'
   if WiFi_2p4G_on and WiFi_5G_on then
      if wifi_led_nsc then 
	 netdev_itfs='wl0 wl1'
      elseif WiFi_2p4G_sta_con and WiFi_5G_sta_con then
         netdev_itfs='wl0 wl1'
      elseif WiFi_2p4G_sta_con then
         netdev_itfs='wl0'
      elseif WiFi_5G_sta_con then
         netdev_itfs='wl1'
      end
   elseif WiFi_2p4G_on and (WiFi_2p4G_sta_con or wifi_led_nsc) then
      netdev_itfs='wl0'
   elseif WiFi_5G_on and (WiFi_5G_sta_con or wifi_led_nsc) then
      netdev_itfs='wl1'
   end
   return WiFi_err and 'none' or netdev_itfs
end

-- 1-state name for wifi/WPS led
local WiFiInitialState = "wifi_wps_all"

-- fixed names are entries in /sys/class/leds/<led name>:<led colour>
local WiFiLedGreenName = "wireless:green"
local WiFiLedRedName = "wireless:red"
local WiFiLedOrangeName = "wireless:orange"

-- Should a timerLed be activated ? If set to false, it can be netdev LED or static LED (The intention is to activate only one type (static, timer, netdev) at a time)
local WiFiTimerLedRed = false
local WiFiTimerLedGreen = false
local WiFiTimerLedOrange = false

local WiFiNetDevLedRed = false
local WiFiNetDevLedGreen = true
local WiFiNetDevLedOrange = false
local WiFi_delay_on = 100
local WiFi_delay_off = 100

-- orange LED : do not use aggregate led wireless:orange, but drive both composing colours leds individually.
-- Reason : aggregate LEDs have one common intensity (brightness) for both colours;
-- If you drive both LEDs separately, they will each be activated with their own (possibly different) intensity
-- e.g. ; best result for orange is red with intensity (brightness) 5, and green brightness 1

-- Only used in staticLed() to determine 'on' (true) or 'off' (false)
local WiFiLed = "off"

local function WiFiLedGreen()
   return WiFiLed == "green" or WiFiLed == "orange"
end

local function WiFiLedRed()
   return WiFiLed == "red" or WiFiLed == "orange" or WiFi_err
end

local function WiFiLedOrange()
   return WiFiLed == "orange"
end
--

local function WiFiStaticLedGreenName()
   return not (WiFiTimerLedGreen or WiFiTimerLedOrange) and not (WiFiNetDevLedGreen or WiFiNetDevLedOrange) and WiFiLedGreenName or nil 
end

local function WiFiStaticLedRedName()
   return not (WiFiTimerLedRed or WiFiTimerLedOrange) and not (WiFiNetDevLedRed or WiFiNetDevLedOrange) and WiFiLedRedName or nil 
end

local function WiFiStaticLedOrangeName()
   return not WiFiTimerLedOrange  and not WiFiNetDevLedOrange and WiFiLedOrangeName or nil 
end

local function WiFiTimerLedGreenName()
   return (WiFiTimerLedGreen or WiFiTimerLedOrange) and not (WiFiNetDevLedGreen or WiFiNetDevLedOrange) and WiFiLedGreenName or nil 
end

local function WiFiTimerLedRedName()
   return (WiFiTimerLedRed or WiFiTimerLedOrange) and not (WiFiNetDevLedRed or WiFiNetDevLedOrange) and WiFiLedRedName or nil 
end

local function WiFiTimerLedOrangeName()
   return WiFiTimerLedOrange and not WiFiNetDevLedOrange and WiFiLedOrangeName or nil 
end

local function WiFiNetDevLedGreenName()
   return (WiFiNetDevLedGreen or WiFiNetDevLedOrange) and WiFiLedGreenName or nil 
end

local function WiFiNetDevLedRedName()
   return (WiFiNetDevLedRed or WiFiNetDevLedOrange) and WiFiLedRedName or nil 
end

local function WiFiNetDevLedOrangeName()
   return WiFiNetDevLedOrange and WiFiLedOrangeName or nil 
end

local function WiFiLEDMode()
   return  (WiFi_2p4G_sta_con or WiFi_5G_sta_con) and 'link tx rx' or 'link'
end

local function WiFiDelayOn()
   return WiFi_delay_on
end

local function WiFiDelayOff()
   return WiFi_delay_off
end

local function CheckConditionsWiFi()
end


local function WiFiNewState (event)
   local newWiFiState= WiFiInitialState
   if event == "sta_con_wl0" then
      WiFi_2p4G_sta_con = true
   elseif event == "no_sta_con_wl0" then
      WiFi_2p4G_sta_con = true
   elseif event == "sta_con_wl1" then
      WiFi_5G_sta_con = true
   elseif event == "no_sta_con_wl1" then
      WiFi_5G_sta_con = true
   elseif event == "2p4G_on" then
      WiFi_2p4G_on = true
   elseif event == "5G_on" then
      WiFi_5G_on = true
   elseif event == "off" then
      WiFi_2p4G_on = false
      WiFi_5G_on = false
      WiFi_5G_sta_con = false
      WiFi_2p4G_sta_con = false
   elseif event == "2p4G_off" then
      WiFi_2p4G_on = false
      WiFi_2p4G_sta_con = false
   elseif event == "5G_off" then
      WiFi_5G_on = false
      WiFi_5G_sta_con = false
   elseif event == "err" then
      WiFi_err = true
   elseif event == "no_err" then
      WiFi_err = false
   elseif event == "wps_off" or event == "wps_idle" or event == "wps_success" then
      WiFiNetDevLedGreen = true
      WiFiTimerLedGreen = false
      WiFiTimerLedRed = false
      WiFiTimerLedOrange = false
      WiFiLed = "off"
   elseif event == "wps_inprogress" then
      WiFiNetDevLedGreen = false
      WiFiTimerLedOrange = true
      WiFi_delay_on = 200
      WiFi_delay_off = 100
   elseif event == "wps_error" then
      WiFiTimerLedOrange = false
      WiFiTimerLedRed = true
      WiFi_delay_on = 100
      WiFi_delay_off = 100
   elseif event == "wps_session_overlap" then
      WiFiTimerLedOrange = false
      WiFiTimerLedRed = true
      WiFi_delay_on = 1000
      WiFi_delay_off = 1000
   elseif event == "wps_setup_locked" then
      WiFiTimerLedOrange = false
      WiFiTimerLedRed = false
      WiFiTimerLedGreen = false
      WiFi_delay_on = 100
      WiFi_delay_off = 100
      WiFiLed = "green"
   end
--   CheckConditionsWiFi()
   return newWiFiState
end

-- When both xdsl and ethwan is connected and when eth4 is unplugged
-- eth4_down event will be received from the net link
-- however since xdsl is present, the internet LED behavior must not be modified
-- this is exceptional to few scenarios where eth4 is used as LAN/WAN port
-- hence always check the xdsl status before acting on the eth4_down event
local function internet_nextState()
   return ((xdsl_status() ~= 5) and "internet_disconnected" or nil)
end

patterns = {
    status = {
        state = "status_inactive",
        transitions = {
            status_inactive = {
                status_ok = "status_active",
            },
            status_active = {
                status_nok = "status_inactive",
            },
        },
        actions = {
            status_active = {
                staticLed("broadband:red", false),
                staticLed("broadband:green", false),
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("voip:green", false)
            },
        }
    },
    remote_mgmt = {
        state = "remote_mgmt_session_ends",
        transitions = {
            remote_mgmt_session_ends = {
                remote_mgmt_session_begins = "remote_mgmt_session_begins",
            },
            remote_mgmt_session_begins = {
                remote_mgmt_session_ends = "remote_mgmt_session_ends"
            }
        },
        actions = {
            remote_mgmt_session_begins = {
                timerLed("power:green", 50, 50)
            }
        }
    }
}

if not is_show_remote_mgmt() then patterns.remote_mgmt=nil end

stateMachines = {
    power = {
        initial = "power_started",
        transitions = {
            power_started = {
                power_service_eco = "service_ok_eco",
                power_service_fullpower = "service_ok_fullpower",
                power_service_notok = "service_notok"
            },
            service_ok_eco = {
                power_service_fullpower = "service_ok_fullpower",
                power_service_notok = "service_notok"
            },
            service_ok_fullpower = {
                power_service_eco = "service_ok_eco",
                power_service_notok = "service_notok"
            },
            service_notok = {
                power_service_fullpower = "service_ok_fullpower",
                power_service_eco = "service_ok_eco"
            }
        },
        actions = {
            power_started = {
                staticLed("power:red", false),
                staticLed("power:green", true)
            },
            service_ok_eco = {
                staticLed("power:red", false),
                staticLed("power:green", true)
            },
            service_ok_fullpower = {
                staticLed("power:red", false),
                staticLed("power:green", true)
            },
            service_notok = {
                staticLed("power:red", true),
                staticLed("power:green", false)
            }
        },
        patterns_depend_on = {
            power_started = { "remote_mgmt" },
            service_ok_eco = { "remote_mgmt" },
            service_ok_fullpower = { "remote_mgmt" },
            service_notok = { "remote_mgmt" }
        }
    },
    broadband = {
        initial = "idling",
        transitions = {
            idling = {
                xdsl_1 = "training",
                xdsl_2 = "synchronizing",
                xdsl_6 = "synchronizing",
            },
            training = {
                xdsl_0 = "idling",
                xdsl_2 = "synchronizing",
                xdsl_6 = "synchronizing",
            },
            synchronizing = {
                xdsl_0 = "idling",
                xdsl_1 = "training",
                xdsl_5 = "connected",
            },
            connected = {
                xdsl_0 = "idling",
                xdsl_1 = "training",
                xdsl_2 = "synchronizing",
                xdsl_6 = "synchronizing",
            },
        },
        actions = {
            idling = {
                staticLed("broadband:red", false),
                netdevLed("broadband:green", 'eth4', 'link'),
            },
            training = {
                timerLed("broadband:green", 250, 250)
            },
            synchronizing = {
                timerLed("broadband:green", 125, 125)
            },
            connected = {
                staticLed("broadband:green", true)
            },
        },
        patterns_depend_on = {
            idling = {"status"},
            training = {"status"},
            synchronizing = {"status"},
            connected = {"status"},
        }
    },
    internet = {
        initial = "internet_disconnected",
        transitions = {
            internet_disconnected = {
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
                network_interface_broadband_ifup = "internet_connecting",
                xdsl_5 = "internet_connecting",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan6_ppp_connecting = "internet_connecting"
            },
            internet_connecting = {
                network_interface_broadband_ifdown = "internet_disconnected",
                xdsl_0 = "internet_disconnected",
                network_device_eth4_down = internet_nextState,
--                network_interface_wan_ifdown = "internet_disconnected",
--                network_interface_wan6_ifdown = "internet_disconnected",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
                network_interface_wan_ppp_disconnected = "internet_disconnected",
                network_interface_wan6_ppp_disconnected = "internet_disconnected"
            },
            internet_connected_ipv4_or_v6 = {
                xdsl_0 = "internet_disconnected",
                network_device_eth4_down = internet_nextState,
                xdsl_1 = "internet_connected_ipv4_or_v6_ddbdd",
                xdsl_2 = "internet_connected_ipv4_or_v6_ddbdd",
                network_interface_wan_ifdown = "internet_connecting",
                network_interface_wan6_ifdown = "internet_connecting",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan6_ifup = "internet_connected_ipv4_and_v6",
                network_interface_wan_ifup = "internet_connected_ipv4_and_v6",
                network_interface_wan_no_ip = "internet_connecting",
                network_interface_wan6_no_ip = "internet_connecting"
            },
            internet_connected_ipv4_and_v6 = {
                xdsl_0 = "internet_disconnected",
                network_device_eth4_down = internet_nextState,
                xdsl_1 = "internet_connected_ipv4_and_v6_ddbdd",
                xdsl_2 = "internet_connected_ipv4_and_v6_ddbdd",
                network_interface_wan_ifdown = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifdown = "internet_connected_ipv4_or_v6",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_no_ip = "internet_connected_ipv4_or_v6",
                network_interface_wan6_no_ip = "internet_connected_ipv4_or_v6"
            },
-- Handle spurious DSL activations : do not switch to internet_disconnected state if a DSL idle (xdsl_0) is preceded by a DSL activation (xdsl_1 or xdsl_2)
-- (e.g Can happen in ETHWAN scenario with no DSL line connected)
-- Go back to original state when DSL idle (xdsl_0) received
-- In the DSL WAN scenario, when DSL is up, you cannot have an activation followed by and idle
-- 'ddbdd' stands for 'Don't Disconnect By DSL Down'
            internet_connected_ipv4_or_v6_ddbdd = {
                xdsl_0 = "internet_connected_ipv4_or_v6",
                network_interface_wan_ifdown = "internet_connecting",
                network_interface_wan6_ifdown = "internet_connecting",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan6_ifup = "internet_connected_ipv4_and_v6_ddbdd",
                network_interface_wan_ifup = "internet_connected_ipv4_and_v6_ddbdd",
                network_interface_wan_no_ip = "internet_connecting",
                network_interface_wan6_no_ip = "internet_connecting"
            },
            internet_connected_ipv4_and_v6_ddbdd = {
                xdsl_0 = "internet_connected_ipv4_and_v6",
                network_interface_wan_ifdown = "internet_connected_ipv4_or_v6_ddbdd",
                network_interface_wan6_ifdown = "internet_connected_ipv4_or_v6_ddbdd",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_no_ip = "internet_connected_ipv4_or_v6_ddbdd",
                network_interface_wan6_no_ip = "internet_connected_ipv4_or_v6_ddbdd"
            },
            internet_connected_mobiledongle = {
                network_interface_wwan_ifdown = "internet_disconnected",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6"
            }
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                runFunc(find_itf_depending_led,{itf='wan',color='green'}),
                staticLed(get_itf_depending_led, false)
            },
            internet_connecting = {
                staticLed("internet:green", false),
-- timerLed("internet:red", 500, 500), was not behaving as expected; using same values since last time when setting timerLed for same LED can cause LED *NOT* to blink at all;
-- Probably LED driver problem; workaround is setting twice with different values
                timerLed("internet:red", 500, 500),
            },
            internet_connected_ipv4_or_v6 = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false),
                runFunc(find_itf_depending_led,{itf='wan',color='green'}),
                staticLed(get_itf_depending_led, true)
            },
            internet_connected_ipv4_and_v6 = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false)
            },
            internet_connected_ipv4_or_v6_ddbdd = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false)
            },
            internet_connected_ipv4_and_v6_ddbdd = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false)
            },
            internet_connected_mobiledongle = {
                netdevLedOWRT("internet:green", 'wwan', 'link tx rx'),
                staticLed("internet:red", false),
                runFunc(find_itf_depending_led,{itf='wan',color='green'}),
                staticLed(get_itf_depending_led, true)
            },
        },
        patterns_depend_on = {
            internet_disconnected = {"status"},
            internet_connecting = {"status"},
            internet_connected_ipv4_and_v6 = {"status"},
            internet_connected_ipv4_or_v6 = {"status"},
            internet_connected_ipv4_and_v6_ddbdd = {"status"},
            internet_connected_ipv4_or_v6_ddbdd = {"status"},
            internet_connected_mobiledongle = {"status"}
        }
    },
    voice = {
        initial = "off",
        transitions = {
            fxs_profiles_usable = {
			fxs_lines_error = "off",
			fxs_lines_usable_off = "off",
			fxs_active = "fxs_profiles_flash",
			fxs_inactive = "fxs_profiles_solid",
			fxs_lines_usable_idle = "off",
            },
            fxs_profiles_solid = {
			fxs_active = "fxs_profiles_flash",
			fxs_inactive = "fxs_profiles_usable",
		    fxs_lines_error = "off",
			fxs_lines_usable_off = "off",
			fxs_lines_usable_idle = "off",
            },
            fxs_profiles_flash = {
			fxs_inactive = "fxs_profiles_solid",
			fxs_active  = "fxs_profiles_flash",
			fxs_lines_error = "off",
			fxs_lines_usable_idle = "off",
            },
            off = {
			fxs_lines_usable = "fxs_profiles_usable",
			fxs_lines_error = "off",
			fxs_lines_usable_off = "off",
			fxs_lines_usable_idle = "off",
            }
        },
        actions = {
            fxs_profiles_usable = {
			staticLed("voip:green", true)
            },
            fxs_profiles_solid = {
			staticLed("voip:green", true)
            },
            fxs_profiles_flash = {
			timerLed("voip:green", 100, 100)
            },
            off = {
			staticLed("voip:green", false)
            }
        },
        patterns_depend_on = {
            fxs_profiles_usable = {
                 "status"
            },
            fxs_profiles_solid = {
                 "status"
            },
            fxs_profiles_flash = {
                 "status"
            },
            off = {
                 "status"
            }
        }
    },
    wifi_wps = {
        initial = "wifi_wps_all",
        transitions = {
            wifi_wps_all = {
                wifi_sta_con_wl0 = {WiFiNewState,"sta_con_wl0"},
                wifi_no_sta_con_wl0 = {WiFiNewState,"no_sta_con_wl0"},
                wifi_sta_con_wl1 = {WiFiNewState,"sta_con_wl1"},
                wifi_no_sta_con_wl1 = {WiFiNewState,"no_sta_con_wl1"},
                wifi_security_wpapsk_wl0 = {WiFiNewState,"2p4G_on"},
                wifi_security_wpa_wl0 = {WiFiNewState,"2p4G_on"},
                wifi_security_wep_wl0 = {WiFiNewState,"2p4G_on"},
                wifi_security_disabled_wl0 = {WiFiNewState,"2p4G_on"},
                wifi_security_wpapsk_wl1 = {WiFiNewState,"5G_on"},
                wifi_security_wpa_wl1 = {WiFiNewState,"5G_on"},
                wifi_security_wep_wl1 = {WiFiNewState,"5G_on"},
                wifi_security_disabled_wl1 = {WiFiNewState,"5G_on"},
                wifi_leds_off = {WiFiNewState,"off"},
                wifi_state_off_wl0 = {WiFiNewState,"2p4G_off"},
                wifi_state_off_wl1 = {WiFiNewState,"5G_off"},
                ip_address_conflict_wl = {WiFiNewState,"err"},
                no_ip_address_conflict_wl = {WiFiNewState,"no_err"},
                wifi_wps_off = {WiFiNewState,"wps_off"},
                wifi_wps_idle = {WiFiNewState,"wps_idle"},
                wifi_wps_inprogress = {WiFiNewState,"wps_inprogress"},
                wifi_wps_error = {WiFiNewState,"wps_error"},
                wifi_wps_session_overlap = {WiFiNewState,"wps_session_overlap"},
                wifi_wps_setup_locked = {WiFiNewState,"wps_setup_locked"},
                wifi_wps_success = {WiFiNewState,"wps_success"}
            },
        },
        actions = {
            wifi_wps_all = {
                staticLed(WiFiStaticLedRedName, WiFiLedRed),
                staticLed(WiFiStaticLedGreenName, WiFiLedGreen),
--                staticLed(WiFiStaticLedOrangeName, WiFiLedOrange),
                netdevLed(WiFiNetDevLedGreenName, WiFiItfs, WiFiLEDMode, 125, 1),
                timerLed(WiFiTimerLedRedName, WiFiDelayOn, WiFiDelayOff),
                timerLed(WiFiTimerLedGreenName, WiFiDelayOn, WiFiDelayOff),
--                timerLed(WiFiTimerLedOrangeName, WiFiDelayOn, WiFiDelayOff),
            },
        },
        patterns_depend_on = {
            wifi_wps_all = {"status"},
        },
    },
}
