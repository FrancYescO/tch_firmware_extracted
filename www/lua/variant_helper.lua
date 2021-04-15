local intl = require("web.intl")
local function log_gettext_error(msg)
    ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
gettext.textdomain('webui-core')

-- Returns a table that contains Section Name, Page Name and its Options
return {
  Telephony = {
    Service = {
      showAdvanced = {
        description = "Display the advanced mode",
        value = false,
        role = {}
      },
      serviceTimeout = {
        description = "Display the Input text box to enter the service timeout value",
        value = true,
        role = {
          engineer = true
        }
      }
    },
    Card = {
      addMmpbxStateSwitchToCardHeader = {
        description = "Telephony feature enable/disable in card header",
        value = false,
        role = {}
      }
    },
    InOutMapping = {
      inOutMapFilter = {
        description = "Display the In/Out mapping only if the profile is enabled",
        value = true
      }
    },
    PhoneNumber = {
      showAdvanced = {
        description = "Display the advanced mode",
        value = true,
        role = {
          engineer = true,
	  ispuser = true
        }
      },
      DigitMap = {
        description = "Display the Digit Map ",
        value = false,
     }
    },
    Global = {
      TelephonyGlobalAccess = {
        description = "Display Telephony Enable and SIP Network table only to the superUser",
        value = true
      },
      NoAnswerTimeout = {
        description = "Display the no answer timeout option for engineer view",
        value = false
      },
      sipNetwork= {
        description = "Display the sip Network options only for the engineer view",
        value = false
      },
      showAdvanced = {
        description = "Display the advanced mode",
        value = false,
        role = {}
      },
      CodecAndQoSTag = {
        description = "Display the Codec and QoS Options",
        value = false
      },
      mmpbxGlobal = {
        description = "Display Telephony global card",
        value = true
      }
    }
  },
  LoginPage = {
    login = {
      loginInternetStatus = {
        description = "To display the wan status",
        value = true
      },
      loginStyleCSS = {
        description = "Displaying the style and logo specific",
        value = true
      },
      forgotPassword = {
        description = "To support the Forgot password feature",
        value = false
      },
      lastAccess = {
        description = "To check the last access user details.",
        value = true
      },
      standardUserDetails = {
        description = "Displaying the standardUser Details.",
        value = false
      },
      firmwareVersion = {
        description = "Displaying the firmwareVersion Details.",
        value = false
      },
      logo = {
        description = "To display the logo",
        value = false
      },
      loginFailureAttempt = {
        description = "To display the login failure Attempts.",
        value = true
      }
    }
  },
  GatewayPage = {
    gateway = {
      loginStyleCSS = {
        description = "To use customer specific CSS files",
        value = true
      },
      changePassword = {
        description = "To support the change password feature",
        value = true
      },
      passwordReminder = {
        description = "To use board specific password reminder pop up",
        value = true
      },
      nspLogo = {
        description = "To display nsplogo",
        value = false
      },
      logo = {
        description = "To differenciate the style of logo",
        value = false
      },
      profileSettings = {
        description = "Profile Settings iso change my password",
        value = true
      },
      accessKey = {
        description = "Change Access Key iso change password",
        value = false
      },
      wizard = {
        description = "To set up basic configuration",
        value = false
      },
      hideAssitanceCard = {
        description = "To not show assistance card",
        value = false
      },
      showSignInButton = {
        description = "To display the Sign In button for Login",
        value = true
      },
      textAlignment = {
        description = "To align text properly when zoomed for Telia",
        value = false
      },
      nspLink = {
        description = "To display nsplink",
        value = true
      }
    }
  },
  PasswordPage = {
    password = {
      sessionLogout = {
        description = "When the password is changed, whether the session needs to be logout and redirect to login page or not.",
        value = true
      },
      logoStyleCss = {
        description = "To use customer specific CSS files",
        value = true
      },
      logo = {
        description = "To display the logo",
        value = false
      },
      passwordStrength = {
        description = "To support the password field strength",
        value = true
      },
      passwordFieldName = {
        description = "To differentiate the name for password field",
        value = true
      },
      DefaultAdminPassword = {
        description = "To set default admin password",
        value = false
      }
    }
  },
  WANServices = {
    PortMapping = {
      DMZ = {
        description = "To display DMZ option in portmapping and hide in settings tab",
        value = true
      },
      IPv6Port = {
        description = "To block destination port for Telia",
        value = false
      }
    },
    DynDNS = {
      dynDNSNote = {
        description = "To display the wordings based on customer",
        value = false
      }
    }
  },
  InternetAccess = {
    internetAccess = {
      atm_wan = {
        description = "To differenciate the atmdevice types",
        value = false
      },
      atmwan = {
        description = "To differenciate the atmdevice types",
        value = true
      }
    },
    settings = {
      mode = {
        description = "To display the connection mode",
        value = false
      }
    },
    IPv6PPPUsername = {
	Username = {
          description = "To alter wan username based on IPv6 switching for TI",
          value = true
	}
    },
    IPv4PPPCred = {
      Userpass = {
        description = "To alter wan username and password based on IPv4 switching for TI",
        value = true,
        role = {
          engineer = true,
          ispuser = true
        }
      }
    }
  },
  LocalNetwork = {
    lan = {
      ipextras = {
        description = "To display the ipextras tab",
        value = true,
        role = {
          engineer = true
        }
      },
      bridgedReset = {
        description = "To show the bridged mode reset message with reset button",
        value = true
      },
      ipv6Prefix = {
        description = "To display ipv6 prefix value",
        value = false
      }
    }
  },
  Wireless = {
    wireless = {
      qtnMacCheck = {
        description = "To support the QTN Mac address",
        value = false
      },
      todConfigFlush = {
        description = "Section to flush the tod config",
        value = false
      },
      platformfield = {
        description = "To support the wireless radio type value",
        value = true
      },
      wpsValue = {
        description = "Path will differ from other custo",
        value = false
      },
      securityPopupShow = {
        description = "To display the popup for none mode in security",
        value = false
      },
      navlistCheck = {
        description = "Do not display the navlist on the list if no SSID",
        value = false
      },
      shortGuardInterval = {
        description = "To check w",
        value = false
      },
      channelList = {
        description = "To support the channel list values",
        value = true
      },
      graphGeneration = {
        description = "To display the graph generation.",
        value = true
      },
      helperFunction = {
        description = "For Tim, the tim_helper file needs to be called.",
        value = true
      },
      quantenna = {
        description = "To check the quantenna using isIntRemman.",
        value = true
      },
      delaySaveOperation = {
        description = "rpc.wireless.radio. returns empty during hostapd restart is in progress, so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute) to break this loop.",
        value = true
      },
      validateLXCCheck = {
        description = "To validate the post helper function validateLXC.",
        value = false
      },
      bandsteerSupport = {
        description = "To differentiate the bandsteer functionality.",
        value = false
      },
      bandsteerDisabledAlert = {
        description = "To display alert message when bandsteer is disabled",
        value = false
      },
      passwordStrength = {
        description = "To enable strength indication for WiFi password.",
        value = true
      },
      guestCheck = {
        description = "For TI, there is some additionally added values check and also check the guest for some html part.",
        value = true
      },
      frameBursting = {
        description = "For TI, the frame bursting, rssi_threshold and rssi_5g_threshold is not applicable and validateRadioandAp is only for TI",
        value = false
      },
      radiolabelState = {
        description = "For TI, additional label is present.",
        value = true
      },
      qrCodeFeature = {
        description = "To support the QR code featute",
        value = false
      },
      hiddenSupport = {
        description = "To support the hidden type html part values",
        value = true
      },
      wifiAnalyzer = {
        description = "To display the wifiAnalyser",
        value = true
      },
      navTab = {
        description = "Nav tab display",
        value = true
      },
      WPSWarning = {
        description = "WPS Warning for guest",
        value = false
      },
      ACLWarning = {
        description = "ACL List Warning",
        value = true
      },
      ssidCheck = {
        description = "To check whether same ssid used for all interfaces",
        value = false
      },
      bandSteerSSID = {
        description = "To differenciate the SSID value when bandSteer is disabled",
        value = true
      },
      multiAP = {
        description = "To check weather multiAP exist or not",
        value = true
      },
      securityMode = {
        description = "To display the None option in security mode",
        value = true
      },
      showWPSPin = {
        description = "To display WPS AP pin code and WPS Device PIN code",
        value = true
      },
      showSSIDTelusBooster = {
        description = "To display ssid's other than Low backhaul, IPTV and  Smarthome for Telus booster",
        value = false
      },
      getBandsteerParams = {
        description = "To get bandsteer params",
        value = true
      },
      hideGuestSSID = {
        description = "For Telia, not to display guest SSID for Telia EE home and support user",
        value = false
      },
      channelWithNo160MHz = {
        description = "Disabling 160MHz Channel bandwidth for WiFi",
        value = true 
      },
      radio5gHighNo160MHz = {
        description = "For Telus, remove 160MHZ support for radio5g high",
        value = false
      },
      hideWEPKey = {
        description = "To hide WEP key field in GUI",
        value = false
      },
      showsplitToggle = {
        description = "To show the split/merge toggle button",
        value = true
      },
      multiapBroadCastACL = {
        description = "To show the BroadCast SSID and ACL when multiAP is enabled",
        value = false
      },
      guestMultiap = {
        description = "To configure the wireless for Guest when multiap is enabled",
        value = false
      },
      showWPSForGuest = {
        descriptiom = "To show WPS button for guest",
        value = false
      },
      showAdditionalStandards = {
        description = "To show additional standards based on sta_minimum_mode configuration",
        value = false
      },
      showOwnSSID = {
        description = "To show the own ssid details in analyzer page",
        value = true
      },
      wpsStateSet = {
        description = "To not set wps admin_state when triggering WPS",
        value = false
      },
      guestBandsteer = {
        description = "To get the guest bandsteer params",
        value = false
      },
      stationTab = {
        description = "To display the station tab",
        value = false
      },
      agentView = {
        description = "When agent alone enabled, broadcast ssid and ACL should not be displayed",
        value = false
      }
    },
    clientMonitor = {
      PacketsInfoAndCurrentTime = {
        description = "To display sent/Receive/retransmission packet details and current time value",
        value = true
      },
      ssidNetwork = {
        description = "To fetche ssid values other than wifi1x",
        value = true
      },
      hostname = {
        description = "To fetch hostname based on friendly name",
        value = true
      },
      hotspot = {
        description = "To fetch the devices which not connected with hotspot",
        value = true
      },
    },
    tod = {
      todPath = {
        description = "To differencitae the path used for tod",
        value = false
      },
      ssidBasedTod = {
        description = "To support ssid based tod",
        value = false
      },
      onAdd = {
        description = "To differenciate add tod rules",
        value = false
      },
      onDelete = {
        description = "To differenciate delete tod rules",
        value = false
      },
      todTime = {
	description = "To differentiate tod time for a single day.",
	value = true
      }
    },
    card = {
      wificardValue = {
        description = "The id name of the wifi ssid will differ for custo's.",
        value = true
      },
      wirelessSSID = {
        description = "To support the wireless ssid helper function.",
        value = true
      },
      sortSSid = {
        description = "The SSID order shown in wireless card will differ for TI",
        value = false
      }
    },
    tabs = {
      wifiNurse = {
        description = "To display Wi-Fi Nurse tab",
        value = true
      }
    }
  },
   Broadband = {
    card = {
      roleCheckName = {
        description = "To display the switch in card.",
        value = false,
        role = {
          engineer = true
        }
      },
       displaySwitch = {
        description = "To differentiate the details in card.",
        value = false
      },
      bridgedMode = {
        description = "To display the state of bridged mode",
        value = false
      },
      hideBridgeInterface = {
        description = "To hide the interaces in bridged mode",
        value = false
      }
    }
  },
  DevicesModal = {
    devicesList = {
      ssidNetwork = {
        description = "To display network name for wireless devices",
        value = false
      }
    },
    globalInfo = {
      fontColour = {
        description = "To differenciate font colour based on custo",
        value = "#004691"
      }
    }
  },
  PasswordResetPage = {
    passwordReset = {
      logo = {
        description = "To display the logo based on customer.",
        value = false
      },
      DefaultAdminPassword = {
        description = "To set default admin password",
        value = false
      }
    }
  },
  Intercept = {
    intercept = {
      logo = {
        description = "To display the logo based on customer.",
        value = false
      }
    }
  },
  Management = {
    userManagertab = {
      roleListValue = {
        description = "Differentiate usermanagement role list",
        value  = false
      },
      defaultRoleList = {
        description = "Differentiate usermanagement default user role",
        value = false
      }
    }
  },
  SystemInfo = {
    TimeManagement = {
      timeZone = {
        description = "Allow to edit CurrentTimeZone and NetworkTimeZone",
        value = true,
        role = {
          engineer = true
        }
      },
      ntpServer = {
        description = "Allow to edit NTP Server",
        value = true
      }
    },
    card = {
      activeBankInfo = {
        description = "The version refers to friendly_sw_version_activebank for TI",
        value = true
      },
      releaseVersion = {
        description = "To display full version string",
        value = false
      },
      version = {
        description = "To display the version string wrt activeBankInfo's value",
        value = T'<strong>Release %s</strong>'
      },
      serialNumber = {
        description = "To display the serial number in the system info card",
        value = false
      },
      upTime = {
        description = "To display the uptime of DUT",
        value = false
      },
      lastACSInform = {
        description = "To display the last ACS inform to the DUT",
        value = false
      },
      readOnlySystemInfo = {
        description = "To have the system info card readOnly in Remote PC",
        value = false
      }
    },
    configuration = {
      hideConfiguration = {
        description = "To hide configuration section inside configuration tab",
        value = false
      }
    }
  },
  InternetCard = {
    card = {
      readOnlyInternetCard = {
        description = "To have the Internet card readOnly in Remote PC",
        value = false
      },
      IPv6Address = {
        description = "To display the IPv6 Address",
        value = false
      },
      netMask = {
        description = "To display the netmask",
        value = false
      }
    }
  },
  WirelessCard = {
    card = {
      readOnlyWirelessCard = {
        description = "To have the Wireless card readOnly in Remote PC",
        value = false
      },
      hideBHSSIDOffState = {
        description = "To hide the Backhaul SSID on the wireless card if SSID is disabled",
        value = false
      }
    }
  },
  LocalNetworkCard = {
    card = {
      readOnlyLocalNetworkCard = {
        description = "To have the Local Network card readOnly in Remote PC",
        value = false
      }
    }
  },
  DevicesCard = {
    card = {
      readOnlyDevicesCard = {
        description = "To have the Devices card readOnly in Remote PC",
        value = false
      }
    }
  },
  CwmpdPage = {
    cwmpdtab = {
      xmppconfig = {
        description = "To display the XMPP Config values",
        value = false
      }
    }
  },
  ExtenderPage = {
    extenderConfig = {
      extenderInfo = {
        description = "To display the Exterder Agent Info",
        value = true
      },
      isExtender = {
        description = "To display only agent information",
        value = false
      },
      controlSelectionEnabled = {
        description = "To display control select dropdown",
        value = false
      },
      backhaulConfig = {
        description = "To display Backhaul Configuration details",
        value = true
      },
      ShowWiFiDevicesWithoutHostManager = {
        description = "To display the wifi devices information when device details are not present in hostmanager",
        value = false
      },
      ShowTopologyWithoutHostManager = {
        description = "To display the Topology modal in Easymesh card when device details are not present in hostmanager",
        value = false
      },
      showEMConfigPage = {
        description = "To display the EasyMesh configuration page, if available",
        value = true
      },
      agentAndStationInfo = {
        description = "To display the Agent Info Tab on Extender Card",
        value = false
      },
      wifiDevicesList = {
        description = "To display the Wifi Devices Tab on Extender Card",
        value = true
      },
      backhaulDetails = {
        description = "To display the backhaul details in easy mesh configuration page",
        value = false
      },
      easyMeshButton = {
        description = "To display the button from which EasyMesh can be enabled or disabled",
        value = true
      },
      credShow = {
        description = "To display only cred0 fronthaul",
        value = true
      },
      frequencySelection = {
        description = "To display the freqency dropdown will all available interface",
        value = false
      },
      credStatusSwitch = {
        description = "To display the enable/disable cred controller",
        value = false
      },
      haulSwitch = {
        description = "To display the fronthaul and backhaul switching buttons",
        value = false
      },
      controllerAgentMacAddress = {
        description = "To display the controller and agent MAC Address",
        value = false
      },
      easyMeshConfirmPopup = {
        description = "To have the confirmation popup before enabling/disbaling EasyMesh",
        value = true
      },
      fronthaulString = {
        description = "To display the title as Fronthaul configuration or CRED0",
        value = true
      },
      easymeshConfig = {
        description = "To display/hide easymesh configuration page",
        value = true
      },
      showLabel = {
        description = "To display the topology and device page label",
        value = false
      },
      hideWifiDevice = {
        description = "To hide the device info details",
        value = false
      }
    },
    extendertopology = {
      navigationLink = {
        description = "To have the nagivation link click on which redirects to Agent or WiFi Devices page",
        value = true
      },
      extenderName = {
        description = "To display the extender name with serial number",
        value = true
      }
    },
    extenderDeviceList = {
     agentHostname = {
        description = "To display the title as Gateway/Extender iso actual hostnames",
        value = true
      }
    }
  },
  Diagnostics = {
    connectionPage = {
      IPv6Addr = {
        description = "To show the ipv6 address from br-lan",
        value = false
       }
    }
  },
  Firewall = {
    firewall = {
      levelMessage = {
        description = "To display the firewall high level",
        value = true
      }
    }
  },
  Assistance = {
    assistance = {
      remoteAssistance = {
        description = "To display only temporary mode and random password",
        value = false
      }
    }
  },
  ParentalBlockPage = {
    parentalblock = {
      logoTelia = {
        description = "To display the logo in PNG format",
        value = false
      }
    }
  }
}
