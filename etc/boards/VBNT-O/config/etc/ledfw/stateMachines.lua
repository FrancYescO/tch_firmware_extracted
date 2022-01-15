-- The only available function is helper (ledhelper)
local timerLed, staticLed, runFunc, patternLed = timerLed, staticLed, runFunc, patternLed

patterns = {
    reset_status = {
        state = "reset_noaction",
        transitions = {
            reset_noaction = {
                reset_pressed = "reset_prepare",
            },
            reset_prepare = {
                reset_abort = "reset_noaction",
                reset_factory = "reset_ongoing",
            },
            reset_ongoing = {
                reset_complete = "reset_noaction",
            },
        },
        actions = {
            reset_prepare = {
                staticLed("broadband:red", false),
                staticLed("broadband:orange", false),
                timerLed("broadband:green", 150, 150),
            },
            reset_ongoing = {
                staticLed("broadband:red", false),
                staticLed("broadband:orange", false),
                timerLed("broadband:green", 400, 400),
            },
        }
    }
}

stateMachines = {
    ambient = {
        initial = "ambient_off",
        transitions = {
            ambient_loop = {
                service_led_on = "ambient_off",
                service_led_off = "ambient_on",
            },
            ambient_off = {
                service_led_off = "ambient_off", --always off in generic
            },
            ambient_on = {
                service_led_on = "ambient_off",
            },
        },
        actions = {
            ambient_loop = {
                patternLed("ambient1:white", "10000000", 500),
                patternLed("ambient2:white", "01000001", 500),
                patternLed("ambient3:white", "00100010", 500),
                patternLed("ambient4:white", "00010100", 500),
                patternLed("ambient5:white", "00001000", 500),
            },
            ambient_on = {
                staticLed("ambient1:white", true),
                staticLed("ambient2:white", true),
                staticLed("ambient3:white", true),
                staticLed("ambient4:white", true),
                staticLed("ambient5:white", true),
            },
            ambient_off = {
                staticLed("ambient1:white", false),
                staticLed("ambient2:white", false),
                staticLed("ambient3:white", false),
                staticLed("ambient4:white", false),
                staticLed("ambient5:white", false),
            },
        },
    },
    broadband = {
        initial = "initial_idle", --initializing
        transitions = {
            initial_idle = {
                system_startup_complete = "red_solid",  -- if no line and initializing completed
                xdsl_0 = "red_solid", --link synchronizing failed
                xdsl_1 = "synchronizing_red_flashing", -- training
                xdsl_2 = "synchronizing_red_flashing", -- for ADSL
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_5 = "synchronizing_red_flashing", -- Showtime
                xdsl_6 = "synchronizing_red_flashing", -- for VDSL
                network_device_eth_wan_ifup = "synchronizing_red_flashing", -- starts eth wan synchronizing
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifup = "green_solid",
                network_interface_wan_ifdown = "synchronizing_red_flashing",
            },
            synchronizing_red_flashing = {  --status: synchronizing or retrieving IP
                xdsl_0 = "red_solid", --link synchronizing failed
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifup = "green_solid",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            green_solid = {  --status: ip connected
                xdsl_0 = "red_solid", --xdsl synchronizing failed
                xdsl_1 = "synchronizing_red_flashing",
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                -- xdsl_5 is Showtime staus, don't response when layer3 interface UP.
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifdown = "synchronizing_red_flashing",
                ping_failed = "serviceko_red_flashing",
                ping_success = "serviceok_green_flashing_quickly",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            serviceko_red_flashing = {  --status: ping failed
                xdsl_0 = "red_solid", --xdsl synchronizing failed
                xdsl_1 = "synchronizing_red_flashing",
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifdown = "synchronizing_red_flashing",
                ping_success = "serviceok_green_flashing_quickly",
                ping_failed = "serviceko_red_flashing",
                broadband_led_timeout = "green_solid",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            red_solid = {  --status: link synchronizing failed or no line
                xdsl_1 = "synchronizing_red_flashing", -- starts xdsl synchronizing
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_5 = "synchronizing_red_flashing",
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifup = "synchronizing_red_flashing", -- starts eth wan synchronizing
                network_interface_wan_ifup = "green_solid",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            serviceok_green_flashing_quickly = {  --status: ping success
                xdsl_0 = "red_solid", --xdsl synchronizing failed
                xdsl_1 = "synchronizing_red_flashing",
                xdsl_2 = "synchronizing_red_flashing",
                xdsl_3 = "synchronizing_red_flashing",
                xdsl_4 = "synchronizing_red_flashing",
                xdsl_6 = "synchronizing_red_flashing",
                network_device_eth_wan_ifdown = "red_solid", -- eth wan down
                network_interface_wan_ifdown = "synchronizing_red_flashing",
                ping_failed = "serviceko_red_flashing",
                broadband_led_timeout = "green_solid",
                fwupgrade_state_upgrading = "writing_firmware_green_flashing_quickly",
            },
            writing_firmware_green_flashing_quickly = {  --status: writing firmware
                fwupgrade_state_failed = "serviceko_red_flashing",
            },
        },
        actions = {
            initial_idle = {
                staticLed("broadband:green", false),
                staticLed("broadband:red", false),
            },
            nolink_red_solid = {
                staticLed("broadband:green", false),
                staticLed("broadband:red", true),
            },
            green_solid = {
                staticLed("broadband:red", false),
                staticLed("broadband:green", true),
            },
            serviceok_green_flashing_quickly = {
                staticLed("broadband:red", false),
                timerLed("broadband:green", 250, 250),
            },
            writing_firmware_green_flashing_quickly = {
                staticLed("broadband:red", false),
                timerLed("broadband:green", 250, 250),
            },
            red_solid = {
                staticLed("broadband:red", true),
                staticLed("broadband:green", false),
            },
            synchronizing_red_flashing = {
                staticLed("broadband:green", false),
                timerLed("broadband:red", 250, 250),
            },
            serviceko_red_flashing = {
                staticLed("broadband:green", false),
                timerLed("broadband:red", 250, 250),
            },
        },
        patterns_depend_on = {
            initial_idle = {"reset_status"},
            nolink_red_solid = {"reset_status"},
            green_solid = {"reset_status"},
            serviceok_green_flashing_quickly = {"reset_status"},
            writing_firmware_green_flashing_quickly = {"reset_status"},
            red_solid = {"reset_status"},
            synchronizing_red_flashing = {"reset_status"},
            serviceko_red_flashing = {"reset_status"},
        },
    },

    wireless = {
        initial = "wireless_off",
        transitions = {
            wireless_off = {
                wifi_radio_on = "green_solid",
                wifi_both_radio_off = "red_solid",
            },
            red_solid = {
                wifi_radio_on = "green_solid",
            },
            green_solid = {
                wifi_both_radio_off = "red_solid",
            },
        },
        actions = {
            green_solid = {
                staticLed("wireless:orange", false),
                staticLed("wireless:red", false),
                staticLed("wireless:green", true),
            },
            red_solid = {
                staticLed("wireless:green", false),
                staticLed("wireless:orange", false),
                staticLed("wireless:red", true),
            },
            wireless_off = {
                staticLed("wireless:green", false),
                staticLed("wireless:orange", false),
                staticLed("wireless:red", false),
            },
        },
    },

    wps = {
        initial = "wpsled_off",  --initially the wps led is off
        transitions = {
            wpsled_off = {
                wps_activate_radio = "green_solid",
                wps_registration_ongoing = "wps_ongoing_green_flashing",
                wps_registration_fail = "wps_registration_fail_red_solid",
            },
            wps_ongoing_green_flashing = {
                wps_registration_success = "green_solid",
                wps_registration_fail = "wps_registration_fail_red_solid",
            },
            green_solid = {
                wps_registration_ongoing = "wps_ongoing_green_flashing",
                wps_led_timeout = "wpsled_off",
            },
            wps_registration_fail_red_solid = {
                wps_registration_ongoing = "wps_ongoing_green_flashing",
                wps_led_timeout = "wpsled_off",
            },
        },
        
        actions = {
            wpsled_off = {
                staticLed("wps:green", false),
                staticLed("wps:red", false),
                staticLed("wps:orange", false),
            },
            wps_ongoing_green_flashing = {
                staticLed("wps:red", false),
                staticLed("wps:orange", false),
                timerLed("wps:green", 250, 250),
            },
            green_solid = {
                staticLed("wps:red", false),
                staticLed("wps:orange", false),
                staticLed("wps:green", true), -- true must be set at last
            },
            wps_registration_fail_red_solid = {
                staticLed("wps:green", false),
                staticLed("wps:orange", false),
                staticLed("wps:red", true), -- true must be set at last
            },
        },
    },
}
