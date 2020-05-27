-- Copyright (c) 2020 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.


-- This table contains the list of datamodel paths, used for MQTT API's set, add or delete request and response interactions.
-- Values from this table are used in the reqResponse_handler.lua for cheking the white-listed Datamodel Values.

local M = {}

M.transformerWhiteList = {
  "rpc.network.firewall.portforward.",
  "InternetGatewayDevice.LANDevice.",
  "rpc.wireless.ssid.",
  "uci.wireless.wifi-iface.",
  "rpc.wireless.radio.",
  "rpc.wireless.ap.",
  "uci.wireless.wifi-bandsteer.@bs0.state",
  "uci.wireless.wifi-bandsteer.@bs0.rssi_threshold",
  "uci.wireless.wifi-bandsteer.@bs0.rssi_5g_threshold",
  "rpc.wireless.wps_button",
  "rpc.mmpbx.calllog.clear",
  "sys.hosts.host.",
  "uci.dhcp.host.",
  "uci.parental.URLfilter.",
  "uci.tod.host.",
  "rpc.network.firewall.mode",
  "uci.parental.general.enable",
  "InternetGatewayDevice.User.",
  "uci.tod.ap.",
  "uci.tod.wifitod.",
  "uci.tod.action.",
  "uci.tod.timer."
}

M.executeWhiteList = {
  "uci delete tod.",
  "uci add_list tod.",
  "uci commit",
  "/etc/init.d/firewall reload",
  "/etc/init.d/tod reload",
  "reboot",
  "echo -n > /etc/cwmpd.db; /etc/init.d/cwmpd restart"
}

return M
