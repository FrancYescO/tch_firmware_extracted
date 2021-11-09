local timerLed, staticLed, patternLed, runFunc = timerLed, staticLed, patternLed, runFunc
local onBoarded=false

local function SetOnBoarded(state)
   onBoarded = state
end

local function IsOnboarded()
   return onBoarded
end

local function WPSBeginState()
   return IsOnboarded() and "wait_rssi" or "disconnected"
end

local function SignalState(sig_state)
   SetOnBoarded(true)
   return sig_state
end

patterns = {
  remote_mgmt = {
    state = "remote_mgmt_session_ends",
    transitions = {
      remote_mgmt_session_ends = {},
      remote_mgmt_session_begins = {}
    },
    actions = {
      remote_mgmt_session_begins = {
        staticLed("wps:red", false),
        timerLed("wps:green", 500, 500)
      }
    }
  },
  show_rssi = {
    state = "rssi_on",
    transitions = {
      rssi_on = {},
      rssi_off = {}
    },
    actions = {
      rssi_off = {
        staticLed("wps:orange", false )
      }
    }
  },
  rtfd = {
    state = "reset_button_released",
    transitions = {
        reset_button_released = {},
        rtfd_in_progress = {},
    },
    actions = {
        rtfd_in_progress = {
            staticLed("wps:green", false),
            timerLed("wps:red", 1000, 1000),
        }
    }
  },
}

stateMachines = {
  wps = {
    initial = "not_ready",
    transitions = {
      -- 'from' state name
      not_ready = {
        wifi_state_on = "disconnected",
        onboarding_initiated = "inprogress",
        -- *** Do sth. to go directly to check_rssi if already onboarded
        bad_connection = {SignalState,"bad_signal"},
        average_connection = {SignalState,"average_signal"},
        good_connection = {SignalState,"good_signal"},
        easymesh_onboarding_inprogress = "easymesh_onboarding",
      },
      disconnected = {
        -- edge name = 'to' state name
        onboarding_initiated = "inprogress",
        -- *** Do sth. to go directly to check_rssi if already onboarded
        bad_connection = {SignalState,"bad_signal"},
        average_connection = {SignalState,"average_signal"},
        good_connection = {SignalState,"good_signal"},
        easymesh_onboarding_inprogress = "easymesh_onboarding",
        --easymesh_onboarding_na = "easymesh_nok",
      },
      inprogress = {
        wifi_wps_success = "success",
        wifi_wps_session_overlap = "session_overlap",
        wifi_wps_error = "error",
      },
      success = {
        --wifi_wps_off = "wait_rssi",
        --wifi_wps_idle = "wait_rssi",
        wps_show_final_state_end = "wait_rssi",
        --backhaul_disconnect = "disconnected",
        wps_client_session_begins = "inprogress",
        easymesh_onboarding_inprogress = "easymesh_onboarding",
        easymesh_onboarding_na = "easymesh_nok",
      },
      wait_rssi = {
        bad_connection = "bad_signal",
        average_connection = "average_signal",
        good_connection = "good_signal",
        onboarding_initiated = "inprogress",
        backhaul_disconnect = "disconnected", --delete or not ??? should a disconnect here  go to disconnected state ? Maybe there was no rssi reporting yet ?! TBI
        easymesh_onboarding_inprogress = "easymesh_onboarding",
        easymesh_onboarding_na = "easymesh_nok",
      },
      error = {
        --wifi_wps_off = WPSBeginState,
        --wifi_wps_idle = WPSBeginState,
        wps_show_final_state_end = WPSBeginState,
        onboarding_initiated = "inprogress",
        wps_client_session_begins = "inprogress",
        onboarding_failed = { nil, { SetOnBoarded, false } },
      },
      session_overlap = {
        --wifi_wps_off = WPSBeginState,
        --wifi_wps_idle = WPSBeginState,
        wps_show_final_state_end = WPSBeginState,
        onboarding_initiated = "inprogress",
        wps_client_session_begins = "inprogress",
        onboarding_failed = { nil, { SetOnBoarded, false } },
      },
      easymesh_onboarding = {
        easymesh_onboarding_ok = "wait_rssi",
        easymesh_onboarding_nok = "easymesh_nok",
        easymesh_onboarding_na = "easymesh_nok",
      },
      easymesh_ok = {
        easymesh_onboarding_ok = "wait_rssi",
        easymesh_onboarding_na = "easymesh_nok",
        easymesh_onboarding_inprogress = "easymesh_onboarding",
      },
      easymesh_nok = {
        onboarding_initiated = "inprogress",
        wps_client_session_begins = "inprogress",
        easymesh_onboarding_inprogress = "easymesh_onboarding",
      },
      bad_signal = {
        average_connection = "average_signal",
        good_connection = "good_signal",
        backhaul_disconnect = "disconnected",
        wps_client_session_begins = "inprogress",
        easymesh_onboarding_inprogress = "easymesh_onboarding",
        easymesh_onboarding_na = "easymesh_nok",
      },
      average_signal = {
        bad_connection = "bad_signal",
        good_connection = "good_signal",
        backhaul_disconnect = "disconnected",
        wps_client_session_begins = "inprogress",
        easymesh_onboarding_inprogress = "easymesh_onboarding",
        easymesh_onboarding_na = "easymesh_nok",
      },
      good_signal = {
        bad_connection = "bad_signal",
        average_connection = "average_signal",
        backhaul_disconnect = "disconnected",
        wps_client_session_begins = "inprogress",
        easymesh_onboarding_inprogress = "easymesh_onboarding",
        easymesh_onboarding_na = "easymesh_nok",
      },
    },

    actions = {
      not_ready = {
        timerLed("wps:orange", 250, 250),
      },
      disconnected = {
        --staticLed("wps:green", false),
        timerLed("wps:orange", 1000, 1000),
        runFunc(SetOnBoarded, false),
      },
      inprogress = {
        staticLed("wps:orange",false),
        timerLed("wps:green", 2000, 1000),
      },
      success = {
        staticLed("wps:green", true),
        staticLed("wps:red", false),
      },
      wait_rssi = {
        runFunc(SetOnBoarded, true),
      },
      error = {
        --staticLed("wps:orange", false),
        staticLed("wps:green", false),
        timerLed("wps:red", 250, 250),
      },
      session_overlap = {
        --staticLed("wps:orange", false),
        staticLed("wps:green", false),
        patternLed("wps:red", "8080808000", 250),
      },
      easymesh_onboarding = {
        staticLed("wps:green", true),
        timerLed("wps:red", 1000, 1000),
      },
      easymesh_ok = {
        staticLed("wps:green", true),
        timerLed("wps:red", 1000, 3000),
      },
      easymesh_nok = {
        staticLed("wps:green", true),
        timerLed("wps:red", 3000, 1000),
      },
      bad_signal = {
        staticLed("wps:orange",false),
        staticLed("wps:green", false),
        staticLed("wps:red", true),
      },
      average_signal = {
        staticLed("wps:orange", true),
      },
      good_signal = {
        staticLed("wps:orange",false),
        staticLed("wps:red", false),
        staticLed("wps:green", true),
      },
    },

    patterns_depend_on = {
      disconnected = { "remote_mgmt", "rtfd" },
      inprogress = { "remote_mgmt", "rtfd" },
      success = { "remote_mgmt", "rtfd" },
      wait_rssi = { "remote_mgmt", "show_rssi", "rtfd" },
      error = { "remote_mgmt", "rtfd" },
      session_overlap = { "remote_mgmt", "rtfd" },
      easymesh_onboarding = { "remote_mgmt", "rtfd" },
      easymesh_ok = { "remote_mgmt", "rtfd" },
      easymesh_nok = { "remote_mgmt", "rtfd" },
      bad_signal = { "remote_mgmt", "show_rssi", "rtfd" },
      average_signal = { "remote_mgmt", "show_rssi", "rtfd" },
      good_signal = { "remote_mgmt", "show_rssi", "rtfd" },
    },
  }
}
