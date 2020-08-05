
return {
            { "uci.web.uiconfig.@uidefault.upgradefw","0", "set"},
            { "uci.cwmpd.cwmpd_config.state","0", "set"},
            { "uci.samba.samba.enabled","0", "set"},
            { "uci.minidlna.config.enabled","0", "set"},
            { "uci.printersharing.config.enabled","0", "set"},
            { "uci.network.interface.@wan.","", "del"},
            { "uci.network.interface.@wan6.","", "del"},
            { "uci.network.interface.@wwan.","", "del"},
            { "uci.network.interface.@guest.","", "del"},
            { "uci.network.interface.@bt_iptv.","", "del"},
            { "uci.network.interface.@lan_public.","", "del"},
            { "uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3 eth5", "set"}, 
            { "uci.dhcp.relay.@relay.","", "del"},
            { "uci.dhcp.dhcp.@wan.","", "del"},
            { "uci.dhcp.dhcp.@bt_iptv.","", "del"},
            { "uci.dhcp.dhcp.@guest_private.","", "del"},
            { "uci.dhcp.dhcp.@lan.ignore","1", "set"},
            { "uci.dhcp.dhcp.@lan.dhcpv4","disabled", "set"},
            { "uci.upnpd.config.enable_upnp","0", "set"},
            { "uci.upnpd.config.enable_natpmp","0", "set"},
            { "uci.wireless.wifi-iface.@wl0_1.","", "del"},
            { "uci.wireless.wifi-iface.@wl1_1.","", "del"},
            { "uci.wireless.wifi-ap.@ap2.","", "del"},
            { "uci.wireless.wifi-ap.@ap3.","", "del"},
            { "uci.wireless.wifi-radius-server.@ap2_auth0.","", "del"},
            { "uci.wireless.wifi-radius-server.@ap2_acct0.","", "del"},
            { "uci.wireless.wifi-radius-server.@ap3_auth0.","", "del"},
            { "uci.wireless.wifi-radius-server.@ap3_acct0.","", "del"},
            { "uci.intercept.config.enabled","0", "set"},
            { "uci.wansensing.global.enable","0", "set"},
            { "uci.mmpbx.mmpbx.@global.enabled","0", "set"},
            { "uci.xdsl.xdsl.@dsl0.enabled","0", "set"},
            { "uci.web.rule.@internetmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@lteajaxmobiletab.roles@1.", "", "del" },
            { "uci.web.rule.@setupmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@iproutesmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@diagnosticsnetworkmodal.roles.@1.", "", "del" }, 
            { "uci.web.rule.@subnetmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@diagnosticsxdslmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@todmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@devicemodal.roles.@1.", "", "del" }, 
            { "uci.web.rule.@broadbandmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@parentalmodal.roles.@1.", "", "del" }, 
            { "uci.web.rule.@diagnosticspingmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@httpi.roles.@1.", "", "del" },
            { "uci.web.rule.@httpi.roles.@1.", "", "del" },
            { "uci.web.rule.@assistancemodal.roles.@1.", "", "del" }, 
            { "uci.web.rule.@resetrebootmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@firewallmodal.roles.@1.", "", "del" }, 
            { "uci.web.rule.@wanservices.roles.@1.", "", "del" }, 
            { "uci.web.rule.@mmpbxprofilemodal.roles.@1.", "", "del" },
            { "uci.web.rule.@mmpbxlogmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@contentsharing.roles.@1.", "", "del" },
            { "uci.web.rule.@mmpbxglobalmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@mmpbxservicemodal.roles.@1.", "", "del" },
            { "uci.web.rule.@mmpbxcontactsmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@httpiredirect.roles.@1.", "", "del" },
            { "uci.web.rule.@hostmapmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@diagnosticsconnectionmodal.roles.@1.", "", "del" },
            { "uci.web.rule.@todwifimodal.roles.@1.", "", "del" },
            { "uci.web.rule.@mmpbxinoutgoingmodal.roles.@1.", "", "del" },
            { "uci.web.card.", "bbcard", "add" },
            { "uci.web.card.@bbcard.hide", "1", "set" },
            { "uci.web.card.@bbcard.card", "broadband.lp", "set" },
            { "uci.web.card.@bbcard.modal", "broadbandmodal", "set" },
            { "uci.web.card.", "intcard", "add" },
            { "uci.web.card.@intcard.hide", "1", "add" },
            { "uci.web.card.@intcard.card", "internet.lp", "set" },
            { "uci.web.card.@intcard.modal", "internetmodal", "set" },
            { "uci.web.card.", "devcard", "add" },
            { "uci.web.card.@devcard.hide", "1", "set" },
            { "uci.web.card.@devcard.card", "Devices.lp", "set" },
            { "uci.web.card.@devcard.modal", "devicemodal", "set" },
            { "uci.web.card.", "wancard", "add" },
            { "uci.web.card.@wancard.hide", "1", "set" },
            { "uci.web.card.@wancard.card", "wanservices.lp", "set" },
            { "uci.web.card.@wancard.modal", "wanservices", "set" },
            { "uci.web.card.", "fwcard", "add" },
            { "uci.web.card.@fwcard.hide", "1", "set" },
            { "uci.web.card.@fwcard.card", "firewall.lp", "set" },
            { "uci.web.card.@fwcard.modal", "firewallmodal", "set" },
            { "uci.web.card.", "telecard", "add" },
            { "uci.web.card.@telecard.hide", "1", "set" },
            { "uci.web.card.@telecard.card", "telephony.lp", "set" },
            { "uci.web.card.@telecard.modal", "mmpbxglobalmodal", "set" },
            { "uci.web.card.", "assistcard", "add" },
            { "uci.web.card.@assistcard.hide", "1", "set" },
            { "uci.web.card.@assistcard.card", "assistance.lp", "set" },
            { "uci.web.card.@assistcard.modal", "assistancemodal", "set" },
            { "uci.web.card.", "cscard", "add" },
            { "uci.web.card.@cscard.hide", "1", "set" },
            { "uci.web.card.@cscard.card", "contentsharing.lp", "set" },
            { "uci.web.card.@cscard.modal", "contentsharing", "set" }, 
            { "rpc.system.reboot", "GUI", "set" },
}