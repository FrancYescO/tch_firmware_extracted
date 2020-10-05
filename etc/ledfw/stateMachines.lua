-- The only available function is helper (ledhelper)
-- print ("usb name is:"..tostring(connected_device)),
-- usbdevLed("usb:green", connected_device, 'link tx rx'),
local timerLed, staticLed, netdevLed, usb_connected, usbdevLed, netdevLedOWRT = timerLed, staticLed, netdevLed, usb_connected, usbdevLed, netdevLedOWRT

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
                staticLed("power:green", true),
                staticLed("upgrade:green", false)
            },
            upgrade = {
                staticLed("power:red", false),
                staticLed("power:green", false),
                staticLed("upgrade:green", true),
                timerLed("power:orange", 250, 250),
            }
        }
    },
    usb = {
        initial = "usb_init",
        transitions = {
        },
        actions = {
            usb_init = {
				usbdevLed("usb:green", usb_connected(), 'link tx rx'),
            }
        }
    },
    broadband = {                 
        initial = "disconnected",             
        transitions = {                        
            disconnected = {                   
                gpon_ploam_2 = "connecting",   
                gpon_ploam_3 = "connecting",   
                gpon_ploam_4 = "connecting",   
                gpon_ploam_5 = "connected",   
            },                              
            connecting = {                 
                gpon_ploam_1 = "disconnected",
                gpon_ploam_5 = "connected",   
            },                                
            connected = {                   
                gpon_ploam_1 = "disconnected",
                gpon_ploam_2 = "connecting",  
                gpon_ploam_3 = "connecting",  
                gpon_ploam_4 = "connecting",  
                gpon_ploam_6 = "error",       
                gpon_ploam_7 = "error",       
                gpon_ploam_8 = "error",       
            },                                
            error = {                         
                gpon_ploam_1 = "disconnected",
                gpon_ploam_5 = "connected",   
            }                                 
        },                                  
        actions = {                         
            disconnected = {                
                staticLed("broadband:green", false)
            },                                     
            connecting = {                         
                timerLed("broadband:green", 250, 250)
            },                                       
            connected = {                            
                staticLed("broadband:green", true)
            },                                     
            error = {                              
                staticLed("broadband:green", false)
            }                                        
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
                staticLed("pon:green", false),
            },
            internet_connecting = {
                staticLed("pon:green", false),
            },
            internet_connected = {
                netdevLedOWRT("pon:green", 'wan', 'link tx rx'),
            }

        }
    },
    ethernet = {
        initial = "ethernet",
        transitions = {
        },
        actions = {
            ethernet = {
                netdevLed("ethernet:green", 'bcmsw', 'link tx rx')
            }
        }
    },
    wifi = {
        initial = "wifi_off",
        transitions = {
            wifi_off = {
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_wep_wl0 = "wifi_wep",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            },
            wifi_nosecurity = {
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_wep_wl0 = "wifi_wep",
            },
            wifi_wep = {
                wifi_state_off_wl0 = "wifi_off",
                wifi_security_wpapsk_wl0 = "wifi_security",
                wifi_security_wpa_wl0 = "wifi_security",
                wifi_security_disabled_wl0 = "wifi_nosecurity",
            },
            wifi_security = {
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
                wifi_wps_idle = "idle"
            },
            setup_locked = {
                wifi_wps_off = "off",
                wifi_wps_idle = "idle"
            },
            error = {
                wifi_wps_off = "off",
                wifi_wps_idle = "idle"
            },
            session_overlap = {
                wifi_wps_off = "off",
                wifi_wps_idle = "idle"
            },
            off = {
                wifi_wps_inprogress = "inprogress",
                wifi_wps_idle = "idle"
            }

        },
        actions = {
            idle = {
                staticLed("wps:red", false),
                staticLed("wps:green", false)
            },
            session_overlap = {
                timerLed("wps:red", 1000, 1000),
                staticLed("wps:green", false)
            },
            error = {
                timerLed("wps:red", 100, 100),
                staticLed("wps:green", false)
            },
            setup_locked = {
                staticLed("wps:red", false),
                staticLed("wps:green", true)
            },
            off = {
                staticLed("wps:red", false),
                staticLed("wps:green", false)
            },
            inprogress ={
                timerLed("wps:red", 200, 100),
                timerLed("wps:green", 200, 100)
            }
        }
    },
    voice1 = {
        initial = "off",
        transitions = {
            off = {
                voice1_on = "on",
                voice1_solid = "solid",
                voice1_flash = "flash",
            },
            on = {
                voice1_off = "off",
                voice1_solid = "solid",
                voice1_flash = "flash",
            },
            solid = {
                voice1_off = "off",
                voice1_on = "on",
                voice1_flash = "flash",
            },
            flash = {
                voice1_off = "off",
                voice1_on = "on",
                voice1_solid = "solid",
            },

        },
        actions = {
            off = {
                staticLed("fxs1:green", false),
            },
            on = {
                staticLed("fxs1:green", true),
            },
            solid = {
                staticLed("fxs1:green", true),
            },
            flash = {
                timerLed("fxs1:green", 250, 250)
            },
        }
    },
    voice2 = {
        initial = "off",
        transitions = {
            off = {
                voice2_on = "on",
                voice2_solid = "solid",
                voice2_flash = "flash",
            },
            on = {
                voice2_off = "off",
                voice2_solid = "solid",
                voice2_flash = "flash",
            },
            solid = {
                voice2_off = "off",
                voice2_on = "on",
                voice2_flash = "flash",
            },
            flash = {
                voice2_off = "off",
                voice2_on = "on",
                voice2_solid = "solid",
            },

        },
        actions = {
            off = {
                staticLed("fxs2:green", false),
            },
            on = {
                staticLed("fxs2:green", true),
            },
            solid = {
                staticLed("fxs2:green", true),
            },
            flash = {
                timerLed("fxs2:green", 250, 250)
            },
        }
    }
}

