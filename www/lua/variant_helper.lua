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
  DevicesModal = {
    globalInfo = {
      fontColour = {
        description = "To differenciate font colour based on custo",
        value = "#004691"
      }
    }
  },
  WANServices = {
    PortMapping = {
      DMZ = {
        description = "To display DMZ option in portmapping and hide in settings tab",
        value = true
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
        value = false
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
      }
    },
    configuration = {
      hideConfiguration = {
        description = "To hide configuration section inside configuration tab",
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
      }
    },
    extenderTopology = {
      extenderName = {
        description = "To display the extender name with serial number",
        value = true
      }
    }
  },
  Diagnostics = {
    networkPage = {
      wifiConnect = {
        description = "To show the connectivity status of devices to wireless interface",
        value = true
       }
    }
  },
  Firewall = {
    firewall = {
      levelMessage = {
        description = "To display the firewall level",
        value = "firewall allows outgoing connections to HTTP, HTTPS, SMTP, POP3, IMAP, SSH services and silently drops unknown incoming connections. This may impact on web services like Internet Speed Test."
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
  }
}
