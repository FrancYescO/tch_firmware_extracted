-- myrepublic
-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT = timerLed, staticLed, netdevLed, netdevLedOWRT

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
                staticLed("broadband:green", false),
                staticLed("internet:green", false),
                staticLed("internet:red", false),
                staticLed("iptv:green", false),
                staticLed("ethernet:green", false),
                staticLed("wireless:green", false),
                staticLed("wireless:red", false),
                staticLed("wireless_5g:green", false),
                staticLed("wireless_5g:red", false),
                staticLed("wps:orange", false),
                staticLed("wps:red", false),
                staticLed("wps:green", false),
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:orange", false),
                staticLed("voip:green", false)
            },
        }
    }
}

stateMachines = {
    power = {
        initial = "power_started",
        transitions = {
            power_started = {
                fwupgrade_state_upgrading = "upgrade",
            },
            upgrade = {
                fwupgrade_state_done = "power_started",
                fwupgrade_state_failed = "power_started",
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
                timerLed("power:blue", 250, 250),
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
                network_interface_wan_ifup = "internet_connected",
                network_interface_broadband_ifup = "internet_connecting",
                xdsl_5 = "internet_connecting",
                network_interface_wan_ppp_connecting = "internet_connecting"
            },
            internet_connecting = {
                network_interface_broadband_ifdown = "internet_disconnected",
                xdsl_0 = "internet_disconnected",
                network_interface_wan_ifdown = "internet_disconnected",
                network_interface_wan_ifup = "internet_connected",
                network_interface_wan_ppp_disconnected = "internet_disconnected"
            },
            internet_connected = {
                network_interface_wan_ifdown = "internet_disconnected",
                network_interface_broadband_ifdown = "internet_disconnected",
--                xdsl_0 = "internet_disconnected"
            }
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", true)
            },
            internet_connecting = {
                staticLed("internet:green", false),
-- timerLed("internet:red", 500, 500), was not behaving as expected; using same values since last time when setting timerLed for same LED can cause LED *NOT* to blink at all;
-- Probably LED driver problem; workaround is setting twice with different values
                timerLed("internet:red", 498, 502),
                timerLed("internet:red", 499, 501)
            },
            internet_connected = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false)
            }

        },
        patterns_depend_on = {
            internet_disconnected = {"status"},
            internet_connecting = {"status"},
            internet_connected  = {"status"},
        }
    },
    usb = {
        initial = "usb_unmount",
        transitions = {
            usb_unmount = {
                usb_led_on = "usb_mount",
            },
            usb_mount = {
                usb_led_off = "usb_unmount",
            }
        },
        actions = {
            usb_unmount = {
                 staticLed("iptv:green", false),
            },
            usb_mount = {
                 staticLed("iptv:green", true),
            }
        },
        patterns_depend_on = {
            usb_unmount = {
                "status"
            },
            usb_mount = {
                "status"
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
        },
        patterns_depend_on = {
            wifi_off = {
                "status"
            },
            wifi_nosecurity = {
                "status"
            },
            wifi_wep = {
                "status"
            },
            wifi_security = {
                "status"
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
        },
        patterns_depend_on = {
            wifi_off = {
                "status"
            },
            wifi_nosecurity = {
                "status"
            },
            wifi_wep = {
                "status"
            },
            wifi_security = {
                "status"
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
            inprogress = {
                staticLed("wps:red", false),
                staticLed("wps:green", false),
                timerLed("wps:orange", 200, 100),
            },
            success = {
            	staticLed("wps:red", false),         
            	staticLed("wps:orange", false), 
            	staticLed("wps:green", true), 
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
            },
            error = {
                "status"
            },
            inprogress = {
                "status"
            }
        }
    },
    qeo = {
        initial = "idle",
        transitions = {
            idle = {
                qeo_reg_inprogress = "inprogress",
                qeo_reg_unreg = "unreg"
            },
            inprogress = {
                qeo_reg_idle = "idle"
            },
            unreg = {
                qeo_reg_idle = "idle"
            }
        },
        actions = {
            idle = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                staticLed("power:blue", false),
                staticLed("power:green", true)
            },
            inprogress = {
                staticLed("power:orange", false),
                staticLed("power:red", false),
                timerLed("power:blue", 250, 250),
                staticLed("power:green", false)
            },
            unreg = {
               staticLed("power:orange", false),
               staticLed("power:blue", false),
               timerLed("power:red", 250, 250),
               staticLed("power:green", false)
            }
        }
    },
    dect = {
        initial = "dectprofile_unusable",
        transitions = {
            dectprofile_unusable = {
                dect_unregistered_usable = "dectprofile_usable",
                dect_registered_usable = "dectprofile_usable",
                dect_registering_usable = "registering",
                dect_registering_unusable = "registering"
            },
            dectprofile_usable = {
                dect_unregistered_unusable = "dectprofile_unusable",
                dect_registered_unusable = "dectprofile_unusable",
                dect_registering_usable = "registering",
                dect_registering_unusable = "registering"
            },
            registering = {
                dect_unregistered_unusable = "dectprofile_unusable",
                dect_registered_unusable = "dectprofile_unusable",
                dect_unregistered_usable = "dectprofile_usable",
                dect_registered_usable = "dectprofile_usable"
            }
        },
        actions = {
            dectprofile_usable = {
                staticLed("dect:orange", false),
                staticLed("dect:red", false),
                staticLed("dect:green", true)
            },
            dectprofile_unusable = {
                staticLed("dect:red", false),
                staticLed("dect:green", false),
                staticLed("dect:orange", false)
            },
            registering = {
                staticLed("dect:red", false),
                staticLed("dect:green", true),
                timerLed("dect:orange", 400, 400)
            }
        },
        patterns_depend_on = {
            dectprofile_usable = {
                "status"
            },
            dectprofile_unusable = {
                "status"
            }
        }
    },
    voice = {
          initial = "off",
                transitions = {
                fxs_profiles_usable = {
                        fxs_lines_usable_off = "off",
                        fxs_lines_error = "off",
                        fxs_active = "fxs_profiles_flash"
                },
                fxs_profiles_flash = {
                        fxs_inactive = "fxs_profiles_usable",
                        fxs_lines_usable_off = "off",
                        fxs_lines_error = "off"
                },
                off = {
                        fxs_lines_usable = "fxs_profiles_usable"
                }
          },
          actions = {
             fxs_profiles_usable = {
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
            fxs_profiles_flash = {
                 "status"
            },
            off = {
                 "status"
            }
        }
    }
}
