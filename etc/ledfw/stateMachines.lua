-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT = timerLed, staticLed, netdevLed, netdevLedOWRT

stateMachines = {
    power = {
        initial = "power_started",
        transitions = {
            power_started = {
                fwupgrade_state_upgrading = "upgrade",
                network_interface_wan_ifup = "internet_connected",
            },
            internet_connected = {
                fwupgrade_state_upgrading = "upgrade",
                network_interface_wan_ifdown = "power_started",
                network_interface_broadband_ifdown = "power_started"
            },
            upgrade = {
                fwupgrade_state_done = "power_started",
                fwupgrade_state_failed = "power_started",
            },
        },
        actions = {
            power_started = {
                staticLed("power:orange", false),
                staticLed("power:red", true),
                staticLed("power:blue", false),
                staticLed("power:green", false)
            },
			internet_connected = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
			},
            upgrade = {
                staticLed("power:red", false),
                staticLed("power:green", false),
                timerLed("power:orange", 250, 250),
            }
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
        }
    },
    internet = {
        initial = "internet_disconnected",
        transitions = {
            internet_disconnected = {
                network_interface_wan_ifup = "internet_connected",
                network_interface_broadband_ifup = "internet_connecting"
            },
            internet_connecting = {
                network_interface_broadband_ifdown = "internet_disconnected",
                network_interface_wan_ifdown = "internet_disconnected",
                network_interface_wan_ifup = "internet_connected"
            },
            internet_connected = {
                network_interface_wan_ifdown = "internet_disconnected",
                network_interface_broadband_ifdown = "internet_disconnected"
            }
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", true)
            },
            internet_connecting = {
                staticLed("internet:green", false),
                timerLed("internet:red", 500, 500)
            },
            internet_connected = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false)
            }

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
        }
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_leds_on = "wifi_security",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_wep_wl0 = "wifi_wep",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            },
            wifi_nosecurity = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_wep_wl0 = "wifi_wep",
            },
            wifi_wep = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            },
            wifi_security = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wep_wl0 = "wifi_wep",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            }
        },
        actions = {
            wifi_off = {
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
            },
            wifi_nosecurity = {
                netdevLed("wireless:red", 'wl0', 'link tx rx'),
                netdevLed("wireless:green", 'wl0', 'link tx rx'),
            },
            wifi_wep = {
                netdevLed("wireless:red", 'wl0', 'link tx rx'),
                netdevLed("wireless:green", 'wl0', 'link tx rx'),
            },
            wifi_security = {
                staticLed("wireless:red", false),
                netdevLed("wireless:green", 'wl0', 'link tx rx')
            }
        }
    },
    wifi_5G = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_leds_on = "wifi_security",
                wifi_security_wpapsk_wl1 = "wifi_security",
                wifi_security_wpa_wl1 = "wifi_security",
                wifi_security_wep_wl1 = "wifi_wep",
                wifi_security_disabled_wl1 = "wifi_nosecurity",
            },
            wifi_nosecurity = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_security_wpapsk_wl1 = "wifi_security",
                wifi_security_wpa_wl1 = "wifi_security",
                wifi_security_wep_wl1 = "wifi_wep",
            },
            wifi_wep = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_security_wpapsk_wl1 = "wifi_security",
                wifi_security_wpa_wl1 = "wifi_security",
                wifi_security_disabled_wl1 = "wifi_nosecurity",
            },
            wifi_security = {
                wifi_leds_off = "wifi_off",
                wifi_state_off_wl1 = "wifi_off",
                wifi_security_wep_wl1 = "wifi_wep",
                wifi_security_disabled_wl1 = "wifi_nosecurity",
            }
        },
        actions = {
            wifi_off = {
                staticLed("wireless_5g:green", false),
                staticLed("wireless_5g:red", false),
            },
            wifi_nosecurity = {
                netdevLed("wireless_5g:red", 'wl1', 'link tx rx'),
                netdevLed("wireless_5g:green", 'wl1', 'link tx rx'),
            },
            wifi_wep = {
                netdevLed("wireless_5g:red", 'wl1', 'link tx rx'),
                netdevLed("wireless_5g:green", 'wl1', 'link tx rx'),
            },
            wifi_security = {
                staticLed("wireless_5g:red", false),
                netdevLed("wireless_5g:green", 'wl1', 'link tx rx')
            }
        }
    },
    wps ={
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
                wifi_wps_success = "success",
                wifi_wps_idle = "idle"
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
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", false),
            },
            session_overlap = {
                staticLed("wps:orange", false),
                timerLed("wps:red", 1000, 1000),
                staticLed("wps:green", false),
            },
            error = {
                staticLed("wps:orange", false),
                timerLed("wps:red", 100, 100),
                staticLed("wps:green", false),
            },
            setup_locked = {
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", true),
            },
            off = {
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", false),
            },
            inprogress ={
                staticLed("wps:red", false),
                staticLed("wps:green", false),
                timerLed("wps:orange", 200, 100),
            },
            success = {
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", true),
            },
        }
    },
    dect ={
      initial = "off",
      transitions = {
            off = {
                dect_registration_true = "registering_unregistered",
                dect_registered_true = "registered"
            },
            registering_registered = {
                dect_registration_false = "registered",
                dect_registered_false = "registering_unregistered"
            },
            registering_unregistered = {
                dect_registration_false = "off",
                dect_registered_true = "registering_registered"
            },
            registered = {
                dect_registration_true = "registering_registered",
                dect_registered_false = "off",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "five"
            },
			zero = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "registered",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "registered",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_five"
			},
			one = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "registered",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "registered",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_five"
			},
			two = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "registered",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "registered",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "two_five"
			},
			three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "registered",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "registered",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "three_five"
			},
			four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "registered",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "registered",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "four_five"
			},
			five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "registered",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "registered",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "four_five"
			},
			zero_one = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_five"
			},
			zero_two = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_two_five"
			},
			zero_three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_three_five"
			},
			zero_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_four_five"
			},
			zero_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_four_five"
			},
			one_two = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_two_five"
			},
			one_three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_three_five"
			},
			one_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_four_five"
			},
			one_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_four_five"
			},
			two_three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "two_three_five"
			},
			two_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "two_four_five"
			},
			two_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "two_four_five"
			},
			three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "three_four_five"
			},
			three_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "three_four_five"
			},
			four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "three_four_five"
			},
			zero_one_two = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_two_five"
			},
			zero_one_three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_three_five"
			},
			zero_one_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_four_five"
			},
			zero_one_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_one",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_one_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_four_five"
			},
			zero_two_three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_two_three_five"
			},
			zero_two_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_two_four_five"
			},
			zero_two_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_two_four_five"
			},
			zero_three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_three_four_five"
			},
			zero_three_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_three_four_five"
			},
			zero_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_four",
                 callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two_four_five",
               callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_three_four_five"
			},
			one_two_three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_two_three_five"
			},
			one_two_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_two_four_five"
			},
			one_two_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_two_four_five"
			},
			one_three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_three_four_five"
			},
			one_three_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_three_four_five"
			},
			one_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_three_four_five"
			},
			two_three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_two",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "two_three_four_five"
			},
			two_three_five	= {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_two",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "two_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "two_three_four_five"
			},
			two_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "two_three_four_five"
			},
			three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_three_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_three_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_three_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_three_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "two_three_four_five"
			},
			zero_one_two_three = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_two_three_five"
			},
			zero_one_two_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_two_four_five"
			},
			zero_one_two_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one_two",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_one_two",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_one_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_two_four_five"
			},
			zero_one_three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_three_three",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_three_three",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_three_four_five"
			},
			zero_one_three_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_one_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_one_three_four_five"
			},
			zero_one_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_one_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_one_three_four_five"
			},
			zero_two_three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_two_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_two_three_four_five"
			},
			zero_two_three_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "zero_two_three_four_five"
			},
			zero_two_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_two_three_five_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_two_three_five_four"
			},
			zero_three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_three_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_three_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_two_three_four_five"
			},
			one_two_three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one_two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one_two_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "one_two_three_four_five"
			},
			one_two_three_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two_three_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two_three_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_4 = "one_two_three_four_five"
			},
			one_two_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "one_two_three_four_five"
			},
			one_three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_three_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_three_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "one_two_three_four_five"
			},
			two_three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_two_three_four_five",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_two_three_four_five",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "one_two_three_four_five"
			},
			zero_one_two_three_four = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one_three_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one_two_four",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_5 = "zero_one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_two_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_two_three_four_five"
			},
			zero_one_two_three_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one_two_three",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_4 = "zero_one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one_two_three",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_5 = "zero_one_two_three_four_five"
			},
			zero_one_two_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one_two_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one_two_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_3 = "zero_one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one_two_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_one_two_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_3 = "zero_one_two_three_four_five"
			},
			zero_one_three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_2 = "zero_one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_one_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_2 = "zero_one_two_three_four_five"
			},
			zero_two_three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "two_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_1 = "zero_one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_1 = "zero_one_two_three_four_five"
			},
			one_two_three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "two_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "one_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "one_two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "one_two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "one_two_three_four",
				callstate_MMPBX_CALLSTATE_ALERTING_dect_dev_0 = "zero_one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "one_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "one_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "one_two_three_four",
                callstate_MMPBX_CALLSTATE_CALL_DELIVERED_dect_dev_0 = "zero_one_two_three_four_five"
			},
			zero_one_two_three_four_five = {
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_0 = "one_two_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_1 = "zero_two_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_2 = "zero_one_three_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_3 = "zero_one_two_four_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_4 = "zero_one_two_three_five",
                callstate_MMPBX_CALLSTATE_IDLE_dect_dev_5 = "zero_one_two_three_four",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_0 = "one_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_1 = "zero_two_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_2 = "zero_one_three_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_3 = "zero_one_two_four_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_4 = "zero_one_two_three_five",
				callstate_MMPBX_CALLSTATE_DISCONNECTED_dect_dev_5 = "zero_one_two_three_four"
			}

		},
        actions = {
            off = {
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:orange", false)
            },
            registering_registered ={
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                timerLed("dect:orange", 400, 400)
            },
            registering_unregistered ={
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                timerLed("dect:orange", 400, 400)
            },
            registered ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                staticLed("dect:green", true)
            },
			zero ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two_three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two_three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two_three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two_three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two_three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two_three ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two_three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two_three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two_three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two_three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			two_three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two_three_four ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two_three_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_two_three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			one_two_three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			},
			zero_one_two_three_four_five ={
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                timerLed("dect:green", 125, 125)
			}
        }
    },
    phone1 = {
        initial = "off",
        transitions = {
            profile_line1_usable = {
                profile_line1_usable_false = "off",
		callstate_MMPBX_CALLSTATE_DIALING_REASON_OUTGOINGCALL_fxs_dev_0 = "profile_line1_solid",
		callstate_MMPBX_CALLSTATE_ALERTING_REASON_INCOMINGCALL_fxs_dev_0 = "profile_line1_flash",
                network_interface_wan_ifdown = "wan_down",
                network_interface_broadband_ifdown = "wan_down"
            },
            profile_line1_solid = {
		callstate_MMPBX_CALLSTATE_CALL_DELIVERED_REASON_OUTGOINGCALL_fxs_dev_0 = "profile_line1_flash",
		callstate_MMPBX_CALLSTATE_IDLE_REASON_CALL_ENDED_fxs_dev_0 = "profile_line1_usable",
                network_interface_wan_ifdown = "wan_down",
                network_interface_broadband_ifdown = "wan_down"
            },
            profile_line1_flash = {
		callstate_MMPBX_CALLSTATE_DISCONNECTED_REASON_LOCAL_DISCONNECT_fxs_dev_0 = "profile_line1_solid",
		callstate_MMPBX_CALLSTATE_DISCONNECTED_REASON_REMOTE_DISCONNECT_fxs_dev_0 = "profile_line1_solid",
		callstate_MMPBX_CALLSTATE_IDLE_REASON_CALL_ENDED_fxs_dev_0 = "profile_line1_usable"
            },
            off = {
		profile_line1_usable_true = "profile_line1_usable"
            },
            wan_down = {
		network_interface_wan_ifup = "off",
		profile_line1_usable_false = "off"
            }
        },
        actions = {
            profile_line1_usable = {
                staticLed("iptv:green", true)
            },
            profile_line1_solid = {
                staticLed("iptv:green", true)
			},
            profile_line1_flash = {
                timerLed("iptv:green", 100, 100)
            },
            off = {
                staticLed("iptv:green", false)
            },
            wan_down = {
                staticLed("iptv:green", false)
            }
        }
    },
    phone2 = {
        initial = "off",
        transitions = {
            profile_line2_usable = {
                profile_line2_usable_false = "off",
		callstate_MMPBX_CALLSTATE_DIALING_REASON_OUTGOINGCALL_fxs_dev_1 = "profile_line2_solid",
		callstate_MMPBX_CALLSTATE_ALERTING_REASON_INCOMINGCALL_fxs_dev_1 = "profile_line2_flash",
                network_interface_wan_ifdown = "wan_down",
                network_interface_broadband_ifdown = "wan_down"
            },
            profile_line2_solid = {
		callstate_MMPBX_CALLSTATE_CALL_DELIVERED_REASON_OUTGOINGCALL_fxs_dev_1 = "profile_line2_flash",
		callstate_MMPBX_CALLSTATE_IDLE_REASON_CALL_ENDED_fxs_dev_1 = "profile_line2_usable",
                network_interface_wan_ifdown = "wan_down",
                network_interface_broadband_ifdown = "wan_down"
            },
            profile_line2_flash = {
		callstate_MMPBX_CALLSTATE_DISCONNECTED_REASON_LOCAL_DISCONNECT_fxs_dev_1 = "profile_line2_solid",
		callstate_MMPBX_CALLSTATE_DISCONNECTED_REASON_REMOTE_DISCONNECT_fxs_dev_1 = "profile_line2_solid",
		callstate_MMPBX_CALLSTATE_IDLE_REASON_CALL_ENDED_fxs_dev_1 = "profile_line2_usable"
            },
            off = {
                profile_line2_usable_true = "profile_line2_usable"
			},
            wan_down = {
                network_interface_wan_ifup = "off",
                profile_line1_usable_false = "off"
            }
        },
        actions = {
            profile_line2_usable = {
                staticLed("voip:green", true)
            },
            profile_line2_solid = {
                staticLed("voip:green", true)
            },
            profile_line2_flash = {
                timerLed("voip:green", 100, 100)
            },
            off = {
                staticLed("voip:green", false)
            },
            wan_down = {
                staticLed("voip:green", false)
            }
        }
    }
}
