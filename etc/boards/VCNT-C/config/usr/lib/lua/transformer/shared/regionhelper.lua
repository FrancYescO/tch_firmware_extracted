local M = {}

local lfs = require("lfs")
local uci_helper = require("transformer.mapper.ucihelper")
local set_on_uci = uci_helper.set_on_uci
local binding = {}

local region_se = {
  { "mmpbx", "syslog", "service_config", "1" },
  { "mmpbx", "syslog", "service_actions", "1" },
  { "mmpbx", "syslog", "calls", "1" },
  { "mmpbx", "syslog", "hide_user_identity", "1" },
  { "mmpbx", "scc_call_return_activate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_return_deactivate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_return_invoke", "datamodel_disabled", "1" },
  { "mmpbx", "scc_barge_in_activate", "scc", "scc_generic" },
  { "mmpbx", "scc_barge_in_activate", "service_base", "profile" },
  { "mmpbx", "scc_barge_in_activate", "pattern", "*70" },
  { "mmpbx", "scc_barge_in_activate", "service_type", "BARGE_IN" },
  { "mmpbx", "scc_barge_in_activate", "action", "activate" },
  { "mmpbx", "scc_barge_in_activate", "enabled", "0" },
  { "mmpbx", "scc_barge_in_activate", "datamodel_disabled", "0" },
  { "mmpbx", "scc_barge_in_deactivate", "scc", "scc_generic" },
  { "mmpbx", "scc_barge_in_deactivate", "service_base", "profile" },
  { "mmpbx", "scc_barge_in_deactivate", "pattern", "#70" },
  { "mmpbx", "scc_barge_in_deactivate", "service_type", "BARGE_IN" },
  { "mmpbx", "scc_barge_in_deactivate", "action", "deactivate" },
  { "mmpbx", "scc_barge_in_deactivate", "enabled", "0" },
  { "mmpbx", "scc_barge_in_deactivate", "datamodel_disabled", "0" },
  { "mmpbx", "scc_call_waiting_activate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_waiting_deactivate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_waiting_interrogate", "datamodel_disabled", "1" },
  { "mmpbx", "single_freq_425_5", "frequency", {"425"} },
  { "mmpbx", "single_freq_425_5", "power", {"-5"} },
  { "mmpbx", "single_freq_425_10", "frequency", {"425"} },
  { "mmpbx", "single_freq_425_10", "power", {"-10"} },
  { "mmpbx", "single_freq_425_16", "frequency", {"425"} },
  { "mmpbx", "single_freq_425_16", "power", {"-16"} },
  { "mmpbx", "single_freq_1400_16", "frequency", {"1400"} },
  { "mmpbx", "single_freq_1400_16", "power", {"-16"} },
  { "mmpbx", "single_freq_1400_20", "frequency", {"1400"} },
  { "mmpbx", "single_freq_1400_20", "power", {"-20"} },
  { "mmpbx", "dual_freq_765_20_850_20", "frequency", {"765", "850"} },
  { "mmpbx", "dual_freq_765_20_850_20", "power", {"-20", "-20"} },
  { "mmpbx", "dial", "delay", "0" },
  { "mmpbx", "dial", "repeat_after", "-1" },
  { "mmpbx", "dial", "play", {"single_freq_425_5"} },
  { "mmpbx", "dial", "duration", {"-1"} },
  { "mmpbx", "callhold", "delay", "0" },
  { "mmpbx", "callhold", "repeat_after", "-1" },
  { "mmpbx", "callhold", "play", {"single_freq_1400_16", "silence"} },
  { "mmpbx", "callhold", "duration", {"400", "15000"} },
  { "mmpbx", "callhold", "loop_from", {"silence"} },
  { "mmpbx", "callhold", "loop_to", {"single_freq_1400_16"} },
  { "mmpbx", "callhold", "loop_iterations", {"-1"} },
  { "mmpbx", "callwaiting", "delay", "0" },
  { "mmpbx", "callwaiting", "repeat_after", "-1" },
  { "mmpbx", "callwaiting", "play", {"single_freq_425_10", "silence", "single_freq_425_10"} },
  { "mmpbx", "callwaiting", "duration", {"200", "500", "200"} },
  { "mmpbx", "rejection", "delay", "0" },
  { "mmpbx", "rejection", "repeat_after", "-1" },
  { "mmpbx", "rejection", "play", {"dual_freq_765_20_850_20", "silence"} },
  { "mmpbx", "rejection", "duration", {"400", "400"} },
  { "mmpbx", "rejection", "loop_from", {"silence"} },
  { "mmpbx", "rejection", "loop_to", {"dual_freq_765_20_850_20"} },
  { "mmpbx", "rejection", "loop_iterations", {"-1"} },
  { "mmpbx", "confirmation", "delay", "0" },
  { "mmpbx", "confirmation", "repeat_after", "-1" },
  { "mmpbx", "confirmation", "play", {"file_message"} },
  { "mmpbx", "confirmation", "duration", {"-1"} },
  { "mmpbx", "congestion", "delay", "0" },
  { "mmpbx", "congestion", "repeat_after", "-1" },
  { "mmpbx", "congestion", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "congestion", "duration", {"250", "750"} },
  { "mmpbx", "congestion", "loop_from", {"silence"} },
  { "mmpbx", "congestion", "loop_to", {"single_freq_425_10"} },
  { "mmpbx", "congestion", "loop_iterations", {"15"} },
  { "mmpbx", "busy", "delay", "0" },
  { "mmpbx", "busy", "repeat_after", "-1" },
  { "mmpbx", "busy", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "busy", "duration", {"250", "250"} },
  { "mmpbx", "busy", "loop_from", {"single_freq_425_10"} },
  { "mmpbx", "busy", "loop_to", {"silence"} },
  { "mmpbx", "busy", "loop_iterations", {"60"} },
  { "mmpbx", "ringback", "delay", "0" },
  { "mmpbx", "ringback", "repeat_after", "-1" },
  { "mmpbx", "ringback", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "ringback", "duration", {"1000", "5000"} },
  { "mmpbx", "ringback", "loop_from", {"silence"} },
  { "mmpbx", "ringback", "loop_to", {"single_freq_425_10"} },
  { "mmpbx", "ringback", "loop_iterations", {"-1"} },
  { "mmpbx", "mwi", "delay", "0" },
  { "mmpbx", "mwi", "repeat_after", "-1" },
  { "mmpbx", "mwi", "play", {"single_freq_425_10", "silence", "single_freq_425_10"} },
  { "mmpbx", "mwi", "duration", {"1200", "40", "13760"} },
  { "mmpbx", "mwi", "loop_from", {"single_freq_425_10"} },
  { "mmpbx", "mwi", "loop_to", {"silence"} },
  { "mmpbx", "mwi", "loop_iterations", {"-1"} },
  { "mmpbx", "specialdial", "delay", "0" },
  { "mmpbx", "specialdial", "repeat_after", "-1" },
  { "mmpbx", "specialdial", "play", {"single_freq_425_5", "silence"} },
  { "mmpbx", "specialdial", "duration", {"320", "20"} },
  { "mmpbx", "specialdial", "loop_from", {"silence"} },
  { "mmpbx", "specialdial", "loop_to", {"single_freq_425_5"} },
  { "mmpbx", "specialdial", "loop_iterations", {"-1"} },
  { "mmpbx", "stutterdial", "delay", "0" },
  { "mmpbx", "stutterdial", "repeat_after", "-1" },
  { "mmpbx", "stutterdial", "play", {"single_freq_425_5", "silence"} },
  { "mmpbx", "stutterdial", "duration", {"320", "20"} },
  { "mmpbx", "stutterdial", "loop_from", {"silence"} },
  { "mmpbx", "stutterdial", "loop_to", {"single_freq_425_5"} },
  { "mmpbx", "stutterdial", "loop_iterations", {"-1"} },
  { "mmpbx", "release", "delay", "0" },
  { "mmpbx", "release", "repeat_after", "-1" },
  { "mmpbx", "release", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "release", "duration", {"250", "750"} },
  { "mmpbx", "release", "loop_from", {"silence"} },
  { "mmpbx", "release", "loop_to", {"single_freq_425_10"} },
  { "mmpbx", "release", "loop_iterations", {"30"} },
  { "mmpbxrvsipnet", "syslog", "registration", "1" },
  { "mmpbxrvsipnet", "syslog", "call_signalling", "1" },
  { "mmpbxrvsipnet", "syslog", "hide_user_identity", "1" },
  { "mmpbxrvsipnet", "sip_net", "primary_registrar", "0.0.0.0" },
  { "mmpbxrvsipnet", "sip_net", "subscription_event", {"reg"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_notifier", {""} },
  { "mmpbxrvsipnet", "sip_net", "subscription_notifier_port", {""} },
  { "mmpbxrvsipnet", "sip_net", "subscription_expire_time", {"86400"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_refresh_percent", {"99"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_retry_time_min", {"1800"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_retry_time_max", {"2100"} },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "codec_black_list", {"AMR-WB", "G722", "telephone-event"} },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "codec_black_list", {"AMR-WB", "G722", "telephone-event"} },
  { "mmpbxbrcmfxsdev", "syslog", "phone", "1" },
  { "mmpbxbrcmfxsdev", "syslog", "syslog_hide_dialled_digits", "1" },
  { "mmpbxbrcmcountry", "global", "country", "sweden" },
  { "mmpbxbrcmcountry", "dtmf_map", "end_code", "14" },
  { "mmpbxbrcmcountry", "dtmf_map", "private_code", {"13", "1", "0", "14", "127"} },
  { "mmpbxbrcmcountry", "dtmf_map", "unavailable_code", {"13", "1", "0", "14", "127"} },
  { "mmpbxbrcmcountry", "dtmf_map", "error_code", {"127"} },
  { "mmpbxbrcmcountry", "ring_map", "general_ring", {"long", "007800ff", "fff00000"} },
  { "mmpbxbrcmcountry", "ring_map", "splash_ring", {"short", "0", "1f8"} }
}

local region_dk = {
  { "mmpbx", "syslog", "service_config", "1" },
  { "mmpbx", "syslog", "service_actions", "1" },
  { "mmpbx", "syslog", "calls", "1" },
  { "mmpbx", "syslog", "hide_user_identity", "1" },
  { "mmpbx", "incoming_map_internal_profile_0", "device", "fxs_dev_0" },
  { "mmpbx", "service_conference", "provisioned", "0" },
  { "mmpbx", "service_conference", "activated", "0" },
  { "mmpbx", "service_transfer", "provisioned", "0" },
  { "mmpbx", "service_transfer","activated", "0" },
  { "mmpbx", "service_warmline_fxs_dev_0", "provisioned", "0" },
  { "mmpbx", "service_warmline_fxs_dev_1", "provisioned", "0" },
  { "mmpbx", "scc_call_return_activate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_return_deactivate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_return_invoke", "datamodel_disabled", "1" },
  { "mmpbx", "scc_barge_in_activate", "scc", "scc_generic" },
  { "mmpbx", "scc_barge_in_activate", "service_base", "profile" },
  { "mmpbx", "scc_barge_in_activate", "pattern", "*70" },
  { "mmpbx", "scc_barge_in_activate", "service_type", "BARGE_IN" },
  { "mmpbx", "scc_barge_in_activate", "action", "activate" },
  { "mmpbx", "scc_barge_in_activate", "enabled", "0" },
  { "mmpbx", "scc_barge_in_activate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_barge_in_deactivate", "scc", "scc_generic" },
  { "mmpbx", "scc_barge_in_deactivate", "service_base", "profile" },
  { "mmpbx", "scc_barge_in_deactivate", "pattern", "#70" },
  { "mmpbx", "scc_barge_in_deactivate", "service_type", "BARGE_IN" },
  { "mmpbx", "scc_barge_in_deactivate", "action", "deactivate" },
  { "mmpbx", "scc_barge_in_deactivate", "enabled", "0" },
  { "mmpbx", "scc_barge_in_deactivate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_waiting_activate", "datamodel_disabled","1" },
  { "mmpbx", "scc_call_waiting_deactivate", "datamodel_disabled","1" },
  { "mmpbx", "scc_call_waiting_interrogate", "datamodel_disabled","1" },
  { "mmpbx", "scc_call_waiting_activate", "enabled","1" },
  { "mmpbx", "scc_call_waiting_deactivate", "enabled","1" },
  { "mmpbx", "scc_call_waiting_interrogate", "enabled","1" },
  { "mmpbx", "single_freq_425_5", "frequency", {"425"} },
  { "mmpbx", "single_freq_425_5", "power", {"-5"} },
  { "mmpbx", "single_freq_425_10", "frequency", {"425"} },
  { "mmpbx", "single_freq_425_10", "power", {"-10"} },
  { "mmpbx", "single_freq_425_16", "frequency", {"425"} },
  { "mmpbx", "single_freq_425_16", "power", {"-16"} },
  { "mmpbx", "single_freq_1400_16", "frequency", {"1400"} },
  { "mmpbx", "single_freq_1400_16", "power", {"-16"} },
  { "mmpbx", "single_freq_1400_20", "frequency", {"1400"} },
  { "mmpbx", "single_freq_1400_20", "power", {"-20"} },
  { "mmpbx", "single_freq_765_10", "frequency", {"765"} },
  { "mmpbx", "single_freq_765_10", "power", {"-10"} },
  { "mmpbx", "dial", "delay", "0" },
  { "mmpbx", "dial", "repeat_after", "-1" },
  { "mmpbx", "dial", "play", {"single_freq_425_5"} },
  { "mmpbx", "dial", "duration", {"15000"} },
  { "mmpbx", "callhold", "delay", "0" },
  { "mmpbx", "callhold", "repeat_after", "-1" },
  { "mmpbx", "callhold", "play", {"single_freq_1400_16", "silence"} },
  { "mmpbx", "callhold", "duration", {"400", "15000"} },
  { "mmpbx", "callhold", "loop_from", {"silence"} },
  { "mmpbx", "callhold", "loop_to", {"single_freq_1400_16"} },
  { "mmpbx", "callhold", "loop_iterations", {"-1"} },
  { "mmpbx", "callwaiting", "delay", "0" },
  { "mmpbx", "callwaiting", "repeat_after", "3600" },
  { "mmpbx", "callwaiting", "play", {"single_freq_425_10", "silence", "single_freq_425_10"} },
  { "mmpbx", "callwaiting", "duration", {"200", "200", "200"} },
  { "mmpbx", "rejection", "delay", "0" },
  { "mmpbx", "rejection", "repeat_after", "-1" },
  { "mmpbx", "rejection", "play", {"single_freq_765_10", "silence"} },
  { "mmpbx", "rejection", "duration", {"400", "400"} },
  { "mmpbx", "rejection", "loop_from", {"single_freq_765_10"} },
  { "mmpbx", "rejection", "loop_to", {"silence"} },
  { "mmpbx", "rejection", "loop_iterations", {"-1"} },
  { "mmpbx", "confirmation", "delay", "0" },
  { "mmpbx", "confirmation", "repeat_after", "-1" },
  { "mmpbx", "confirmation", "play", {"single_freq_765_10", "silence"} },
  { "mmpbx", "confirmation", "duration", {"1000", "5000"} },
  { "mmpbx", "confirmation", "loop_from", {"silence"} },
  { "mmpbx", "confirmation", "loop_to", {"single_freq_765_10"} },
  { "mmpbx", "confirmation", "loop_iterations", {"-1"} },
  { "mmpbx", "congestion", "delay", "0" },
  { "mmpbx", "congestion", "repeat_after", "-1" },
  { "mmpbx", "congestion", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "congestion", "duration", {"250", "250"} },
  { "mmpbx", "congestion", "loop_from", {"silence"} },
  { "mmpbx", "congestion", "loop_to", {"single_freq_425_10"} },
  { "mmpbx", "congestion", "loop_iterations", {"140"} },
  { "mmpbx", "busy", "delay", "0" },
  { "mmpbx", "busy", "repeat_after", "-1" },
  { "mmpbx", "busy", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "busy", "duration", {"250", "250"} },
  { "mmpbx", "busy", "loop_from", {"silence"} },
  { "mmpbx", "busy", "loop_to", {"single_freq_425_10"} },
  { "mmpbx", "busy", "loop_iterations", {"140"} },
  { "mmpbx", "ringback", "delay", "0" },
  { "mmpbx", "ringback", "repeat_after", "-1" },
  { "mmpbx", "ringback", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "ringback", "duration", {"1000", "4000"} },
  { "mmpbx", "ringback", "loop_from", {"silence"} },
  { "mmpbx", "ringback", "loop_to", {"single_freq_425_10"} },
  { "mmpbx", "ringback", "loop_iterations", {"-1"} },
  { "mmpbx", "mwi", "delay", "0" },
  { "mmpbx", "mwi", "repeat_after", "-1" },
  { "mmpbx", "mwi", "play", {"single_freq_425_10", "silence", "single_freq_425_10"} },
  { "mmpbx", "mwi", "duration", {"1200", "40", "13760"} },
  { "mmpbx", "mwi", "loop_from", {"single_freq_425_10"} },
  { "mmpbx", "mwi", "loop_to", {"silence"} },
  { "mmpbx", "mwi", "loop_iterations", {"-1"} },
  { "mmpbx", "specialdial", "delay", "0" },
  { "mmpbx", "specialdial", "repeat_after", "-1" },
  { "mmpbx", "specialdial", "play", {"single_freq_425_5", "silence"} },
  { "mmpbx", "specialdial", "duration", {"320", "20"} },
  { "mmpbx", "specialdial", "loop_from", {"silence"} },
  { "mmpbx", "specialdial", "loop_to", {"single_freq_425_5"} },
  { "mmpbx", "specialdial", "loop_iterations", {"-1"} },
  { "mmpbx", "stutterdial", "delay", "0" },
  { "mmpbx", "stutterdial", "repeat_after", "-1" },
  { "mmpbx", "stutterdial", "play", {"single_freq_425_5", "silence"} },
  { "mmpbx", "stutterdial", "duration", {"320", "20"} },
  { "mmpbx", "stutterdial", "loop_from", {"silence"} },
  { "mmpbx", "stutterdial", "loop_to", {"single_freq_425_5"} },
  { "mmpbx", "stutterdial", "loop_iterations", {"-1"} },
  { "mmpbx", "release", "delay", "0" },
  { "mmpbx", "release", "repeat_after", "-1" },
  { "mmpbx", "release", "play", {"single_freq_425_10", "silence"} },
  { "mmpbx", "release", "duration", {"250", "250"} },
  { "mmpbx", "release", "loop_from", {"silence"} },
  { "mmpbx", "release", "loop_to", {"single_freq_425_10"} },
  { "mmpbx", "release", "loop_iterations", {"140"} },
  { "mmpbx", "areacode_translation_1", "areacode", "+45" },
  { "mmpbxbrcmcountry", "global", "country", "denmark" },
  { "mmpbxbrcmcountry", "dtmf_map", "end_code", "11" },
  { "mmpbxbrcmcountry", "dtmf_map", "private_code", {"15", "1", "11", "127" } },
  { "mmpbxbrcmcountry", "dtmf_map", "unavailable_code", {"15", "3", "11", "127"} },
  { "mmpbxbrcmcountry", "dtmf_map", "error_code", {"127"} },
  { "mmpbxbrcmcountry", "ring_map", "general_ring", {"long", "00A500ff", "fe000000"} },
  { "mmpbxbrcmcountry", "ring_map", "splash_ring", {"short", "0", "1f8"} },
  { "mmpbxrvsipnet", "syslog", "registration", "1" },
  { "mmpbxrvsipnet", "syslog", "call_signalling", "1" },
  { "mmpbxrvsipnet", "syslog", "hide_user_identity", "1" },
  { "mmpbxrvsipnet", "sip_net", "interface", "wan" },
  { "mmpbxrvsipnet", "sip_net", "primary_proxy", "proxy1.ims.telia.com" },
  { "mmpbxrvsipnet", "sip_net", "primary_registrar", "ims.telia.com" },
  { "mmpbxrvsipnet", "sip_net", "dtmf_relay", "auto" },
  { "mmpbxrvsipnet", "sip_net", "subscription_event", {"reg"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_notifier", {""} },
  { "mmpbxrvsipnet", "sip_net", "subscription_notifier_port", {""} },
  { "mmpbxrvsipnet", "sip_net", "subscription_expire_time", {"86400"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_refresh_percent", {"99"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_retry_time_min", {"1800"} },
  { "mmpbxrvsipnet", "sip_net", "subscription_retry_time_max", {"2100"} },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "cw_cas_delay", "758" },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "codec_black_list", {"AMR-WB", "G722", "telephone-event"} },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "cw_cas_delay", "758" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "codec_black_list", {"AMR-WB", "G722", "telephone-event" } },
  { "mmpbxbrcmfxsdev", "syslog", "phone", "1" },
  { "mmpbxbrcmfxsdev", "syslog", "syslog_hide_dialled_digits", "1" },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hook_flash_timeout", "2000" }
}

local region_lt = {
  { "mmpbx", "global", "no_answer_timeout", "" },
  { "mmpbx", "service_call_waiting_fxs_dev_0", "provisioned", "0" },
  { "mmpbx", "service_call_waiting_fxs_dev_1", "provisioned", "0" },
  { "mmpbx", "service_clir", "provisioned", "1" },
  { "mmpbx", "scc_call_return_activate", "enabled", "0" },
  { "mmpbx", "scc_call_return_activate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_return_deactivate", "enabled", "0" },
  { "mmpbx", "scc_call_return_deactivate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_return_invoke", "enabled", "0" },
  { "mmpbx", "scc_call_return_invoke", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_waiting_activate", "enabled", "0" },
  { "mmpbx", "scc_call_waiting_activate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_waiting_deactivate", "enabled", "0" },
  { "mmpbx", "scc_call_waiting_deactivate", "datamodel_disabled", "1" },
  { "mmpbx", "scc_call_waiting_interrogate", "enabled", "0" },
  { "mmpbx", "scc_call_waiting_interrogate", "datamodel_disabled", "1" },
  { "mmpbx", "media_filter_audio_generic", "network", {"internal_net", "sip_net"} },
  { "mmpbx", "codec_filter_sip_net_pcmu", "fmtp_format_display", "0" },
  { "mmpbx", "codec_filter_sip_net_pcma", "fmtp_format_display", "0" },
  { "mmpbx", "codec_filter_sip_net_g722", "allow", "1" },
  { "mmpbx", "codec_filter_sip_net_g722", "priority", "4" },
  { "mmpbx", "codec_filter_sip_net_g722", "fmtp_format_display", "0" },
  { "mmpbx", "codec_filter_sip_net_g729", "name", "G729" },
  { "mmpbx", "codec_filter_sip_net_g729", "media_filter", "media_filter_audio_generic" },
  { "mmpbx", "codec_filter_sip_net_g729", "allow", "1" },
  { "mmpbx", "codec_filter_sip_net_g729", "priority", "3" },
  { "mmpbx", "codec_filter_sip_net_g729", "remove_silence_suppression", "1" },
  { "mmpbx", "codec_filter_sip_net_g729", "rtp_map", "0" },
  { "mmpbx", "codec_filter_sip_net_g726_24", "name", "G726-24" },
  { "mmpbx", "codec_filter_sip_net_g726_24", "media_filter", "media_filter_audio_generic" },
  { "mmpbx", "codec_filter_sip_net_g726_24", "allow", "1" },
  { "mmpbx", "codec_filter_sip_net_g726_24", "fmtp_format_display", "0" },
  { "mmpbx", "codec_filter_sip_net_g726_24", "priority", "7" },
  { "mmpbx", "codec_filter_sip_net_g726_24", "remove_silence_suppression", "1" },
  { "mmpbx", "codec_filter_sip_net_g726_24", "rtp_map", "1" },
  { "mmpbx", "codec_filter_sip_net_g726_32", "fmtp_format_display", "0" },
  { "mmpbx", "codec_filter_sip_net_g726_32", "priority", "6" },
  { "mmpbx", "codec_filter_sip_net_g726_32", "remove_silence_suppression", "1" },
  { "mmpbx", "codec_filter_sip_net_g726_40", "priority", "5" },
  { "mmpbx", "codec_filter_sip_net_g726_40", "fmtp_format_display", "0" },
  { "mmpbx", "codec_filter_sip_net_g723", "name", "G723" },
  { "mmpbx", "codec_filter_sip_net_g723", "media_filter", "media_filter_audio_generic" },
  { "mmpbx", "codec_filter_sip_net_g723", "allow", "0" },
  { "mmpbx", "codec_filter_sip_net_g723", "remove_silence_suppression", "0" },
  { "mmpbx", "codec_filter_sip_net_g723", "fmtp_format_display", "0" },
  { "mmpbx", "codec_filter_sip_net_g723", "rtp_map", "0" },
  { "mmpbx", "codec_filter_sip_net_telephone_event_8k", "fmtp_format_display", "0" },
  { "mmpbx", "single_freq_dialtone", "frequency", {"425"} },
  { "mmpbx", "single_freq_dialtone", "power", {"-9"} },
  { "mmpbx", "single_freq_hightone", "frequency", {"1400"} },
  { "mmpbx", "single_freq_hightone", "power", {"-11"} },
  { "mmpbx", "single_freq_hightone_mark", "frequency", {"1400"} },
  { "mmpbx", "single_freq_hightone_mark", "power", {"-11"} },
  { "mmpbx", "dual_tone", "frequency", {"765", "850"} },
  { "mmpbx", "dual_tone", "power", {"-11", "-11"} },
  { "mmpbx", "single_freq_425", "frequency", {"425"} },
  { "mmpbx", "single_freq_425", "power", {"-11"} },
  { "mmpbx", "file_confirmation", "filename", "/etc/mmpbx/confirmation.au" },
  { "mmpbx", "file_confirmation", "encoding", "PCMU" },
  { "mmpbx", "dial", "delay", "0" },
  { "mmpbx", "dial", "repeat_after", "-1" },
  { "mmpbx", "dial", "play", {"single_freq_dialtone"} },
  { "mmpbx", "dial", "duration", {"-1"} },
  { "mmpbx", "callhold", "delay", "0" },
  { "mmpbx", "callhold", "repeat_after", "-1" },
  { "mmpbx", "callhold", "play", {"single_freq_hightone", "silence"} },
  { "mmpbx", "callhold", "duration", {"400", "15000"} },
  { "mmpbx", "callhold", "loop_from", {"silence"} },
  { "mmpbx", "callhold", "loop_to", {"single_freq_hightone"} },
  { "mmpbx", "callhold", "loop_iterations", {"-1"} },
  { "mmpbx", "callwaiting", "delay", "0" },
  { "mmpbx", "callwaiting", "repeat_after", "-1" },
  { "mmpbx", "callwaiting", "play", {"single_freq_425", "silence", "single_freq_425", "silence-m" } },
  { "mmpbx", "callwaiting", "duration", {"200", "200", "200", "9000"} },
  { "mmpbx", "callwaiting", "loop_from", {"silence-m"} },
  { "mmpbx", "callwaiting", "loop_to", {"single_freq_425"} } ,
  { "mmpbx", "callwaiting", "loop_iterations", {"-1"} },
  { "mmpbx", "rejection", "delay", "0" },
  { "mmpbx", "rejection", "repeat_after", "-1" },
  { "mmpbx", "rejection", "play", {"dual_tone", "silence"} },
  { "mmpbx", "rejection", "duration", {"400", "400"} },
  { "mmpbx", "rejection", "loop_from", {"silence"} },
  { "mmpbx", "rejection", "loop_to", {"dual_tone"} },
  { "mmpbx", "rejection", "loop_iterations", {"-1"} },
  { "mmpbx", "confirmation", "delay", "0" },
  { "mmpbx", "confirmation", "repeat_after", "-1" },
  { "mmpbx", "confirmation", "play", {"file_confirmation"} },
  { "mmpbx", "confirmation", "duration", {"-1"} },
  { "mmpbx", "congestion", "delay", "0" },
  { "mmpbx", "congestion", "repeat_after", "-1" },
  { "mmpbx", "congestion", "play", {"single_freq_425", "silence"} },
  { "mmpbx", "congestion", "duration", {"250", "250"} },
  { "mmpbx", "congestion", "loop_from", {"silence"} },
  { "mmpbx", "congestion", "loop_to", {"single_freq_425"} },
  { "mmpbx", "congestion", "loop_iterations", {"-1"} },
  { "mmpbx", "busy", "delay", "0" },
  { "mmpbx", "busy", "repeat_after", "-1" },
  { "mmpbx", "busy", "play", {"single_freq_dialtone", "silence"} },
  { "mmpbx", "busy", "duration", {"500", "500"} },
  { "mmpbx", "busy", "loop_from", {"silence"} },
  { "mmpbx", "busy", "loop_to", {"single_freq_dialtone"} },
  { "mmpbx", "busy", "loop_iterations", {"-1"} },
  { "mmpbx", "ringback", "delay", "500" },
  { "mmpbx", "ringback", "repeat_after", "-1" },
  { "mmpbx", "ringback", "play", {"single_freq_dialtone", "silence"} },
  { "mmpbx", "ringback", "duration", {"1000", "4000"} },
  { "mmpbx", "ringback", "loop_from", {"silence"} },
  { "mmpbx", "ringback", "loop_to", {"single_freq_dialtone"} },
  { "mmpbx", "ringback", "loop_iterations", {"-1"} },
  { "mmpbx", "mwi", "delay", "0" },
  { "mmpbx", "mwi", "repeat_after", "-1" },
  { "mmpbx", "mwi", "play", {"single_freq_dialtone", "silence", "single_freq_dialtone-mw", "single_freq_dialtone"} },
  { "mmpbx", "mwi", "duration", {"1200", "40", "40", "-1"} },
  { "mmpbx", "mwi", "loop_from", {"single_freq_dialtone-mw"} },
  { "mmpbx", "mwi", "loop_to", {"silence"} },
  { "mmpbx", "mwi", "loop_iterations", {"4"} },
  { "mmpbx", "specialdial", "delay", "0" },
  { "mmpbx", "specialdial", "repeat_after", "-1" },
  { "mmpbx", "specialdial", "play", {"single_freq_dialtone", "silence"} },
  { "mmpbx", "specialdial", "duration", {"400", "40"} },
  { "mmpbx", "specialdial", "loop_from", {"silence"} },
  { "mmpbx", "specialdial", "loop_to", {"single_freq_dialtone"} },
  { "mmpbx", "specialdial", "loop_iterations", {"-1"} },
  { "mmpbx", "stutterdial", "delay", "0" },
  { "mmpbx", "stutterdial", "repeat_after", "-1" },
  { "mmpbx", "stutterdial", "play", {"single_freq_dialtone", "silence"} },
  { "mmpbx", "stutterdial", "duration", {"500", "50"} },
  { "mmpbx", "stutterdial", "loop_from", {"silence"} },
  { "mmpbx", "stutterdial", "loop_to", {"single_freq_dialtone"} },
  { "mmpbx", "stutterdial", "loop_iterations", {"-1"} },
  { "mmpbx", "release", "delay", "0" },
  { "mmpbx", "release", "repeat_after", "-1" },
  { "mmpbx", "release", "play", {"single_freq_425", "silence"} },
  { "mmpbx", "release", "duration", {"250", "250"} },
  { "mmpbx", "release", "loop_from", {"silence"} },
  { "mmpbx", "release", "loop_to", {"single_freq_425"} },
  { "mmpbx", "release", "loop_iterations", {"-1"} },
  { "mmpbx", "areacode_translation_1", "areacode", "+370" },
  { "mmpbx", "areacode_translation_1", "prefix", "8" },
  { "mmpbx", "areacode_translation_1", "remove_header_length", "4" },
  { "mmpbxbrcmcountry", "global", "country", "etsi" },
  { "mmpbxbrcmcountry", "global_provision", "min_disconnect_time", "750" },
  { "mmpbxbrcmcountry", "global_provision", "min_hookflash_time", "90" },
  { "mmpbxbrcmcountry", "global_provision", "max_hookflash_time", "710" },
  { "mmpbxbrcmcountry", "global_provision", "plsdl_minbreak_time", "20" },
  { "mmpbxbrcmcountry", "global_provision", "plsdl_maxbreak_time", "85" },
  { "mmpbxbrcmcountry", "global_provision", "plsdl_minMake_time", "20" },
  { "mmpbxbrcmcountry", "global_provision", "plsdl_maxMake_time", "85" },
  { "mmpbxbrcmcountry", "global_provision", "plsdl_interdigit_time", "260" },
  { "mmpbxbrcmcountry", "global_provision", "cid_mode", "2" },
  { "mmpbxbrcmcountry", "global_provision", "cid_sigprotocol", "1" },
  { "mmpbxbrcmcountry", "global_provision", "cid_fskafterring", "750" },
  { "mmpbxbrcmcountry", "global_provision", "cid_fskafterdtas", "250" },
  { "mmpbxbrcmcountry", "global_provision", "cid_fskafterrpas", "100" },
  { "mmpbxbrcmcountry", "global_provision", "cid_ringafterfsk", "100" },
  { "mmpbxbrcmcountry", "global_provision", "cid_dtasafterlr", "100" },
  { "mmpbxbrcmcountry", "global_provision", "cid1_dtas_tone_id", "0" },
  { "mmpbxbrcmcountry", "global_provision", "vmwi_dtas_tone_id", "0" },
  { "mmpbxbrcmcountry", "global_provision", "cid2_dtas_tone_id", "1" },
  { "mmpbxbrcmcountry", "global_provision", "cid1_dtas_level", "21" },
  { "mmpbxbrcmcountry", "global_provision", "cid2_dtas_level", "21" },
  { "mmpbxbrcmcountry", "global_provision", "vmwi_mode", "7" },
  { "mmpbxbrcmcountry", "global_provision", "vmwi_sigprotocol", "3" },
  { "mmpbxbrcmcountry", "global_provision", "vmwi_fskafterdtas", "100" },
  { "mmpbxbrcmcountry", "global_provision", "vmwi_fskafterrpas", "100" },
  { "mmpbxbrcmcountry", "global_provision", "vmwi_dtasafterlr", "100" },
  { "mmpbxbrcmcountry", "global_provision", "pte_mindetectpower", "40" },
  { "mmpbxbrcmcountry", "global_provision", "dtmf_dbLevel", "4" },
  { "mmpbxbrcmcountry", "global_provision", "highvring_support", "1" },
  { "mmpbxbrcmcountry", "global_provision", "powerring_frequency", "20" },
  { "mmpbxbrcmcountry", "ring_map", "general_ring", {"long", "006400ff", "fff00000"} },
  { "mmpbxbrcmcountry", "ring_map", "splash_ring", {"short", "9", "1f8"} },
  { "mmpbxbrcmcountry", "mmbrcmtonecomponents_dial", "freq1_level", "-9" },
  { "mmpbxrvsipnet", "sip_net", "local_port", "5065" },
  { "mmpbxrvsipnet", "sip_net", "primary_proxy", "10.0.95.68" },
  { "mmpbxrvsipnet", "sip_net", "primary_registrar", "teo.lt" },
  { "mmpbxrvsipnet", "sip_net", "reg_back_off_timeout", "180" },
  { "mmpbxrvsipnet", "sip_net", "401_407_waiting_time", "0" },
  { "mmpbxrvsipnet", "sip_net", "no_answer_response", "480" },
  { "mmpbxrvsipnet", "sip_net", "session_timer", "enabled" },
  { "mmpbxrvsipnet", "sip_net", "min_session_expires", "200" },
  { "mmpbxrvsipnet", "sip_net", "session_expires", "3600" },
  { "mmpbxrvsipnet", "sip_net", "escape_star", "1" },
  { "mmpbxrvsipnet", "sip_net", "control_qos_value", "ef" },
  { "mmpbxrvsipnet", "sip_net", "waiting_time_for_registration_on_400_or_503_response", "60" },
  { "mmpbxrvsipnet", "sip_net", "switch_next_proxy_on_failure_response", "0" },
  { "mmpbxrvsipnet", "sip_net", "cancel_invite_timer", "32000" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "user_friendly_name", "FXS device 1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "comfort_noise", "silence" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "echo_cancellation", "1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "fax_transport", "inband_renegotiation" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "rtcp_interval", "5000" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "t38_redundancy", "1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "relay_state", "0" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "cw_cas_delay", "758" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "fxs_privacy_reason", "P" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "fxs_unavailability_reason", "O" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "fxs_port", "1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "cid_display_date_enabled", "1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "cid_display_calling_line_enabled", "1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "cid_display_calling_party_name_enabled", "1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "pos", "0" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "early_detect_faxmodem", "0" },
  { "mmpbxbrcmfxsdev", "fxs_dev_1", "codec_black_list", {"telephone-event"} },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "user_friendly_name", "FXS device 0" },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "comfort_noise", "silence" },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "t38_redundancy", "1" },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "rtcp_interval", "5000" },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "relay_state", "0" },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "cw_cas_delay", "758" },
  { "mmpbxbrcmfxsdev", "fxs_dev_0", "codec_black_list", {"telephone-event"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hook_flash_timeout", "2000" },
  { "mmpbxbrcmfxsdev", "keypad_generic", "delayed_disconnect", "0" },
  { "mmpbxbrcmfxsdev", "keypad_generic", "delayed_disconnect_timeout", "60" },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hold_and_enable_call_setup", {"HF2"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hold_and_enable_call_setup", {"HFTimeout"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hold_first_from_conference", {"HF5"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hold_last_from_conference", {"HF7"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hold_conference", {"HF2"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "resume_first_held", {"HF*"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "drop_dialing_and_resume_last_held", {"HF1"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "drop_first_from_conference", {"HF6"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "drop_last_from_conference", {"HF8"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "drop_and_enable_call_setup", {"HF9"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "ccbs", {"HF5", "5"} },
  { "mmpbxbrcmfxsdev", "keypad_generic", "hook_flash_dial_tone", "0" },
}

function M.region_set(region, transactions, commitapply)
  local region_data
  if region == "LT" then
    set_on_uci({config = "mmpbx", sectionname = "single_freq_dialtone"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "single_freq_hightone"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "single_freq_hightone_mark"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "dual_tone"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "single_freq_425"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "file_confirmation"}, "file", commitapply)
    region_data = region_lt
  else
    set_on_uci({config = "mmpbx", sectionname = "single_freq_425_5"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "single_freq_425_10"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "single_freq_425_16"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "single_freq_1400_16"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "single_freq_1400_20"}, "tone", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "scc_barge_in_activate"}, "scc_entry", commitapply)
    set_on_uci({config = "mmpbx", sectionname = "scc_barge_in_deactivate"}, "scc_entry", commitapply)
    if region == "SE" then
      set_on_uci({config = "mmpbx", sectionname = "dual_freq_765_20_850_20"}, "tone", commitapply)
      lfs.link("/usr/share/announcement_files/message.au", "/etc/mmpbx/message.au", true)
      region_data = region_se
    elseif region == "DK" then
      set_on_uci({config = "mmpbx", sectionname = "single_freq_765_10"}, "tone", commitapply)
      region_data = region_dk
    end
  end
  for _,v in ipairs(region_data) do
    binding.config = v[1]
    binding.sectionname = v[2]
    binding.option = v[3]
    set_on_uci(binding, v[4], commitapply)
    transactions[binding.config] = true
  end
  return true
end

return M
