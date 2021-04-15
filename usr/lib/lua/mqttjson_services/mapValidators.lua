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

-- Maps the datamodel parameters with their respective validators.
local paramWithValidator = {
  ["rpc.wireless.ssid."] = {
    admin_state = "isBoolean",
  },
  ["uci.wireless.wifi-iface."] = {
    ssid = "validateSSID"
  },
  ["rpc.wireless.radio."] = {
    requested_channel = "validateReqChannel",
    requested_channel_width = "validateReqChannelWidth"
  },
  ["rpc.wireless.ap."] = {
    public = "isBoolean",
    wpa_psk_passphrase = "validateWpaPassphrase",
    mode = "validateSecurityMode",
    admin_state = "isBoolean",
    ap_pin = "validateApPin"
  },
  ["uci.wireless.wifi-bandsteer."] = {
    state = "isBoolean",
    rssi_threshold = "validateRssiThreshold",
    rssi_5g_threshold = "validateRssiThreshold"
  },
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
  ["InternetGatewayDevice.User."] = {
    Password = "validatePassword",
  },
  ["uci.dhcp.host."] = {
    mac = "isValidMac",
    ip = "isValidIP",
    name = "isString"
  },
  ["rpc.network.firewall.portforward."] = {
    name = "isString",
    family = "validatePfwFamily",
    dest_port = "validatePort",
    src_dport = "validatePort",
    dest_ip = "isValidIP",
    value = "validateProtocol",
    dest_mac = "isValidMac",
  },
  ["sys.hosts.host."] = {
    FriendlyName = "isString",
    HostType = "isString"
  },
  ["InternetGatewayDevice.LANDevice."] = {
    IPInterfaceIPAddress = "isValidIP",
    DHCPServerEnable = "isBoolean",
    MinAddress = "isValidIP",
    MaxAddress = "isValidIP",
    SubnetMask = "isValidSubnetMask"
  },
}

return paramWithValidator
