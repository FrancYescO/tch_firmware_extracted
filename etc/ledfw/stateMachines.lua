-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT = timerLed, staticLed, netdevLed, netdevLedOWRT

stateMachines = {
    power = {
        initial = "power_started",
        transitions = {
            power_started = {
                fwupgrade_state_upgrading = "upgrade",
                thermalProtection_overheat = "power_overheated",
            },
            upgrade = {
                fwupgrade_state_done = "power_started",
                fwupgrade_state_failed = "power_started",
                thermalProtection_overheat = "power_overheated",
            },
            power_overheated = {
                fwupgrade_state_upgrading = "upgrade",
                fwupgrade_state_done = "power_started",
                fwupgrade_state_failed = "power_started",
                thermalProtection_operational = "power_started",
            },
        },
        actions = {
            power_started = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
            },
            upgrade = {
                staticLed("power:red", false),
                staticLed("power:green", false),
                staticLed("power:orange", false),
                staticLed("power:blue", true),
            },
            power_overheated = {
                staticLed("power:orange", false),
                staticLed("power:red", true),
                staticLed("power:blue", false),
                staticLed("power:green", false)
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
                staticLed("ethernet:green", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:white", false),
                staticLed("ethernet:blue", false),
                netdevLed("ethernet:green", 'eth4', 'link'),
            },
            training = {
                staticLed("ethernet:green", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:blue", false),
                staticLed("ethernet:white", true),
            },
            synchronizing = {
                staticLed("ethernet:green", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:white", false),
                staticLed("ethernet:blue", true)
            },
            connected = {
                staticLed("ethernet:white", false),
                staticLed("ethernet:red", false),
                staticLed("ethernet:blue", false),
                staticLed("ethernet:green", true)
            },
        }
    },
    internet = {
        initial = "internet_disconnected",
        transitions = {
            internet_disconnected = {
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_broadband_ifup = "internet_connecting",
                network_interface_wan_ppp_connecting = "internet_connecting",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_connecting = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wan_ppp_disconnected = "internet_disconnected",
                network_interface_wan_ppp_authenticating = "internet_ppp_authenticating",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_connected = {
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_bigpond_connected = {
                network_interface_wan_off_wan6_off = "internet_disconnected",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_ppp_authenticating = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_ppp_disconnecting = "internet_ppp_authentication_failed",
                network_interface_wan_ppp_connected = "internet_connecting",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_ppp_authentication_failed = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_ppp_connected = "internet_connecting",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifup = "internet_connected_mobiledongle",
            },
            internet_connected_mobiledongle = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_connected_without_bigpond = "internet_connected",
                network_interface_connected_with_bigpond = "internet_bigpond_connected",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan6_ifup = "internet_connected",
                network_interface_wwan_ifdown = "internet_disconnected",
            }
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("internet:blue", false),
                staticLed("internet:white", false),
            },
            internet_connecting = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("internet:blue", false),
                staticLed("internet:white", true),
            },
            internet_bigpond_connected = {
                staticLed("internet:white", false),
                staticLed("internet:red", false),
                staticLed("internet:green", false),
                staticLed("internet:blue", true),
            },
            internet_connected = {
                staticLed("internet:white", false),
                staticLed("internet:blue", false),
                staticLed("internet:red", false),
                staticLed("internet:green", true),
            },
            internet_ppp_authenticating = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("internet:blue", false),
                staticLed("internet:white", true),
            },
            internet_ppp_authentication_failed = {
                staticLed("internet:white", false),
                staticLed("internet:green", false),
                staticLed("internet:blue", false),
                staticLed("internet:red", true),
            },
            internet_connected_mobiledongle = {
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("internet:blue", false),
                staticLed("internet:magenta", true),
            },
        }
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_leds_on = "wifi_on",
                wifi_state_on_wl0 = "wifi_on",
                wifi_state_on_wl1 = "wifi_on",
                network_interface_fonopen_ifup = "wifi_telstra_air_broadcasting",
            },
            wifi_on = {
                wifi_leds_off = "wifi_off",
                wifi_state_wl0_off_wl1_off = "wifi_off",
                network_interface_fonopen_ifup = "wifi_telstra_air_broadcasting",
            },
            wifi_telstra_air_broadcasting = {
                wifi_leds_off = "wifi_off",
                wifi_state_wl0_off_wl1_off = "wifi_off",
                network_interface_fonopen_ifdown = "wifi_on",
            },
        },
        actions = {
            wifi_off = {
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("wireless:white", false),
                staticLed("wireless:blue", false),
                staticLed("wireless:magenta", false)
            },
            wifi_on = {
                staticLed("wireless:red", false),
                staticLed("wireless:blue", false),
                staticLed("wireless:green", true),
            },
            wifi_telstra_air_broadcasting = {
                staticLed("wireless:green", true),
                staticLed("wireless:red", false),
                staticLed("wireless:blue", false),
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
                pairing_overlap = "pairing_overlap",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_error = {
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_inprogress = "pairing_inprogress",
                pairing_overlap = "pairing_overlap",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_overlap = {
                pairing_off = "off",
                pairing_success = "pairing_success",
                pairing_inprogress = "pairing_inprogress",
                pairing_error = "pairing_error",
                paging_alerting_true = "paging_alerting",
                profile_state_stop = "off"
            },
            pairing_success = {
                pairing_off = "off",
                pairing_overlap = "pairing_overlap",
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
                staticLed("dect:blue", false),
                staticLed("dect:white", false)
            },
            pairing_inprogress ={
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:blue", false),
                timerLed("dect:white", 400, 400)
            },
            pairing_error ={
                staticLed("dect:white", false),
                staticLed("dect:green", false),
                staticLed("dect:blue", false),
                timerLed("dect:red", 100, 100)
            },
            pairing_success ={
                staticLed("dect:white", false),
                staticLed("dect:red", false),
                staticLed("dect:blue", false),
                staticLed("dect:green", true)
            },
            pairing_overlap ={
                staticLed("dect:white", false),
                staticLed("dect:blue", false),
                staticLed("dect:green", false),
                timerLed("dect:red", 1000, 1000)
            },
            paging_alerting ={
                staticLed("dect:white", false),
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                timerLed("dect:blue", 400, 400)
            }
        }
    },

    voip = {
        initial = "off",
        transitions = {
            off = {
                profile_register_registering = "profile_registering",
                profile_register_registered = "profile_registered",
                profile_register_emergency = "profile_emergency_only"
            },
            profile_registering = {
                profile_register_unregistered = "off",
                profile_register_registered = "profile_registered",
                profile_register_emergency = "profile_emergency_only",
                new_call_started = "voip_on_registering",
                profile_state_stop = "off"
            },
            profile_registered = {
                profile_register_unregistered = "off",
                profile_register_registering = "profile_registering",
                profile_register_emergency = "profile_emergency_only",
                new_call_started = "voip_on_registered",
                profile_state_stop = "off"
            },
            profile_emergency_only = {
                profile_register_unregistered = "off",
                profile_register_registering = "profile_registering",
                profile_register_registered = "profile_registered",
                new_call_started = "voice_on_emergency_only",
                profile_state_stop = "off"
            },
            voip_on_registered = {
                profile_register_unregistered = "voip_on_unregistered",
                profile_register_registering = "voip_on_registering",
                profile_register_emergency = "voice_on_emergency_only",
                all_calls_ended = "profile_registered",
                profile_state_stop = "off"
            },
            voip_on_registering = {
                profile_register_unregistered = "voip_on_unregistered",
                profile_register_registered = "voip_on_registered",
                profile_register_emergency = "voice_on_emergency_only",
                all_calls_ended = "profile_registering",
                profile_state_stop = "off"
            },
            voip_on_unregistered = {
                profile_register_registering = "voip_on_registering",
                profile_register_registered = "voip_on_registered",
                profile_register_emergency = "voice_on_emergency_only",
                all_calls_ended = "off",
                profile_state_stop = "off"
            },
            voice_on_emergency_only = {
                profile_register_unregistered = "voip_on_unregistered",
                profile_register_registering = "voip_on_registering",
                profile_register_registered = "voip_on_registered",
                all_calls_ended = "profile_emergency_only",
                profile_state_stop = "off"
            }
        },
        actions = {
            off = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", false)
            },
            profile_registering = {
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", false),
                staticLed("voip:white", true)
            },
            profile_registered = {
                staticLed("voip:white", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", false),
                staticLed("voip:green", true)
            },
            profile_emergency_only = {
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", false),
                staticLed("voip:magenta", true)
            },
            voip_on_registered = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", true)
            },
            voip_on_registering = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", true)
            },
            voip_on_unregistered = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", true)
            },
            voice_on_emergency_only = {
                staticLed("voip:white", false),
                staticLed("voip:green", false),
                staticLed("voip:red", false),
                staticLed("voip:blue", true)
            }
        }
    },
    mobile = {
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
                staticLed("lte:blue", false)
            },
            mobile_bars0 = {
                staticLed("lte:red", false),
                staticLed("lte:green", false),
                staticLed("lte:blue", false)
            },
            mobile_bars1 = {
                staticLed("lte:red", true),
                staticLed("lte:green", false),
                staticLed("lte:blue", false)
            },
            mobile_bars2 = {
                staticLed("lte:red", true),
                staticLed("lte:green", true),
                staticLed("lte:blue", false)
            },
            mobile_bars3 = {
                staticLed("lte:red", true),
                staticLed("lte:green", true),
                staticLed("lte:blue", false)
            },
            mobile_bars4 = {
                staticLed("lte:red", false),
                staticLed("lte:green", true),
                staticLed("lte:blue", false)
            },
            mobile_bars5 = {
                staticLed("lte:red", false),
                staticLed("lte:green", true),
                staticLed("lte:blue", false)
            }
        }
    }
}
