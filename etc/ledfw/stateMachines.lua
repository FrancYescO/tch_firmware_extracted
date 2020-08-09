-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT = timerLed, staticLed, netdevLed, netdevLedOWRT

stateMachines = {
    power = {
        initial = "power_started",
        transitions = {
            power_started = {
            fwupgrade_state_upgrading = "upgrade",
            Layer2_wansensing_starting = "fixed_connecting",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
            network_interface_wwan_ifup = "mobiled_online",
            network_interface_wan_ifup = "fixed_online",
            network_interface_wan6_ifup = "fixed_online",
            bridge_wan_connected = "bridge_online",
            bridge_wan_disconnected = "bridge_offline",
        },
        upgrade = {
            fwupgrade_state_done = "power_started",
            fwupgrade_state_failed = "power_started",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
        },
        fixed_connecting = {
            fwupgrade_state_upgrading = "upgrade",
            network_interface_wwan_ifup = "mobiled_online",
            network_interface_wan_ifup = "fixed_online",
            network_interface_wan6_ifup = "fixed_online",
            network_interface_wwan_unavailable = "mobiled_offline",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
            bridge_wan_connected = "bridge_online",
            bridge_wan_disconnected = "bridge_offline",
        },
        mobiled_online = {
            fwupgrade_state_upgrading = "upgrade",
            network_interface_wan_ifup = "fixed_online",
            network_interface_wan6_ifup = "fixed_online",
            network_interface_wwan_ifdown = "mobiled_offline",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
       },
       fixed_online = {
            fwupgrade_state_upgrading = "upgrade",
            network_interface_wan_off_wan6_off = "fixed_connecting",
            network_interface_wan_ifup = "fixed_online",
            network_interface_wan6_ifup = "fixed_online",
            network_interface_wwan_ifup = "mobiled_online",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
            bridge_wan_connected = "bridge_online",
            bridge_wan_disconnected = "bridge_offline",
       },
       mobiled_offline = {
            fwupgrade_state_upgrading = "upgrade",
            network_interface_wan_ifup = "fixed_online",
            network_interface_wan6_ifup = "fixed_online",
            network_interface_wwan_ifup = "mobiled_online",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
       },
       bridge_online = {
            fwupgrade_state_upgrading = "upgrade",
            bridge_wan_disconnected = "bridge_offline",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
       },
       bridge_offline = {
            fwupgrade_state_upgrading = "upgrade",
            bridge_wan_connected = "bridge_online",
            rtfd_cycle_led_red = "cycle_color_red",
            thermalProtection_overheat = "power_overheated",
       },
       cycle_color_red = {
            rtfd_cycle_led_blue = "cycle_color_blue"
       },
       cycle_color_blue = {
            rtfd_cycle_led_green = "cycle_color_green",
       },
       cycle_color_green = {
            rtfd_cycle_led_white = "cycle_color_white",
       },
       cycle_color_white = {
            rtfd_cycle_led_orange = "cycle_color_orange",
       },
       cycle_color_orange = {
            rtfd_cycle_led_red = "cycle_color_red",
       },
       power_overheated = {
            fwupgrade_state_upgrading = "upgrade",
            fwupgrade_state_done = "power_started",
            fwupgrade_state_failed = "power_started",
            thermalProtection_operational_fixed_online = "fixed_online",
            thermalProtection_operational_mobiled_online = "mobiled_online",
            thermalProtection_operational_connection_failed = "mobiled_offline",
            bridge_wan_connected = "bridge_online",
            bridge_wan_disconnected = "bridge_offline",
        },
   },
   actions = {
       power_started = {
           staticLed("power:red", true),
           staticLed("power:green", true),
           staticLed("power:blue", true),
       },
       upgrade = {
           staticLed("power:red", false),
           staticLed("power:green", false),
           staticLed("power:blue", false),
           timerLed("power:red", 250, 250),
           timerLed("power:green", 250, 250),
           timerLed("power:blue", 250, 250),
       },
       fixed_connecting = {
           staticLed("power:blue", false),
           staticLed("power:red", 8),
           staticLed("power:green", 2),
       },
       mobiled_online = {
           staticLed("power:red", false),
           staticLed("power:green",false),
           staticLed("power:blue", 5),  -- Decrease brightness because of hardware issue.
        },
       fixed_online = {
           staticLed("power:red", false),
           staticLed("power:blue", false),
           staticLed("power:green", 5), -- Decrease brightness because of hardware issue.
       },
       mobiled_offline = {
           staticLed("power:blue", false),
           staticLed("power:green", false),
           staticLed("power:red", true),
       },
       cycle_color_red = {
           staticLed("power:green", false),
           staticLed("power:red", true),
           staticLed("power:blue", false),
       },
       cycle_color_blue = {
           staticLed("power:green", false),
           staticLed("power:red", false),
           staticLed("power:blue", true),
       },
       cycle_color_green = {
           staticLed("power:green", true),
           staticLed("power:red", false),
           staticLed("power:blue", false),
       },
       cycle_color_white = {
           staticLed("power:red", true),
           staticLed("power:green", true),
           staticLed("power:blue", true),
       },
       cycle_color_orange = {
           staticLed("power:blue", false),
           staticLed("power:red", 8),
           staticLed("power:green", 2),
       },
       power_overheated = {
           staticLed("power:red", true),
           staticLed("power:green", false),
           staticLed("power:blue", true),
       },
       bridge_online = {
           staticLed("power:red", false),
           staticLed("power:green", 5),
           staticLed("power:blue", false),
       },
       bridge_offline = {
           staticLed("power:red", true),
           staticLed("power:green", false),
           staticLed("power:blue", false),
       },
   }
},
    broadband = {
        initial = "idling",
        transitions = {
            idling = {
                xdsl_1 = "training",
                xdsl_2 = "synchronizing", --for ADSL event
                xdsl_6 = "synchronizing", --for VDSL event
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
                -- For netdev led, the brightness uses the value set before
                -- Turn on the led then off it, to make sure the brightness using the uci setting
                staticLed("ethernet:green", true),
                staticLed("ethernet:green", false),
                netdevLed("ethernet:green", 'eth4', 'link'),
            },
            training = {
                timerLed("ethernet:green", 250, 250)
            },
            synchronizing = {
                timerLed("ethernet:green", 125, 125)
            },
            connected = {
                staticLed("ethernet:green", true)
            },
        }
    },
    internet = {
        initial = "internet_disconnected",
        transitions = {
            internet_disconnected = {
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifup = "internet_connected",
                network_interface_wan_authfailed = "internet_ppp_authentication_failed",
            },
            internet_connected = {
                network_interface_wan_off_wan6_off_wwan_off = "internet_disconnected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wan_authfailed = "internet_ppp_authentication_failed",
            },
            internet_bigpond_connected = {
                network_interface_wan_off_wan6_off_wwan_off = "internet_disconnected",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifup = "internet_connected",
                network_interface_wan_authfailed = "internet_ppp_authentication_failed",
            },
            internet_ppp_authentication_failed = {
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifup = "internet_connected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wan_off_wan6_off_wwan_off = "internet_disconnected",
            },
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
            },
            internet_bigpond_connected = {
                staticLed("internet:red", true),
                staticLed("internet:green", true),
            },
            internet_connected = {
                staticLed("internet:red", false),
                staticLed("internet:green", true),
            },
           internet_ppp_authentication_failed = {
                staticLed("internet:green", false),
                staticLed("internet:red", true),
            },
        }
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_state_on_wl0 = "wifi_on",
                wifi_state_on_wl1 = "wifi_on",
            },
            wifi_on = {
                wifi_state_wl0_off_wl1_off = "wifi_off",
            },
        },
        actions = {
            wifi_off = {
                staticLed("wireless:green", false),
            },
            wifi_on = {
                staticLed("wireless:green", true),
            },
        }
    },
    dect_wps ={
      initial = "off",
      transitions = {
            off = {
                pairing_inprogress = "pairing_inprogress",
                pairing_success = "pairing_success",
                paging_alerting_true = "paging_alerting"
            },
            pairing_inprogress = {
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_error = "pairing_error",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_error = {
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_inprogress = "pairing_inprogress",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_success = {
                pairing_off = "off",
                pairing_inprogress = "pairing_inprogress",
                pairing_error = "pairing_error",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            paging_alerting = {
                paging_alerting_false = "pairing_success",
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_inprogress = "pairing_inprogress",
                pairing_error = "pairing_error",
                profile_state_stop = "off"
            }
        },
        actions = {
            off = {
                staticLed("dect:red", false),
                staticLed("dect:green", false),
            },
            pairing_inprogress ={
                staticLed("dect:red", false),
                timerLed("dect:green", 250, 250)
            },
            pairing_error ={
                staticLed("dect:green", false),
                staticLed("dect:red", true)
            },
            pairing_success ={
                staticLed("dect:red", false),
                staticLed("dect:green", true)
            },
            paging_alerting ={
                staticLed("dect:red", false),
                timerLed("dect:green", 1000, 1000)
            }
        }
    },

    voip = {
        initial = "off",
        transitions = {
            off = {
                profile_register_registered = "profile_registered",
                profile_register_unregistered = "profile_unregistered",
                profile_register_emergency = "profile_emergency_only",
                pstnline_linked = "pstnline_linked"
            },
            profile_registered = {
                profile_register_unregistered = "profile_unregistered",
                profile_register_emergency = "profile_emergency_only",
                new_call_started = "voip_on_registered",
                profile_state_stop = "off"
            },
            profile_unregistered = {
                profile_register_registered = "profile_registered",
                profile_register_emergency = "profile_emergency_only",
                profile_state_stop = "off"
            },
            profile_emergency_only = {
                profile_register_unregistered = "profile_unregistered",
                profile_register_registered = "profile_registered",
                new_call_started = "voice_on_emergency_only",
                profile_state_stop = "off"
            },
            voip_on_registered = {
                profile_register_unregistered = "voip_on_unregistered",
                profile_register_emergency = "voice_on_emergency_only",
                all_calls_ended = "profile_registered",
                profile_state_stop = "off",
            },
            voip_on_unregistered = {
                profile_register_registered = "voip_on_registered",
                profile_register_emergency = "voice_on_emergency_only",
                all_calls_ended = "profile_unregistered",
                profile_state_stop = "off"
            },
            voice_on_emergency_only = {
                profile_register_unregistered = "voip_on_unregistered",
                profile_register_registered = "voip_on_registered",
                all_calls_ended = "profile_emergency_only",
                profile_state_stop = "off"
            },
            pstnline_linked = {
                pstnline_nolink = "off",
                new_call_started = "dect_offhook",
            },
            dect_offhook = {
               pstnline_nolink = "off",
               all_calls_ended = "pstnline_linked",
            }
        },
        actions = {
            off = {
                staticLed("voip:green", false),
                staticLed("voip:red", false),
            },
            profile_registered = {
                staticLed("voip:red", false),
                staticLed("voip:green", true)
            },
            profile_emergency_only = {
                staticLed("voip:red", true),
                staticLed("voip:green", true),
            },
            voip_on_registered = {
                staticLed("voip:red", false),
                timerLed("voip:green", 500, 500),
            },
            voip_on_unregistered = {
                staticLed("voip:green", false),
                staticLed("voip:red", true)
            },
            profile_unregistered = {
                staticLed("voip:green", false),
                staticLed("voip:red", true)
            },
            voice_on_emergency_only = {
                staticLed("voip:red", true),
                staticLed("voip:green", true),
            },
            pstnline_linked = {
                staticLed("voip:red", false),
                staticLed("voip:green", true),
            },
            dect_offhook = {
                staticLed("voip:red", false),
                timerLed("voip:green", 500, 500),
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
    mobile = {
        initial = "mobile_offline",
        transitions = {
            mobile_online = {
                network_interface_wwan_ifdown= "mobile_offline",
            },
            mobile_offline = {
                network_interface_wwan_ifup = "mobile_online"
            }
        },
        actions = {
            mobile_offline = {
                staticLed("mobile:red", false),
                staticLed("mobile:green", false),
            },
            mobile_online = {
                staticLed("mobile:red", false),
                staticLed("mobile:green", true),
            }
        }
    }
}
