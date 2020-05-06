-- The only available function is helper (ledhelper)
local timerLed, staticLed, netdevLed, netdevLedOWRT = timerLed, staticLed, netdevLed, netdevLedOWRT
local wl1_ifname = get_wl1_ifname()

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
                staticLed("iptv:green", false),
                staticLed("iptv:red", false),
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
                staticLed("power:blue", true),
                staticLed("power:green", false)
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
                network_interface_mgmt_ifup = "internet_mgmt_connected",
                network_interface_wan_ifup = "internet_wan_connected",
                network_interface_broadband_ifup = "internet_connecting",
                xdsl_5 = "internet_connecting",
            },
            internet_connecting = {
                network_interface_broadband_ifdown = "internet_disconnected",
                xdsl_0 = "internet_disconnected",
                network_interface_mgmt_ifdown = "internet_disconnected",
                network_interface_mgmt_ifup = "internet_mgmt_connected",
                network_interface_wan_ifdown = "internet_disconnected",
                network_interface_wan_ifup = "internet_wan_connected",
            },
            internet_mgmt_connected = {
                network_interface_mgmt_ifdown = "internet_disconnected",
                xdsl_0 = "internet_disconnected"
            },
            internet_wan_connected = {
                network_interface_wan_ifdown = "internet_disconnected",
                xdsl_0 = "internet_disconnected"
            },
        },
        actions = {
            internet_disconnected = {
                staticLed("internet:green", false),
                staticLed("internet:red", false)
            },
            internet_connecting = {
                staticLed("internet:green", false),
-- timerLed("internet:red", 500, 500), was not behaving as expected; using same values since last time when setting timerLed for same LED can cause LED *NOT* to blink at all;
-- Probably LED driver problem; workaround is setting twice with different values
                timerLed("internet:red", 498, 502),
                timerLed("internet:red", 499, 501)
            },
            internet_mgmt_connected = {
                netdevLedOWRT("internet:green", 'mgmt', 'link tx rx'),
                staticLed("internet:red", false)
            },
            internet_wan_connected = {
                netdevLedOWRT("internet:green", 'wan', 'link tx rx'),
                staticLed("internet:red", false)
            },
        },
        patterns_depend_on = {
            internet_disconnected = {"status"},
            internet_connecting = {"status"},
            internet_wan_connected = {"status"},
            internet_mgmt_connected = {"status"},
        }
    },
    iptv = {
        initial = "iptv_disconnected",
        transitions = {
            iptv_disconnected = {
                network_interface_iptv_ifup = "iptv_connected",
            },
            iptv_connected = {
                network_interface_iptv_ifdown = "iptv_disconnected",
            }
        },
        actions = {
            iptv_disconnected = {
                staticLed("iptv:green", false),
                staticLed("iptv:red", true)
            },
            iptv_connected = {
                staticLed("iptv:green", true),
                staticLed("iptv:red", false)
            }
        },
        patterns_depend_on = {
            iptv_disconnected = {
                "status"
            },
            iptv_connected = {
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
                wifi_sta_con_wl0 = "wifi_on_sc",
                wifi_no_sta_con_wl0 = "wifi_on_nsc",
            },
            wifi_on_nsc = {
                wifi_state_off_wl0 = "wifi_off",
                wifi_acl_on_wl0 = "wifi_acl",
                wifi_sta_con_wl0 = "wifi_on_sc",
            },
            wifi_on_sc = {
                wifi_state_off_wl0 = "wifi_off",
                wifi_acl_on_wl0 = "wifi_acl",
                wifi_no_sta_con_wl0 = "wifi_on_nsc",
            },
            wifi_acl = {
                wifi_acl_off_wl0 = "wifi_off",
            }
        },
        actions = {
            wifi_off = {
                staticLed("wireless:green", false),
            },
            wifi_on_nsc = {
                staticLed("wireless:green", true),
            },
            wifi_on_sc = {
                netdevLed("wireless:green", 'wl0', 'link tx rx')
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
    wifi_5G = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_sta_con_wl1 = "wifi_on_sc",
                wifi_no_sta_con_wl1 = "wifi_on_nsc",
            },
            wifi_on_nsc = {
                wifi_state_off_wl1 = "wifi_off",
                wifi_acl_on_wl1 = "wifi_acl",
                wifi_sta_con_wl1 = "wifi_on_sc",
            },
            wifi_on_sc = {
                wifi_state_off_wl1 = "wifi_off",
                wifi_acl_on_wl1 = "wifi_acl",
                wifi_no_sta_con_wl1 = "wifi_on_nsc",
            },
            wifi_acl = {
                wifi_acl_off_wl1 = "wifi_off",
            }
        },
        actions = {
            wifi_off = {
                staticLed("wireless_5g:green", false),
            },
            wifi_on_nsc = {
                staticLed("wireless_5g:green", true),
            },
            wifi_on_sc = {
                netdevLed("wireless_5g:green", wl1_ifname, 'link tx rx')
            },
            wifi_acl = {
                timerLed("wireless_5g:green", 498, 502),
                timerLed("wireless_5g:green", 499, 501)
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
                dect_registering_unusable = "registering",
                dect_active = "dect_inuse"
            },
            dect_inuse = {
                dect_unregistered_unusable = "dectprofile_unusable",
                dect_registered_unusable = "dectprofile_unusable",
                dect_registering_usable = "registering",
                dect_registering_unusable = "registering",
                dect_inactive = "dectprofile_usable"
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
            dect_inuse = {
                timerLed("dect:green", 125, 125),
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
                fxs_profiles_usable_false = "off",
                callstate_MMPBX_CALLSTATE_HAS_CALL = "fxs_profiles_in_call"
            },
            fxs_profiles_in_call = {
                callstate_MMPBX_CALLSTATE_NO_CALL = "fxs_profiles_usable",
                fxs_profiles_usable_false = "off"
            },
            off = {
                fxs_profiles_usable_true = "fxs_profiles_usable"
            }
        },
        actions = {
            fxs_profiles_usable = {
                staticLed("voip:green", true)
            },
            fxs_profiles_in_call = {
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
            fxs_profiles_in_call = {
                 "status"
            },
            off = {
                 "status"
            }
        }
    }
}
