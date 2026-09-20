-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT, runFunc, uci, ubus, print, get_depending_led = timerLed, staticLed, netdevLed, netdevLedOWRT, runFunc, uci, ubus, print, get_depending_led
local wl1_ifname = get_wl1_ifname()
local itf_depending_led
local DSL_sync
local ipv4_or_v6 = false
local ipv4_and_v6 = false
local led_fast_pattern,led_fast_delay = "1111111000000011111110000000000000000000000000", 40

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

local function SetDSL(state)
   DSL_sync=state
end

local function SetIP4_or_v6(state)
   ipv4_or_v6=state
end

local function SetIP4_and_v6(state)
   ipv4_and_v6=state
end

local function DSLDownNextState()
   return DSL_sync and "internet_disconnected" or ipv4_and_v6 and "internet_connected_ipv4_and_v6" or "internet_connected_ipv4_or_v6"
end

local function MobileDownNextState()
   return ipv4_or_v6 and "mobile_device_connected" or "no_service_or_disconnected"
end

patterns = {
    firmwareupgrade = {
        state = "fwupgrade_state_done",
        transitions = {
            fwupgrade_state_done = {
                fwupgrade_state_upgrading = "fwupgrade_state_upgrading",
                fwupgrade_state_done = "fwupgrade_state_done"
            },
            fwupgrade_state_upgrading = {
                fwupgrade_state_flashing = "fwupgrade_state_flashing",
            },
            fwupgrade_state_flashing = {
                fwupgrade_state_done = "fwupgrade_state_done",
            },
        },
        actions = {
            fwupgrade_state_upgrading = {
                staticLed("power:red", false),
                staticLed("mobile:green", false),
                staticLed("mobile:red", false),
                staticLed("mobile:blue", false),
                staticLed("power:green", true)
            },
            fwupgrade_state_flashing = {
                staticLed("power:red", false),
                staticLed("power:green", false),
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("voip:red",false),
                staticLed("voip:green", false),
                staticLed("mobile:green", false),
                staticLed("mobile:red", false),
                staticLed("mobile:blue", false),
                patternLed("power:green",   "011111111100000", 111),
                patternLed("internet:green","001111111110000", 111),
                patternLed("wireless:green","000111111111000", 111),
                patternLed("voip:green",    "000011111111100", 111),
                patternLed("mobile:green",  "000001111111110", 111)
            },
        }
    }
}

stateMachines = {
    power = {
        initial = "power_started",
        transitions = {
            power_started = {
                reset_button_pressed = "reset_trigger",
            },
-- On Pressing the RESET button we would enter the 'reset_trigger' state and LED behaviour will be triggered accordingly.
-- If the button is released before the minimum configurable time for 'reset', then 'reset_button_released' would be received.
-- we move to "power started' state and then board would be rebooted.
-- So once we enter the 'reset_trigger' state, it implies either the board will be reset or will be rebooted.
            reset_trigger = {
                reset_button_released = "power_started",
            },
        },
        actions = {
            power_started = {
                staticLed("power:red", false),
                staticLed("power:green", true)
            },
            reset_trigger = {
                staticLed("power:red", false),
                staticLed("internet:red",false),
                staticLed("wireless:red",false),
                staticLed("voip:red",false),
                staticLed("mobile:blue",false),
                staticLed("mobile:red",false),
                patternLed("power:green",    "100000000000000", 2000),
                patternLed("internet:green", "110000000000000", 2000),
                patternLed("wireless:green", "111000000000000", 2000),
                patternLed("voip:green",     "111100000000000", 2000),
                patternLed("mobile:green",   "111110000000000", 2000),
            },
        },
        patterns_depend_on = {
            power_started = {"firmwareupgrade"},
        },
    },
    internet = {
        initial = "internet_disconnected",
        transitions = {
            internet_disconnected = {
                xdsl_1 = "internet_xdsl_connection_initiating",
                xdsl_0 = "internet_disconnected",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan6_ppp_connecting = "internet_connecting",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6",
            },
            internet_xdsl_connection_initiating = {
                xdsl_2 = "internet_xdsl_connecting",
                xdsl_6 = "internet_xdsl_connecting",
                xdsl_0 = "internet_disconnected",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan6_ppp_connecting = "internet_connecting",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6"
            },
            internet_xdsl_connecting = {
                xdsl_0 = "internet_disconnected",
                xdsl_5 = "internet_xdsl_connected",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan6_ppp_connecting = "internet_connecting",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6"

            },
            internet_xdsl_connected = {
                xdsl_0 = "internet_disconnected",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan6_ppp_connecting = "internet_connecting",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan_ifdown = "internet_connection_failure",
                network_interface_wan6_ifdown = "internet_connection_failure",
                network_interface_wan_no_ip = "internet_connection_failure",
                network_interface_wan6_no_ip = "internet_connection_failure"
            },
            internet_connecting = {
                xdsl_0 = DSLDownNextState,
                network_interface_wan_ppp_connected = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ppp_connected = "internet_connected_ipv4_or_v6",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6",
                network_interface_broadband_ifdown = "internet_connection_failure",
                network_interface_wan_ppp_disconnected = "internet_connection_failure",
                network_interface_wan6_ppp_disconnected = "internet_connection_failure",
                network_interface_wan_ifdown = "internet_connection_failure",
                network_interface_wan6_ifdown = "internet_connection_failure",
                network_interface_wan_no_ip = "internet_connection_failure",
                network_interface_wan6_no_ip = "internet_connection_failure",
                network_device_eth4_down = "internet_disconnected"
            },
            internet_connected_ipv4_or_v6 = {
                xdsl_0 = DSLDownNextState,
                network_interface_wan_ifup = "internet_connected_ipv4_and_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_and_v6",
                network_interface_broadband_ifdown = "internet_connection_failure",
                network_interface_wan_ppp_disconnected = "internet_connection_failure",
                network_interface_wan6_ppp_disconnected = "internet_connection_failure",
                network_interface_wan_ifdown = "internet_connection_failure",
                network_interface_wan6_ifdown = "internet_connection_failure",
                network_interface_wan_no_ip = "internet_connection_failure",
                network_interface_wan6_no_ip = "internet_connection_failure",
                network_device_eth4_down = "internet_disconnected"
            },
            internet_connected_ipv4_and_v6 = {
                xdsl_0 = DSLDownNextState,
                network_interface_wan_ppp_disconnected = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ppp_disconnected = "internet_connected_ipv4_or_v6",
                network_interface_broadband_ifdown = "internet_connection_failure",
                network_interface_wan_ifdown = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifdown = "internet_connected_ipv4_or_v6",
                network_interface_wan_no_ip = "internet_connected_ipv4_or_v6",
                network_interface_wan6_no_ip = "internet_connected_ipv4_or_v6",
                network_device_eth4_down = "internet_disconnected"
            },
            internet_connection_failure = {
                xdsl_0 = "internet_disconnected",
                network_interface_wan_ppp_connected = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ppp_connected = "internet_connected_ipv4_or_v6",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan6_ppp_connecting = "internet_connecting",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ifup = "internet_connected_ipv4_or_v6",
                network_interface_wan6_ifup = "internet_connected_ipv4_or_v6"
            }
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                runFunc(SetDSL,false),
				runFunc(SetIP4_or_v6,false)
            },
            internet_xdsl_connection_initiating = {
                staticLed("internet:green", false),
                timerLed("internet:red", 1000, 666),
                staticLed("voip:green", false),
                staticLed("voip:red", false)
            },
            internet_xdsl_connecting = {
                staticLed("internet:green", false),
                staticLed("internet:red", true),
                staticLed("voip:green", false),
                staticLed("voip:red", false)
            },
            internet_xdsl_connected = {
                staticLed("internet:red", false),
                timerLed("internet:green", 1000, 666),
                runFunc(SetDSL,true)
            },
            internet_connecting = {
                staticLed("internet:red", false),
                timerLed("internet:green", 1000, 666)
            },
            internet_connected_ipv4_or_v6 = {
                staticLed("internet:red", false),
                staticLed("internet:green", true),
				runFunc(SetIP4_or_v6,true),
                runFunc(SetIP4_and_v6,false)
            },
            internet_connected_ipv4_and_v6 = {
                staticLed("internet:red", false),
                staticLed("internet:green", true),
                runFunc(SetIP4_and_v6,true)
            },
            internet_connection_failure = {
                staticLed("internet:green", false),
                patternLed("internet:red", led_fast_pattern, led_fast_delay),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
				runFunc(SetIP4_or_v6,false)
            }
        },
        patterns_depend_on = {
            internet_disconnected = {"firmwareupgrade"},
            internet_xdsl_connection_initiating = {"firmwareupgrade"},
            internet_xdsl_connecting = {"firmwareupgrade"},
            internet_xdsl_connected = {"firmwareupgrade"},
            internet_connecting = {"firmwareupgrade"},
            internet_connected_ipv4_or_v6 = {"firmwareupgrade"},
            internet_connected_ipv4_and_v6 = {"firmwareupgrade"},
            internet_connection_failure = {"firmwareupgrade"}
        },
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_on_wl0 = "wifi_on_24G",
                wifi_on_wl1 = "wifi_on_5G",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started"
            },
            wifi_off_scheduling_started = {
                wifi_on_wl0 = "wifi_on_24G",
                wifi_on_wl1 = "wifi_on_5G",
                wifi_tod_scheduler_stop = "wifi_scheduling_stopped"
            },
            wifi_scheduling_stopped = {
                wifi_on_wl0 = "wifi_on_24G",
                wifi_on_wl1 = "wifi_on_5G",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started"
            },
            wifi_on_24G = {
                wifi_on_wl1 = "wifi_on_24G_and_5G",
                wifi_off_wl0 = "wifi_off",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started",
                wifi_wps_wl0_inprogress = "wifi_on_24G_wps_pairing"
            },
            wifi_on_5G = {
                wifi_on_wl0 = "wifi_on_24G_and_5G",
                wifi_off_wl1 = "wifi_off",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started",
                wifi_wps_wl1_inprogress = "wifi_on_5G_wps_pairing"
            },
            wifi_on_24G_and_5G = {
                wifi_off_wl0 = "wifi_on_5G",
                wifi_off_wl1 = "wifi_on_24G",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started",
                wifi_wps_wl0_inprogress = "wifi_on_24G_and_5G_wps_pairing",
                wifi_wps_wl1_inprogress = "wifi_on_24G_and_5G_wps_pairing"
            },
            wifi_on_24G_wps_pairing = {
                wifi_off_wl0 = "wifi_off",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started",
                wifi_wps_wl0_success = "wifi_on_24G",
                wifi_wps_wl0_error = "wifi_on_24G"
            },
            wifi_on_5G_wps_pairing = {
                wifi_off_wl1 = "wifi_off",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started",
                wifi_wps_wl1_success = "wifi_on_5G",
                wifi_wps_wl1_error = "wifi_on_5G"
            },
            wifi_on_24G_and_5G_wps_pairing = {
                wifi_off_wl0 = "wifi_on_5G",
                wifi_off_wl1 = "wifi_on_24G",
                wifi_off_tod_scheduler_start = "wifi_off_scheduling_started",
                wifi_wps_wl0_success = "wifi_on_24G_and_5G",
                wifi_wps_wl1_success = "wifi_on_24G_and_5G",
                wifi_wps_wl0_error = "wifi_on_24G_and_5G",
                wifi_wps_wl1_error = "wifi_on_24G_and_5G"
            }
        },
        actions = {
            wifi_off = {
                staticLed("power:green", true),
                staticLed("wireless:green", false)
            },
            wifi_off_scheduling_started = {
                staticLed("power:green", true),
                timerLed("wireless:green", 1000, 666)
            },
            wifi_scheduling_stopped = {
                staticLed("power:green",true),
                staticLed("wireless:green", false),
                staticLed("wireless:red", false)
            },
            wifi_on_24G = {
                staticLed("wireless:green", true),
                staticLed("power:green", true)
            },
            wifi_on_5G = {
                staticLed("wireless:green", true),
                staticLed("power:green", true)
            },
            wifi_on_24G_and_5G = {
                staticLed("wireless:green", true),
                staticLed("power:green", true)
            },
            wifi_on_24G_wps_pairing = {
                patternLed("wireless:green", led_fast_pattern, led_fast_delay),
                staticLed("power:green", true)
            },
            wifi_on_5G_wps_pairing = {
                patternLed("wireless:green", led_fast_pattern, led_fast_delay),
                staticLed("power:green", true)
            },
            wifi_on_24G_and_5G_wps_pairing = {
                patternLed("wireless:green", led_fast_pattern, led_fast_delay),
                staticLed("power:green", true)
            }
        },
	    patterns_depend_on = {
		    wifi_off = {"firmwareupgrade"},
		    wifi_off_scheduling_started = {"firmwareupgrade"},
		    wifi_scheduling_stopped = {"firmwareupgrade"},
		    wifi_on_24G = {"firmwareupgrade"},
		    wifi_on_5G = {"firmwareupgrade"},
		    wifi_on_24G_and_5G = {"firmwareupgrade"},
		    wifi_on_24G_wps_pairing = {"firmwareupgrade"},
		    wifi_on_5G_wps_pairing = {"firmwareupgrade"},
		    wifi_on_24G_and_5G_wps_pairing = {"firmwareupgrade"}
	    },
    },
    voice = {
        initial = "off",
        transitions = {
            fxs_profiles_usable = {
                fxs_lines_error = "fxs_profiles_error",
                registration_ongoing = "fxs_profiles_registering",
                fxs_lines_usable_off = "off",
                fxs_inactive = "fxs_profiles_usable",
                outgoing_call = "fxs_profiles_flash",
                incoming_call = "fxs_profiles_flash",
                fxs_lines_usable_idle = "off",
            },
            fxs_profiles_flash_fast = {
                fxs_inactive = "fxs_profiles_usable",
                fxs_lines_error = "fxs_profiles_error",
                fxs_lines_usable_idle = "off",
                outgoing_call = "fxs_profiles_flash",
                ongoing_call = "fxs_profiles_flash_fast",
                incoming_call = "fxs_profiles_flash",
            },
            fxs_profiles_flash = {
                fxs_inactive = "fxs_profiles_usable",
                fxs_lines_error = "fxs_profiles_error",
                fxs_lines_usable_off = "off",
                outgoing_call = "fxs_profiles_flash",
                incoming_call = "fxs_profiles_flash",
                ongoing_call = "fxs_profiles_flash_fast",
                fxs_lines_usable_idle = "off",
            },
            fxs_profiles_error = {
                registration_ongoing = "fxs_profiles_registering",
                fxs_lines_usable = "fxs_profiles_usable",
                fxs_lines_error = "fxs_profiles_error",
                fxs_lines_usable_off = "off",
                fxs_lines_usable_idle = "off",
            },
            fxs_profiles_registering = {
                registration_ongoing = "fxs_profiles_registering",
                fxs_lines_usable = "fxs_profiles_usable",
                fxs_lines_error = "fxs_profiles_error",
                fxs_lines_usable_off = "off",
                fxs_lines_usable_idle = "off",
            },
            off = {
                fxs_lines_usable = "fxs_profiles_usable",
                fxs_lines_error = "fxs_profiles_error",
                fxs_lines_usable_off = "off",
                registration_ongoing = "fxs_profiles_registering",
                fxs_lines_usable_idle = "off",
            }
        },
        actions = {
            fxs_profiles_usable = {
                staticLed("voip:green", true),
                staticLed("voip:red", false),
            },
            fxs_profiles_flash = {
                timerLed("voip:green", 1000, 666),
            },
            fxs_profiles_flash_fast = {
                patternLed("voip:green", led_fast_pattern, led_fast_delay),
            },
            fxs_profiles_error = {
                patternLed("voip:red", led_fast_pattern, led_fast_delay),
                staticLed("voip:green", false),
            },
            fxs_profiles_registering = {
                timerLed("voip:red", 1000, 666),
                staticLed("voip:green", false),
            },
            off = {
                staticLed("voip:red", false),
                staticLed("voip:green", false),
            }
        },
        patterns_depend_on = {
            fxs_profiles_usable = {"firmwareupgrade"},
            fxs_profiles_flash_fast = {"firmwareupgrade"},
            fxs_profiles_flash = {"firmwareupgrade"},
            fxs_profiles_error = {"firmwareupgrade"},
            fxs_profiles_registering = {"firmwareupgrade"},
            off = {"firmwareupgrade"}
        }
    },
    mobile = {
        initial = "unplugged",
        transitions = {
            unplugged = {
                mobile_on = "mobile_device_connected",
            },
            mobile_device_connected = {
                mobile_sim_not_present = "no_sim_card",
                mobile_sim_locked = "pending_pin_puk",
                mobile_sim_blocked = "pending_pin_puk",
                mobile_session_setup_umts = "detecting_3g",
                mobile_session_setup_lte = "detecting_4g",
                mobile_session_setup_gsm = "detecting_gprs",
                mobile_session_connected_umts = "connected_3g",
                mobile_session_connected_lte = "connected_4g",
                mobile_session_connected_gsm = "connected_gprs",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged"
            },
            no_sim_card = {
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            pending_pin_puk = {
                mobile_sim_blocked = "pending_pin_puk",
                mobile_sim_disabled = "no_service_or_disconnected",
                mobile_session_setup_umts = "detecting_3g",
                mobile_session_setup_lte = "detecting_4g",
                mobile_session_setup_gsm = "detecting_gprs",
                mobile_session_connected_umts = "connected_3g",
                mobile_session_connected_lte = "connected_4g",
                mobile_session_connected_gsm = "connected_gprs",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            no_service_or_disconnected = {
                mobile_session_setup_umts = "detecting_3g",
                mobile_session_setup_lte = "detecting_4g",
                mobile_session_setup_gsm = "detecting_gprs",
                mobile_session_connected_umts = "connected_3g",
                mobile_session_connected_lte = "connected_4g",
                mobile_session_connected_gsm = "connected_gprs",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
                network_interface_wan_ifup = "mobile_device_connected"
            },
            detecting_3g = {
                mobile_session_setup_lte = "detecting_4g",
                mobile_session_setup_gsm = "detecting_gprs",
                mobile_session_disconnected = MobileDownNextState,
                mobile_session_connected_umts = "connected_3g",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            detecting_4g = {
                mobile_session_setup_umts = "detecting_3g",
                mobile_session_setup_gsm = "detecting_gprs",
                mobile_session_disconnected = MobileDownNextState,
                mobile_session_connected_lte = "connected_4g",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            detecting_gprs = {
                mobile_session_setup_umts = "detecting_3g",
                mobile_session_setup_lte = "detecting_4g",
                mobile_session_disconnected = MobileDownNextState,
                mobile_session_connected_gsm = "connected_gprs",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            connected_3g = {
                mobile_session_disconnected = MobileDownNextState,
                mobile_session_teardown_umts = MobileDownNextState,
                mobile_session_removed_umts = MobileDownNextState,
                mobile_voice_dialing_umts = "voice_call_3g",
                mobile_voice_alerting_umts = "voice_call_3g",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            connected_4g = {
                mobile_session_disconnected = MobileDownNextState,
                mobile_session_teardown_lte = MobileDownNextState,
                mobile_session_removed_lte = MobileDownNextState,
                mobile_voice_dialing_lte = "voice_call_4g",
                mobile_voice_dialing_umts = "voice_call_3g",
                mobile_voice_dialing_gsm = "voice_call_2g",
                mobile_voice_alerting_lte = "voice_call_4g",
                mobile_voice_alerting_umts = "voice_call_3g",
                mobile_voice_alerting_gsm = "voice_call_2g",
                mobile_session_connected_gsm = "connected_gprs",
                mobile_session_connected_umts = "connected_3g",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            connected_gprs = {
                mobile_session_disconnected = MobileDownNextState,
                mobile_session_teardown_gsm = MobileDownNextState,
                mobile_session_removed_gsm = MobileDownNextState,
                mobile_voice_dialing_gsm = "voice_call_2g",
                mobile_voice_alerting_gsm = "voice_call_2g",
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            voice_call_3g = {
                mobile_voice_delivered_umts = "voice_call_3g",
                mobile_voice_connected_umts = "voice_call_3g",
                mobile_voice_no_call_umts = "connected_3g",
                mobile_session_disconnected = MobileDownNextState,
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            voice_call_4g = {
                mobile_voice_delivered_lte = "voice_call_4g",
                mobile_voice_connected_lte = "voice_call_4g",
                mobile_voice_no_call_lte = "connected_4g",
                mobile_session_disconnected = MobileDownNextState,
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
            voice_call_2g = {
                mobile_voice_delivered_gsm = "voice_call_2g",
                mobile_voice_connected_gsm = "voice_call_2g",
                mobile_voice_no_call_gsm = "connected_gprs",
                mobile_session_disconnected = MobileDownNextState,
                mobile_off = "unplugged",
                mobile_device_disconnected = "unplugged",
            },
        },
        actions = {
            unplugged = {
                staticLed("mobile:blue", false),
                staticLed("mobile:red", false),
                staticLed("mobile:green", false),
            },
            mobile_device_connected = {
                staticLed("mobile:blue", false),
                staticLed("mobile:red", false),
                staticLed("mobile:green", false),
            },
            no_sim_card = {
                staticLed("mobile:green", false),
                staticLed("mobile:blue", false),
                staticLed("mobile:red", true),
            },
            pending_pin_puk = {
                staticLed("mobile:green", false),
                staticLed("mobile:blue", false),
                timerLed("mobile:red", 1000, 666),
            },
            no_service_or_disconnected = {
                staticLed("mobile:green", false),
                staticLed("mobile:blue", false),
                patternLed("mobile:red", led_fast_pattern, led_fast_delay),
            },
            detecting_3g = {
                staticLed("mobile:green", false),
                staticLed("mobile:red", false),
                timerLed("mobile:blue", 1000, 666),
            },
            detecting_4g = {
                staticLed("mobile:green", false),
                patternLed("mobile:red", 1000, 666),
                patternLed("mobile:blue", 1000, 666)
            },
            detecting_gprs = {
                staticLed("mobile:blue", false),
                staticLed("mobile:red", false),
                patternLed("mobile:green", 1000, 666)
            },
            connected_3g = {
                staticLed("mobile:green", false),
                staticLed("mobile:red", false),
                staticLed("mobile:blue", true),
            },
            connected_4g = {
                staticLed("mobile:green", false),
                staticLed("mobile:blue", true),
                staticLed("mobile:red", true),
            },
            connected_gprs = {
                staticLed("mobile:blue", false),
                staticLed("mobile:red", false),
                staticLed("mobile:green", true),
            },
            voice_call_3g = {
                staticLed("mobile:red", false),
                staticLed("mobile:green", false),
                patternLed("mobile:blue", led_fast_pattern, led_fast_delay),
            },
            voice_call_4g = {
                staticLed("mobile:green", false),
                patternLed("mobile:red", led_fast_pattern, led_fast_delay),
                patternLed("mobile:blue", led_fast_pattern, led_fast_delay),
            },
            voice_call_2g = {
                staticLed("mobile:blue", false),
                staticLed("mobile:red", false),
                patternLed("mobile:green", led_fast_pattern, led_fast_delay),
            },
        },
        patterns_depend_on = {
            unplugged = {"firmwareupgrade"},
            mobile_device_connected = {"firmwareupgrade"},
            no_sim_card = {"firmwareupgrade"},
            pending_pin_puk = {"firmwareupgrade"},
            no_service_or_disconnected = {"firmwareupgrade"},
            detecting_3g = {"firmwareupgrade"},
            detecting_4g = {"firmwareupgrade"},
            detecting_gprs = {"firmwareupgrade"},
            connected_3g = {"firmwareupgrade"},
            connected_4g = {"firmwareupgrade"},
            connected_gprs = {"firmwareupgrade"},
            voice_call_3g = {"firmwareupgrade"},
            voice_call_4g = {"firmwareupgrade"},
            voice_call_2g = {"firmwareupgrade"}
        },
    }
}
