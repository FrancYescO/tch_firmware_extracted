-- Copyright (c) 2020 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.


-- This table contains the list of datamodel paths with parameters used in MQTT API's set request.
-- The datamodel parameters are mapped with corresponding validators.

local paramWithValidator = {
  ["uci.wireless.wifi-bandsteer.@bs0.state"] = "isBoolean",
  ["uci.wireless.wifi-bandsteer.@bs0.rssi_threshold"] = "validateRssiThreshold",
  ["uci.wireless.wifi-bandsteer.@bs0.rssi_5g_threshold"] = "validateRssiThreshold",
  ["rpc.wireless.wps_button"] = true,
  ["rpc.mmpbx.calllog.clear"] = "isBoolean",
  ["rpc.network.firewall.mode"] = "validateFirewallMode",
  ["uci.parental.general.enable"] = "isBoolean",
  ["uci.tod.host."] = {
    enabled = "isBoolean",
    type = "validateTodType",
    id = "isValidMac",
    mode = "validateTodMode",
    rule_name = "isString",
    start_time = "validateTime",
    stop_time = "validateTime",
    value = "validateWeekday"
  },
  ["uci.parental.URLfilter."] = {
    mac = "isValidMac",
    site = "isValidURL",
    action = "validateURLfilterAction",
    device = "validateURLfilterDevice"
  },
}

return paramWithValidator
