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
        value = true,
        role = {
          engineer = true
        }
      },
      serviceTimeout = {
        description = "Display the Input text box to enter the service timeout value",
        value = true
      }
    },
    Card = {
      addMmpbxStateSwitchToCardHeader = {
        description = "Create Card header",
        value = true
      }
    },
    InOutMapping = {
      inOutMapFilter = {
        description = "Display the In/Out mapping only if the profile is enabled",
        value = false
      }
    },
    PhoneNumber = {
      showAdvanced = {
        description = "Display the advanced mode",
        value = true,
        role = {
          engineer = true
        }
      },
      DigitMap = {
        description = "Display the Digit Map ",
        value = true,
     }
    },
    Global = {
      TelephonyGlobalAccess = {
        description = "Display Telephony Enable and SIP Network table only to the superUser",
        value = true
      },
      NoAnswerTimeout = {
        description = "Display the no answer timeout option for engineer view",
        value = true,
        role = {
          engineer = true
        }
      },
      sipNetwork= {
        description = "Display the sip Network options only for the engineer view",
        value = true,
        role = {
          engineer = true
        }
      },
      showAdvanced = {
        description = "Display the advanced mode",
        value = true,
        role = {
          engineer = true
        }
      },
      CodecAndQoSTag = {
        description = "Display the Codec and QoS Options",
        value = true,
        role = {
          engineer = true
        }
      },
      mmpbxGlobal = {
        description = "Display Telephony global card",
        value = false
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
        value = false
      },
      forgotPassword = {
        description = "To support the Forgot password feature",
        value = true
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
      },
      remoteAssistanceUserName = {
        description = "To auto complete the remote assistance username.",
        value = false
       }
    }
  },
  GatewayPage = {
    gateway = {
      loginStyleCSS = {
        description = "To use customer specific CSS files",
        value = false
      },
      changePassword = {
        description = "To support the change password feature",
        value = true
      },
      passwordReminder = {
        description = "To use board specific password reminder pop up",
        value = false
      },
      nspLogo = {
        description = "To display nsplogo",
        value = false
      },
      nspLogoRedirect = {
        description = "To Redirect the NSPlink to default web page",
        value = false
      },
      logo = {
        description = "To differenciate the style of logo",
        value = true
      },
      profileSettings = {
        description = "Profile Settings iso change my password",
        value = false
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
        value = false
      },
      hideDemoBuildInformation = {
        description = "To hide Demo build information for Custo sessions",
        value = false
      },
      showLanguageSelect = {
        description = "To select language on Gateway page.",
        value = false
      }
    }
  },
  PasswordPage = {
    password = {
      sessionLogout = {
        description = "When the password is changed, whether the session needs to be logout and redirect to login page or not.",
        value = false
      },
      logoStyleCss = {
        description = "To use customer specific CSS files",
        value = false
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
        value = false
      },
      DefaultAdminPassword = {
        description = "To set default admin password",
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
        value = false
      }
    },
    settings = {
      mode = {
        description = "To display the connection mode",
        value = false
      }
    },
    IPv4PPPCred = {
      Userpass = {
        description = "To alter wan username and password based on IPv4 switching for TI",
        value = false,
        role = {}
      }
    }
  },
  LocalNetwork = {
    lan = {
      ipextras = {
        description = "To display the ipextras tab",
        value = false,
        role = {}
      },
      bridgedReset = {
        description = "To show the bridged mode reset message with reset button",
        value = true
      },
      ipv6Prefix = {
        description = "To display ipv6 prefix value",
        value = false
      },
      userIPv6State = {
        description = "To preserve the user IPv6 state as wansensing is enabling the ipv6 state",
        value = false
      },
      resetConfig = {
        description = "To differenciate Reset Configuration Button",
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
        value = true
      },
      platformfield = {
        description = "To support the wireless radio type value",
        value = false
      },
      wpsValue = {
        description = "Path will differ from other custo",
        value = true
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
        description = "To check the shotGuardInterval",
        value = false
      },
      channelList = {
        description = "To support the channel list values",
        value = false
      },
      graphGeneration = {
        description = "To display the graph generation.",
        value = false
      },
      helperFunction = {
        description = "For Tim, the tim_helper file needs to be called.",
        value = false
      },
      quantenna = {
        description = "To check the quantenna using isIntRemman.",
        value = false
      },
      steering = {
        description = "To handle steering in accordance to smartwifi.",
        value = false
      },
      delaySaveOperation = {
        description = "rpc.wireless.radio. returns empty during hostapd restart is in progress, so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute) to break this loop.",
        value = false
      },
      validateLXCCheck = {
        description = "To validate the post helper function validateLXC.",
        value = true
      },
      bandsteerSupport = {
        description = "To differentiate the bandsteer functionality.",
        value = true
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
        value = false
      },
      frameBursting = {
        description = "For TI, the frame bursting, rssi_threshold and rssi_5g_threshold is not applicable and validateRadioandAp is only for TI",
        value = true
      },
      radiolabelState = {
        description = "For TI, additional label is present.",
        value = false
      },
      aplabelState = {
        description = "For TI, additional label is present.",
        value = false
      },
      qrCodeFeature = {
        description = "To support the QR code featute",
        value = true
      },
      hiddenSupport = {
        description = "To support the hidden type html part values",
        value = false
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
      BandSteerElement = {
        description = "To display or hide the Bandsteer elements in newUI",
        value = false,
        role = {}
      },
      ACLList = {
        description = "To display or hide the ACL List",
        value = true,
        role = {
          admin = true
        }
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
        value = false
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
      channelWithNo160MHz = {
        description = "Disabling 160MHz Channel bandwidth for WiFi",
        value = false
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
      showAdditionalStandards = {
        description = "To show additional standards based on sta_minimum_mode configuration",
        value = false
      },
      showOwnSSID = {
        description = "To show the own ssid details in analyzer page",
        value = false
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
        value = true
      },
      agentView = {
        description = "When agent alone enabled, broadcast ssid and ACL should not be displayed",
        value = true
      },
      showGuestWPS = {
        description = "To show the WPS guest page",
        value = true
      },
      showWirelessPassword = {
        description = "To show/hide the wireless password checkbox",
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
        value = true
      },
      ssidBasedTod = {
        description = "To support ssid based tod",
        value = true
      },
      onAdd = {
        description = "To differenciate add tod rules",
        value = true
      },
      onDelete = {
        description = "To differenciate delete tod rules",
        value = true
      },
      todTime = {
        description = "To differentiate tod time for a single day.",
        value = false
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
        value = true
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
        value = true
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
    }
  },
  WANServices = {
    PortMapping = {
      DMZ = {
        description = "To display DMZ option in portmapping and hide in settings tab",
        value = false
      }
    }
  },
  PasswordResetPage = {
    passwordReset = {
      logo = {
        description = "To display the logo based on customer.",
        value = true
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
        value = true
      },
    wanDownMessage = {
        description = "To display intercept message due to abnormal status of wan.",
        value = false
      },
    titleText = {
        description = "To display title with Translation tag when the page is intercepted for unknown reason",
        value = true
      }
    }
  },
  Management = {
    userManagertab = {
      roleListValue = {
        description = "Differentiate usermanagement role list",
        value  = true
      },
      defaultRoleList = {
        description = "Differentiate usermanagement default user role",
        value = false
      }
    },
    systemExtratab = {
      showWANSSH = {
        description = "To show WAN SSH enable button",
        value = false
      },
      lanSSHInterface = {
        description = "LAN SSH interface is empty",
        value = true
      }
    }
  },
  SystemInfo = {
    TimeManagement = {
      timeZone = {
        description = "Allow to edit CurrentTimeZone and NetworkTimeZone",
        value = true
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
      },
      fullBridge = {
        description = "To display bridgemode options for gfr",
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
      },
      showLowbandHighband = {
        description = "To show Low band/High band indication for 5Hz radio in GUI ",
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
        value = true
      }
    }
  },
  ExtenderPage = {
    extenderConfig = {
      readOnlyEasymeshCard = {
        description = "To have the Easymesh card readOnly in Remote PC",
        value = false
      },
      extenderInfo = {
        description = "To display the Exterder Agent Info",
        value = true
      },
      isExtender = {
        description = "To display only agent information",
        value = true
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
        value = true
      },
      ShowTopologyWithoutHostManager = {
        description = "To display the Topology modal in Easymesh card when device details are not present in hostmanager",
        value = true
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
        value = false
      },
      backhaulDetails = {
        description = "To display the backhaul details in easy mesh configuration page",
        value = false
      },
      easyMeshButton = {
        description = "To display the button from which EasyMesh can be enabled or disabled",
        value = false
      },
      credShow = {
        description = "To display only cred0 fronthaul",
        value = false
      },
      frequencySelection = {
        description = "To display the freqency dropdown will all available interface",
        value = true
      },
      credStatusSwitch = {
        description = "To display the enable/disable cred controller",
        value = true
      },
      haulSwitch = {
        description = "To display the fronthaul and backhaul switching buttons",
        value = true
      },
      controllerAgentMacAddress = {
        description = "To display the controller and agent MAC Address",
        value = true
      },
      easyMeshConfirmPopup = {
        description = "To have the confirmation popup before enabling/disbaling EasyMesh",
        value = false
      },
      fronthaulString = {
        description = "To display the title as Fronthaul configuration or CRED0",
        value = false
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
        value = true
      },
      showPassword = {
        description = "To show/hide the password checkbox",
        value = false
      },
      ExtenderImage = {
        description = "To show the extender image not icon in topology tab",
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
        value = false
      }
    }
  },
  Firewall = {
    firewall = {
      levelMessage = {
        description = "To display the firewall high level",
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
