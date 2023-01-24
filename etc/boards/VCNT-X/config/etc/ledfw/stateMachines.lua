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
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("ethernet:green", false),
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:orange", false),
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
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
            },
            service_ok_eco = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
            },
            service_ok_fullpower = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
            },
            service_notok = {
                staticLed("power:orange", false),
                staticLed("power:red", true),
                staticLed("power:blue", false),
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
                netdevLed("mobile:green", 'eth4', 'link'),
            },
            training = {
                timerLed("mobile:green", 250, 250)
            },
            synchronizing = {
                timerLed("mobile:green", 125, 125)
            },
            connected = {
                staticLed("mobile:green", true)
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
                timerLed("internet:red", 498, 502),
                timerLed("internet:red", 499, 501),
                staticLed(get_itf_depending_led, false)
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
    ethernet = {
        initial = "ethernet",
        transitions = {
        },
        actions = {
            ethernet = {
                netdevLed("ethernet:green", 'eth0 eth1 eth2 eth3', 'link tx rx')
            }
        },
        patterns_depend_on = {
            ethernet = {
                "status"
            }
        }
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_sta_con_wl0 = "wifi_on_sc",
                wifi_sta_con_wl1 = "wifi_on_sc",
                wifi_no_sta_con_wl0 = "wifi_on_nsc",
                wifi_no_sta_con_wl1 = "wifi_on_nsc",
            },
            wifi_on_nsc = {
                wifi_state_off_wl0 = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_acl_on_wl0 = "wifi_acl",
                wifi_acl_on_wl1 = "wifi_acl",
                wifi_sta_con_wl0 = "wifi_on_sc",
                wifi_sta_con_wl1 = "wifi_on_sc",
            },
            wifi_on_sc = {
                wifi_state_off_wl0 = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_acl_on_wl0 = "wifi_acl",
                wifi_acl_on_wl1 = "wifi_acl",
                wifi_no_sta_con_wl0 = "wifi_on_nsc",
                wifi_no_sta_con_wl1 = "wifi_on_nsc",
            },
            wifi_acl = {
                wifi_acl_off_wl0 = "wifi_off",
                wifi_acl_off_wl1 = "wifi_off",
            }
        },
        actions = {
            wifi_off = {
                staticLed("wireless:green", false),
            },
            wifi_on_nsc = {
                staticLed("wireless:green", wifi_led_nsc),
            },
            wifi_on_sc = {
                netdevLed("wireless:green", 'wl0 wl1', 'link tx rx')
            },
            wifi_acl = {
                timerLed("wireless:green", 498, 502),
                timerLed("wireless:green", 499, 501)
            }
        },
        patterns_depend_on = {
            wifi_off = {
                "status"
            },
            wifi_on_nsc = {
                "status"
            },
            wifi_on_sc = {
                "status"
            },
            wifi_acl = {
                "status"
            }
        }
    },
    wps = {
        initial = "off",
        transitions = {
            idle = {
                wifi_wps_inprogress = "inprogress",
                wifi_wps_off = "off"
            },
            inprogress = {
                wifi_wps_error = "error",
                wifi_wps_session_overlap = "session_overlap",
                wifi_wps_setup_locked = "setup_locked",
                wifi_wps_off = "off",
                wifi_wps_idle = "idle",
                wifi_wps_success = "success"
            },
            success = {
                wifi_wps_idle = "idle",
                wifi_wps_off = "off",
                wifi_wps_error = "error",
                wifi_wps_session_overlap = "session_overlap",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_setup_locked = "setup_locked"
            },
            setup_locked = {
                wifi_wps_off = "off",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            },
            error = {
                wifi_wps_off = "off",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            },
            session_overlap = {
                wifi_wps_off = "off",
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            },
            off = {
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            }
        },
        actions = {
            idle = {
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                staticLed("dect:green", false),
            },
            session_overlap = {
                staticLed("dect:orange", false),
                timerLed("dect:red", 1000, 1000),
                staticLed("dect:green", false),
            },
            error = {
                staticLed("dect:orange", false),
                timerLed("dect:red", 100, 100),
                staticLed("dect:green", false),
            },
            setup_locked = {
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                staticLed("dect:green", true),
            },
            off = {
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                staticLed("dect:green", false),
            },
            inprogress = {
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                timerLed("dect:orange", 200, 100),
            },
            success = {
                staticLed("dect:red", false),
                staticLed("dect:orange", false),
                staticLed("dect:green", true),
            }
        },
        patterns_depend_on = {
            idle = {
                "status"
            },
            session_overlap = {
                "status"
            },
            setup_locked = {
                "status"
            },
            off = {
                "status"
            },
            success = {
                "status"
            }
        }
    },
    lte = {
        initial = "mobile_off",
        transitions = {
            mobile_off ={
                mobile_bars0 = "mobile_bars0",
                mobile_bars1 = "mobile_bars1",
                mobile_bars2 = "mobile_bars2",
                mobile_bars3 = "mobile_bars3",
                mobile_bars4 = "mobile_bars4",
                mobile_bars5 = "mobile_bars5",
            },
            mobile_bars0 = {
                mobile_bars1 = "mobile_bars1",
                mobile_bars2 = "mobile_bars2",
                mobile_bars3 = "mobile_bars3",
                mobile_bars4 = "mobile_bars4",
                mobile_bars5 = "mobile_bars5",
                mobile_off = "mobile_off"
            },
            mobile_bars1 = {
                mobile_bars0 = "mobile_bars0",
                mobile_bars2 = "mobile_bars2",
                mobile_bars3 = "mobile_bars3",
                mobile_bars4 = "mobile_bars4",
                mobile_bars5 = "mobile_bars5",
                mobile_off = "mobile_off"
            },
            mobile_bars2 = {
                mobile_bars0 = "mobile_bars0",
                mobile_bars1 = "mobile_bars1",
                mobile_bars3 = "mobile_bars3",
                mobile_bars4 = "mobile_bars4",
                mobile_bars5 = "mobile_bars5",
                mobile_off = "mobile_off"
            },
            mobile_bars3 = {
                mobile_bars0 = "mobile_bars0",
                mobile_bars1 = "mobile_bars1",
                mobile_bars2 = "mobile_bars2",
                mobile_bars4 = "mobile_bars4",
                mobile_bars5 = "mobile_bars5",
                mobile_off = "mobile_off"
            },
            mobile_bars4 = {
                mobile_bars0 = "mobile_bars0",
                mobile_bars1 = "mobile_bars1",
                mobile_bars2 = "mobile_bars2",
                mobile_bars3 = "mobile_bars3",
                mobile_bars5 = "mobile_bars5",
                mobile_off = "mobile_off"
            },
            mobile_bars5 = {
                mobile_bars0 = "mobile_bars0",
                mobile_bars1 = "mobile_bars1",
                mobile_bars2 = "mobile_bars2",
                mobile_bars3 = "mobile_bars3",
                mobile_bars4 = "mobile_bars4",
                mobile_off = "mobile_off"
            }
        },
        actions = {
            mobile_off = {
                staticLed("lte:red", false),
                staticLed("lte:green", false),
            },
            mobile_bars0 = {
                staticLed("lte:green", false),
                staticLed("lte:red", false),
            },
            mobile_bars1 = {
                staticLed("lte:green", false),
                staticLed("lte:red", true),
            },
            mobile_bars2 = {
                staticLed("lte:green", true),
                staticLed("lte:red", true),
            },
            mobile_bars3 = {
                staticLed("lte:red", false),
                staticLed("lte:green", true),
            },
            mobile_bars4 = {
                staticLed("lte:red", false),
                staticLed("lte:green", true),
            },
            mobile_bars5 = {
                staticLed("lte:red", false),
                staticLed("lte:green", true),
            },
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
    }
}
