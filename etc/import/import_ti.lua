
-- restore the web admin user
config "web" {
  section "usr_admin" {
    convert = function(s)
      keepOptions("srp_salt", "srp_verifier")
    end
  }
}

config "firewall" {
  --firewall level
  section "fwconfig" {
    convert = function(s)
      keepOptions("level", "dmz")
    end
  },
  sectiontype "userrule" {
    clear_list = true,
  },
  sectiontype "userrule_v6" {
    clear_list = true,
  },
  -- DMZ
  section "dmzredirect" {
    convert = function(s)
      keepOptions("dest_mac", "dest_ip")
    end,
  },
  -- WAN NAT
  section "wan" {
    convert = function(s)
      keepOptions("masq")
    end,
  },
  -- port mappings
  sectiontype "userredirect" {
    clear_list = true,
  },
  sectiontype "dmzredirect" {
    clear_list = true,
  },
}

-- restore LAN IP
config "network" {
  section "lan" {
    convert = function(s)
      keepOptions("ipaddr", "netmask")
    end,
  }
}

--restore DHCP config
config "dhcp" {
  section "lan" {
    -- for lan, restore everything
    clear_existing = true,
  },
  --for others only keep enable
  section "wlnet_b_24" {
    convert = function(s)
      keepOptions("dhcpv4")
    end,
  },
  section "wlnet_b_5" {
    convert = function(s)
      keepOptions("dhcpv4")
    end,
  },
  --restore static address assignments
  sectiontype "host" {
    clear_list = true,
  },
}

config "upnpd" {
  section "config" {
    convert = function(s)
      keepOptions("enable_upnp")
    end,
  }
}

config "dlnad" {
  section "config" {
    convert = function(s)
      keepOptions("enabled")
    end,
  }
}

config "wireless" {
  sectiontype "wifi-iface" {
    convert = function(s)
      keepOptions("ssid")
    end,
  },
  sectiontype "wifi-ap" {
    convert = function(s)
      keepOptions(
        "public",
        "wpa_psk_key", "wep_key", "security_mode",
        "acl_mode", "acl_accept_list", "acl_deny_list"
      )
    end,
  },
}

config "mmpbx" {
  sectiontype "incoming_map" {
    convert = function(s)
      if s.profile == "sip_profile_0" then
        keepOptions("device")
      else
        skip()
      end
    end
  },
}

config "mmpbxbrcmfxsdev" {
  section "fxs_dev_0" {
    convert = function(s)
      keepOptions("pos")
    end,
  },
  section "fxs_dev_1" {
    convert = function(s)
      keepOptions("pos")
    end,
  },
}

