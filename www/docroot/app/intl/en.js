angular.module('fw')
    .constant('INTL_EN', {
        LANG: 'eng',
        LANG_L: 'Cambia lingua',
        SUBNAV : {
            HOME: 'home',
            WIFI: 'wifi',
            LINE: 'connection',
            DEVICES: 'devices',
            ADVANCED: 'advanced',
            MODEM: 'modem',
            INFO: 'information',
            VOICE: 'voice',
            ONT: 'ont',
            CHANGE_PASSWORD: 'Change password',
            SUPPORT: 'SUPPORT'
        },
        AUTH: {
            APPLY: 'Apply',
            CHANGE_PASSWORD: 'CHANGE PASSWORD',
            FIRSTLOGIN: 'FIRST TIME LOGIN',
            YOURETHEFIRST: 'You are first time to login.<br>Please set username and password.',
            LOGIN: 'LOGIN',
            REMEMBER_ME: 'Remember me',
            ERRORS: {
                WRONG_CREDENTIALS: 'Username or password incorrect',
                PASSWORD_MISSMATCH: 'The password does not match con confirmation',
                CHANGEPASSWORDERR: 'Something went wrong, try again'
            }
        },
        FOOTER: {
            SUGGESTIONS: 'Suggestions'
        },
        WEEK: {SUN: 'SUN', SAT: 'SAT', FRI: 'FRI', THU: 'THU', WED: 'WED', TUE: 'TUE', MON: 'MON'},
        LOADER: 'Loading...',
        FORMS: {
            SAVE_CHANGES: 'Save changes',
            CANCEL: 'Cancel',
            CLOSE: 'Close',
            DELETE: 'Delete', // Standard delete column name
            NAME: 'Name', // Standard name column name
            STATUS: 'Status', // Standard status column name
            ENABLED: 'Enabled',
            DISABLED: 'Disabled',
            CONNECTED: 'Connected',
            DISCONNECTED: 'Disconnected',
            ADD: 'Add',
            REMOVE: 'Remove',
            FROM_TIME: 'from',
            TO_TIME: 'to',
            ON_TIME: 'on',
            RANGE_FROM: 'from',
            RANGE_TO: 'to',
            REQUIRED: 'Error: invalid fields'
        },
        DEV_ICONS: {
            ICON0: 'Console',
            ICON1: 'Printer',
            ICON2: 'Computer',
            ICON3: 'Laptop',
            ICON4: 'Smartphone',
            ICON5: 'Tablet',
            ICON6: 'TV',
            ICON7: 'Other',
            ICON8: 'Hard disk'
        },
        WIDGETS: {
            LINE_STATUS: {
                TITLE: 'LINE STATUS (current bandwidth)',
                TITLE_SHORT: 'LINE STATUS',
                RANGE: {
                    TITLE: 'Range',
                    DAY: 'Day',
                    WEEK: 'Week',
                    MONTH: 'Month'
                },
                AVERAGE_UP: 'Average upload',
                AVERAGE_DOWN: 'Average download',
                AVERAGE_day: 'Daily average speed',
                AVERAGE_week: 'Weekly average <br />speed',
                NEW_LINE : 'Run a new test now',
                IP_ADDRESS: 'IP address',
                UPLOAD_M: 'UPLOAD <sub>average speed</sub>',
                DOWNLOAD_M: 'DOWNLOAD <sub>average speed</sub>'
            },
            DEVICES: {
                TITLE: 'ONLINE DEVICES',
                TITLE_SHORT: 'ONLINE DEVICES',
                FAMILY: 'devices <br />in family',
                FAMILY_M: 'IN FAMILY <sub>online devices</sub>',
                OTHERS: 'other <br />devices',
                OTHERS_M: 'OTHERS <sub>online device</sub>',
                ONLINE_NOW: 'online devices <br/>connected to the main network',
                CIRCLES: 'Circles:',
                FILTER:{
                    TITLE: 'Show',
                    STATE: 'Status',
                    BOOST: 'Boost',
                    STOP: 'Stop'
                }
            },
            LED_STATUS: {
                TITLE: 'LED STATUS',
                TITLE_SHORT: 'LED STATUS',
                LEGEND: {
                    PRESENCE: { TITLE: 'Ambient light', TITLE_M: 'Ambient <br />light', ON: 'OK', OFF: 'Off', ALTON: 'Ok', ALTOFF: 'Problem' },
                    LINE: { TITLE: 'Line status', TITLE_M: 'Linea', ON: 'Present', OFF: 'Off', NAN: '--', ALTON: 'Ok', ALTOFF: 'Problem' },
                    WIFI: { TITLE: 'Wifi status', TITLE_M: 'Wifi', ON: 'OK', OFF: 'Off', NAN: '--', ALTON: 'Ok', ALTOFF: 'Problem' },
                    WPS: { TITLE: 'WPS', TITLE_M: 'WPS', ON: 'OK', OFF: 'Off', NAN: '--', CON: 'Connecting', ALTON: 'Ok', ALTOFF: 'Problem' }
                },
                WARNING: 'WARNING!',
                WARNING_MSG: 'Issue detected on your system.',
                ALLRIGHT: 'EXCELLENT!',
                ALLRIGHT_MSG: 'No issues detected on your system.',
                WIFI_OFF: 'Your main network is currently disabled. To enable it go to the <a class="link" href="#/wifi" ui-sref="wifi">wifi</a> section',
                UPDATE: 'Refresh LED status'
            },
            WIFI_CHANNEL: {
                TITLE: 'WIFI CHANNEL',
                TITLE_SHORT: 'WIFI CHANNEL',
                NETWORKS_SHORT: 'nets',
                RESCAN_CHANNEL: 'Rescan WiFi channel',
                WIFI_CH: 'Currently active wifi channel',
                CHANNELS: 'channels',
                FILTER: {
                    TITLE: 'Manage',
                    FREQ2_4: 'Main network (2,4 GHz)',
                    FREQ2_4_M: '2,4 GHz network',
                    FREQ5: 'Main network (5 GHz)',
                    FREQ5_M: '5 GHz network'
                },
                BUSY: 'This channel is quite busy. Tune your network on other channels for better performances.'
            },
            PARENTAL_CONTROL: {
                TITLE: 'PARENTAL CONTROL',
                TITLE_SHORT: 'PARENTAL CONTROL',
                PROTECTED_DEVS: 'protected <br/>devices',
                ADD: 'Add device',
                REMOVE: 'Remove device',
                MODAL_TITLE_ADD: 'Add device to Parental Control',
                MODAL_TITLE_REMOVE: 'Remove device from Parental Control',
                MODAL_SEARCH_MODE_AUTO: 'Online devices',
                MODAL_SEARCH_MODE_MANUAL: 'Manual',
                ENABLED_ALL_NETWORK: 'Parental Control <br />enabled on the network.',
                ENABLED_ALL_DEVICES: 'All devices are protected.',
                DISABLED_ALL_NETWORK: 'Parental Control <br />not enabled.',
                DISABLED_ALL_DEVICES: 'None of your devices is protected.',
                SHOW_DETAILS: 'Show details'
            },
            FAMILY_DEVICES: {
                TITLE: 'IN-FAMILY DEVICES',
                ONLINE: 'online <br />devices',
                OFFLINE: 'offline <br />devices',
                ADD: 'Add device',
                REMOVE: 'Remove device',
                MODAL_TITLE_ADD: 'Add device to family',
                MODAL_SEARCH_MODE: 'Search mode',
                MODAL_SEARCH_MODE_ONLINE: 'Online devices',
                MODAL_SEARCH_MODE_OFFLINE: 'Offline devices',
                MODAL_SEARCH_NO_RESULT: 'No device found.',
                MODAL_DEVICE_LIST: 'Devices',
                MODAL_DEVICE_NAME: 'Device name',
                MODAL_ADD_MAC_ADDRESS: 'MAC address',
                MODAL_TITLE_REMOVE: 'Remove device from family',
                ACTIVE_ROUTINES: 'There are {{routines_num}} routines currently active: ',
                ACTIVE_ROUTINES_AND: ' and ',
                BOOST_ON: 'Boost on ',
                STOP_ON: 'Stop su '
            }
        },
        PENDING_CHANGES: {
            TITLE: 'ATTENTION!',
            MESSAGE: 'You have pending changes.',
            NOTES: 'Leaving this page your changes will be lost.',
            BTN_CONFIRM: 'Proceed'
        },
        ERROR_OPERATION: {
            TITLE: 'ERROR',
            MESSAGE: '<p>There was an error while performing the requested operation.</p>'+
                     '<p>Verify that you are connected to the network and try reloading the page.</p>'+
                     '<p>If the problem persists, please contact the Customer Support.</p>',
            CLOSE: 'Close'
        },
        PAGES: {
            WIFI: {
                MAIN_NETWORK: {
                    TITLE: 'MAIN NETWORK (2,4 GHz and 5 GHz)',
                    TITLE_SHORT: 'MAIN NETWORK',
                    SSID_NETWORK_NAME: 'Network name (SSID)',
                    SSID_BROADCAST: 'Broadcast SSID',
                    WIFI_SECURITY_TYPE: 'Protection',
                    PASSWORD: 'Password',
                    PASSWORD_SECURITY_LABEL: 'Password strength:',
                    PASSWORD_SECURITY: {
                        NONE: '--',
                        LOW: 'Low',
                        MEDIUM: 'Medium',
                        HIGH: 'High',
                        VERY_HIGH: 'Very high'
                    },
                    PASSWORD_GENERATE_NOW: 'Generate a new password now',
                    WPS_DESCRIPTION: 'The WPS function allows you to enable a fast internet connection between your FASTgate and a Wi-Fi device you intend to pair to {{ssid_value}} <br />'
                        +'Press the related button on your FASTgate until the LED will start blinking.  <br />'+
                        'Within 120 seconds, press the WPS button on the device too. <br />'+
                        'At the end of the procedure, a solid green light will serve for a successful pairing. <br />'+
                        'In presence of a solid red light, no connection estabilished.',
                    ACTIVATE_WPS_NOW: 'Trigger WPS now',
                    ACTIVATE_WPS_DESCRIPTION: "",
                    AUTO_SHUTDOWN: 'Automatic switch off',
                    AUTO_SHUTDOWN_DESCRIPTION: 'You will be unable to use your Wi-Fi connection for the last indicated in the timer. Once the timer will expire, your network will be automatically reactivate.',
                    ACTIVE: 'Active',
                    INACTIVE: 'Inactive',
                    WILL_SHUT_IN: 'WiFi will shut down in',
                    DURATION: 'Timer',
                    RADIUS_AUTHENTICATION_IPADDR: 'RADIUS Authentication Server IP',
                    RADIUS_AUTHENTICATION_PORT: 'RADIUS Authentication Server Port',
                    RADIUS_AUTHENTICATION_KEY: 'RADIUS Authentication Server key',
                    RADIUS_ACCOUNTING_IPADDR: 'RADIUS Accounting Server IP',
                    RADIUS_ACCOUNTING_PORT: 'RADIUS Accounting Server Port',
                    RADIUS_ACCOUNTING_KEY: 'RADIUS Accounting Server key'
                },
                GUEST_NETWORK: {
                    TITLE: 'GUEST NETWORK',
                    TITLE_SHORT: 'GUEST NETWORK',
                    PASSWORD_WILL_BE_REGENERATED: 'This password will be regenerated automatically at every new session or by forcing it through the button below.',
                    SHOW_QR_CODE: 'Show QR Code',
                    RESTRICTIONS: 'Restrictions to navigation',
                    MAX_TIME: 'Maximum time',
                    NO_MAX_TIME: 'None',
                    DEVICES_WILL_BE_DISCONNECTED: 'Connected devices to this network will be automatically disconnected after timeout',
                    FILTERING: 'Allow',
                    FILTERING_ALL: 'All services',
                    FILTERING_WEB: 'Only navigation',
                    TIME_LEFT: 'left'
                },
                MAIN_NETWORK_SHARED: {
                    ENABLED: 'Enabled',
                    DISABLED: 'Disabled',
                    DIVIDE_BY_BANDWIDTH: 'Split network by bandwidth',
                    DIVIDE_BY_BAND_DESCRIPTION: "To split the network based on bandwidth lets you choose the way to exchange datas via wifi, simply by selecting the network with the desired SSID extension.",

                    ACTIVE_5GHZ: '5 GHz enabled',
                    NAME_5GHZ: '5 GHz network name (SSID)',
                    SECURITY_5GHZ: '5 GHz network protection',
                    PASSWORD_5GHZ: '5 GHz network password',

                    ACTIVE_2_4GHZ: '2,4 GHz enabled',
                    NAME_2_4GHZ: '2,4 GHz network name (SSID)',
                    SECURITY_2_4GHZ: '2,4 GHz network protection',
                    PASSWORD_2_4GHZ: '2,4 GHz network password'
                },
                ECO_RANGES: {
                    NONE: 'Do not repeat',
                    WEEK_END: 'Weekends',
                    WEEKDAYS: 'Working days',
                    ALL: 'Daily'
                },
                AUTH_TYPES: {
                    NONE: 'Open',
                    NONE_DESCR: 'No protection (suggested)',
                    WEP: 'WEP',
                    WEP_DESCR: 'Due to remarkable flaws in their protection systems, the cryptographic methods of WEP and WPA TKIP are considered inefficient to the purpose therefore they are not recommended. We suggest to use them only in case you need to pair to the network devices which are not supported by the more recent standard. Devices that uses this methods of cryptography are not really efficient and won\'t benefit from the best performances.',
                    WPA2PSK: 'WPA2-PSK',
                    WPA2PSK_DESCR:'WPA2 implements the mandatory elements of IEEE 802.11i. In particular, it includes mandatory support for CCMP, an AES-based encryption mode with strong security.',
                    WPAWPA2PSK: 'WPA-PSK + WPA2-PSK',
                    WPAWPA2PSK_DESCR:'WPA2 implements the mandatory elements of IEEE 802.11i. In particular, it includes mandatory support for CCMP, an AES-based encryption mode with strong security.',

                    WPA2ENT: 'WPA2 Enterprise',
                    WPA2ENT_DESCR:'WPA2 implements the mandatory elements of IEEE 802.11i. In particular, it includes mandatory support for CCMP, an AES-based encryption mode with strong security.',
                    WPAWPA2ENT: 'WPA+WPA2 Enterprise',
                    WPAWPA2ENT_DESCR:'WPA2 implements the mandatory elements of IEEE 802.11i. In particular, it includes mandatory support for CCMP, an AES-based encryption mode with strong security.'
                },
                MODAL_WPS: {
                    TITLE_0: 'Waiting for a device connection...',
                    TITLE_1: 'Device connected!',
                    TITLE_2: 'No device connected.',
                    REMAINING: 'remaining seconds',
                    STATUS_SUCCESS: 'A new device has been connected to your main network and it\'s online.<br/><br/>Please go to <a ui-sref="devices" ng-click="ctrl.cancel()" href="#devices">Online Devices</a> to manage it.',
                    STATUS_FAILED: 'No devices connected.',
                },
                MODAL_WIFI_DISABLED: {
                    TITLE: 'ATTENTION!',
                    MESSAGE: 'Are you sure you want to disable the wifi <br />main network?',
                    NOTES: 'Remember that once you turned off connect with PC via ethernet cable to be able to rekindle <br />'+
                        'or press the <span class="ico-wps"></span> WPS button on your FASTGate.<br />' +
                        'Once activated wifi, all settings will be reset and you will not lose any <br />'+
                        'settings (network name, password, automatic shutdown...).',
                    BTN_CONFIRM: 'Turn off wifi'
                },
                MODAL_WIFI_RESTART: {
                    TITLE: 'ATTENTION!',
                    WAIT: 'PLEASE WAIT...',
                    MESSAGE: 'This may take up to a minute and temporarily disconnect your network devices.',
                    NOTES: 'At the end you could not surf the wifi. <br />Remember to reconnect to the network before proceeding.',
                    RECONFIGURING: 'Network reconfiguration in progress...',
                    BTN_CONFIRM: 'Proceed'
                }
            },
            INFO: {
                TECH_INFO: {
                    TITLE: 'DATA SHEET',
                    SUPPLIER_NAME: 'Producer',
                    PRODUCT_NAME: 'Product name',
                    SW_VERSION: 'Software version',
                    FW_VERSION: 'Firmware version',
                    LAN_UPTIME: 'Modem Uptime',
                    HW_VERSION: 'Hardware version',
                    GW_IP: 'Gateway IP',
                    MAC_ADDR: 'WAN MAC address'
                },
                LEGAL_NOTICES: {
                    TITLE: 'LEGAL NOTES'
                },
                ACTIONS: {
                    RESTART: 'Reboot Fastgate'
                }
            },
            LINE: {
                LINE_STATUS: {
                    TITLE: 'LINE STATE',
                    EDIT: {
                        VERIFY: 'Test automatically',
                        VERIFY_MAN: 'Test manually',
                        FREQ: 'Frequency',
                        FREQ_1: 'Daily',
                        FREQ_6: 'Six times per day',
                        FREQ_INFO:'All the tests run will be saved in History. </br>Attention! The capacity of saving the total amount of measurements is limitated: the more is the frequency of saving, the less is the time they’ll be kept in History.',
                        TABLE:{
                            TITLE: 'History',
                            ALL: 'All',
                            MAX: 'Max. peaks',
                            MIN: 'Min. peaks',
                            DATE: 'Date'
                        }

                    }
                },
                WIFI_CHANNEL: {
                    TITLE: 'WIFI CHANNEL',
                    SEARCH_CHANNEL: 'Auto-search <br />for best channel',
                    SEARCH_CHANNEL_DESC_2G: 'Auto-search selects one of the three non-overlapping frequencies - by chosing among channels 1, 6 or 11 - based on interference (RSSI) from other networks near you.',
                    SEARCH_CHANNEL_DESC_5G: 'The automatic search allows you to position yourself on the best wireless channel based on the interference of any other networks around you.',
                    CHANNEL: 'Current channel',
                    CHANNEL_DESC: 'If you wish to select a channel autonomously you can tell from the above graph the interference (RSSI) from other networks near you. <br /> Remember each network might influence contiguous channel in a range of 2.',
                    HZ_CHANNEL: 'Channel bandwidth',
                    CHANNEL_BUSY: 'The current channel is pretty busy! Tune your network in to other channels for better performance!',
                    EDIT:{
                        TABLE:{
                            TITLE: 'Details',
                            CHANNEL: 'Channel',
                            NAME: 'Network Name (SSID)',
                            MAC : 'MAC address (BSSID)',
                            RSSI: 'RSSI'
                        }
                    }
                }
            },
            DEVICES: {
                ONLINE: {
                    TITLE: 'ONLINE DEVICES',
                    TITLE_M: 'ONLINE',
                    DEVICE: 'Device name',
                    CIRCLE: 'Circle',
                    ACTIVE_BOOSTS: '1 boost active: {{boost_remaining}}\' remaining',
                    ACTIVE_STOPS: '1 stop active: {{stop_remaining}}\' remaining',
                    FAM_DEVICES_LINK_P1: 'Go to ',
                    FAM_DEVICES_LINK_P2: 'Family Devices',
                    FAM_DEVICES_LINK_P3: ' to manage routine.',
                    DURATION: 'Modality lasting',
                    IN_FAMILY: 'in Family',
                    OTHER: 'Other'
                },
                FAMILY_DEVICES: {
                    TITLE: 'FAMILY DEVICES',
                    TITLE_M: 'IN FAMILY',
                    TABLE : {
                        TITLE : 'Details',
                        DEVICES: 'Devices',
                        STATUS: 'Status',
                        MODE: 'Mode'
                    },
                    EDIT: {
                        NAME: 'Name',
                        ICON: 'Icon',
                        STATUS: 'Status',
                        LAST_CONNECTION: 'Last connected ',
                        CONNECTION: 'Connected by',
                        CONNECTION0: 'Ethernet',
                        CONNECTION1: 'Wifi',
                        CONNECTION_WIFI: 'Connected to ',
                        ROUTINE: 'Routine',
                        BOOST: 'Boost',
                        BOOST_STATUS: 'scheduled',
                        BOOST_AT: 'at',
                        BOOST_SCHEDULER: 'Timer',
                        STOP: 'Stop',
                        CONTROLLER: 'Parental Control',
                        WEEKEND: 'Weekend',
                        WORKING: 'Working days',
                        EVERYDAY: 'All days',
                        INFO: 'To manually set internet restrictions go to <a ui-sref="advanced" href="#/advanced">Avanced settings</a>'
                    }
                },
                OTHERS: {
                    TITLE: 'OTHER DEVICES',
                    TABLE : {
                        TITLE : 'Details',
                        DEVICES: 'Devices',
                        STATUS: 'Status',
                        MODE: 'Mode',
                        LAST_CONNECTION: 'Last connection'
                    }
                }
            },
            ADVANCED: {
                    PARENTAL: {
                        TITLE: 'PARENTAL CONTROL',
                        PC_ACTIVE: '{{dev_num}} protected devices.',
                        PC_INACTIVE: 'Parental control disabled.',
                        PC_ALL: 'Parental control is enabled on all devices',
                        ADD_NEW: 'Add URL',
                        MODAL_ADD_URL_TITLE: 'Add URL to block list',
                        FORM: {
                            APPLY_TO: {
                                TITLE: 'Apply to',
                                SINGLE: 'Selected devices',
                                ALL: 'Whole network',
                                DESCRIPTION: 'By manage the parental control by selected devices you will be able to enable specific settings for each of your devices, even through their related sections: <a href="#/devices">Devices</a>'
                            },
                            BLOCKS: {
                                TITLE: 'Blocks'
                            }
                        },
                        PROTECTED_DEVICES: 'PROTECTED DEVICES'
                    },
                    RESTRICTIONS: {
                        TITLE: 'RESTRICTIONS TO ACCESS',
                        ADD_NEW: 'Add device',
                        MODAL_TITLE_ADD: 'Add device',
                        MODAL_SEARCH_MODE: 'Search method',
                        MODAL_SEARCH_MODE_AUTO: 'Online devices',
                        MODAL_SEARCH_MODE_MANUAL: 'Add manually',
                        MODAL_DEVICE_LIST: 'Devices list',
                        MODAL_DEVICE_NAME: 'Device name',
                        MODAL_ADD_MAC_ADDRESS: 'Insert MAC address',
                        BEHAVIOUR: {
                            TITLE: 'Behaviour',
                            ALLOW: 'Allow access',
                            DENY: 'Deny access',
                            DESCRIPTION: 'By allowing you will enable the access to the devices placed in the below tab only. Devices which are not in there, won\'t be able to access your FASTgate.'
                        },
                        LIST: {
                            TITLE: 'List',
                            MAC: 'MAC address'
                        }
                    },
                    PORT_CONF_EASY: {
                        TITLE: 'SIMPLIFIED PORT MAPPING',
                        TITLE_MOBILE: 'PORT MAPPING',
                        UPNP: 'UPnP',
                        UPNP_DESC: "The UPnP is a communication protocol that allows devices on your internal network to automatically configure the opening of the connections on your Fastgate.",
                        UPNP_DET: {
                            TITLE: 'UPnP details',
                            DEST: 'Destination',
                            DESC: 'Description',
                            PROT: 'Protocol',
                            INT_PORT: 'Internal port',
                            EXT_PORT: 'External port'
                        },
                        MAPPING: {
                            CONSOLE: {
                                TITLE: 'Port mapping (console)',
                                ID: 'ID',
                                PROT: 'Protocol',
                                EXT_PORT: 'External port',
                                INT_PORT: 'Internal port',
                                ADD_NEW: 'Pair new port mapping to console'
                            },
                            SERVICE: {
                                TITLE: 'Port mapping (services)',
                                ADD_NEW: 'Pair new port mapping to service'
                            }
                        },
                        MODAL_TITLE_ADD_CONSOLES: 'Pair new port mapping to console',
                        MODAL_TITLE_ADD_SERVICES: 'Pair new port mapping to service',
                        MODAL_SEARCH_MODE: 'Search mode',
                        MODAL_SEARCH_MODE_AUTO: 'Online devices',
                        MODAL_SEARCH_MODE_MANUAL: 'Manual',
                        MODAL_DEVICE_LIST: 'Devices',
                        MODAL_DEVICE_NAME: 'Device name',
                        MODAL_ADD_IP_ADDRESS: 'IP address',
                        MODAL_ADD_CONSOLES: 'Console',
                        MODAL_ADD_SERVICES: 'Service'
                    },
                    PORT_CONF_MAN: {
                        TITLE: 'PORT MAPPING',
                        FIREWALL: 'Firewall',
                        MODAL_TITLE_ADD: 'pair new port mapping',
                        FW_DESC: 'The Firewall in off mode allows all outgoing connections without restrictions. Input, the IPv4 connections are regulated by sections DMZ and Port Mapping, IPv6 connections are unrestricted.',
                        PORT_INVALID: 'The selected port is not available, as it is currently used for interior of your FASTGate services.',
                        PORT_CONFLICTING: 'The selected port conflicts with another rule.',
                        LEVEL: {
                            TITLE: 'Security level',
                            NAME_1: 'High',
                            NAME_2: 'Medium',
                            DESC_1: 'The Firewall in high mode does not allow any connections outgoing and incoming.',
                            DESC_2: 'The Firewall in the medium mode only allows the use of web browsing and e-mail. Input, the IPv4 connections are regulated by sections DMZ and Port Mapping, IPv6 connections are limited only to responses initiated services from within.',
                            DESC: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.'
                        },
                        DMZ: 'DMZ',
                        DMZ_DESC: 'Fastgate will forward all the wan connections to the client configured in the DMZ, except those connections available in eventual configured postmappings.',
                        CLIENT: {
                            TITLE: 'Configured clients',
                            IP: 'IP address',
                            ADD_NEW: 'Configure new client'
                        },
                        MAPPING: {
                            TITLE: 'Port mapping',
                            SERVICE: 'Service',
                            IP: 'IP address',
                            PROT: 'Protocol',
                            EXT_PORT: 'External port',
                            INT_PORT: 'Internal port',
                            ADD_NEW: 'pair new port mapping'
                        }
                    },
                    USB_CONF: {
                        TITLE: 'USB SETTINGS',
                        DLNA: 'DLNA',
                        DLNA_DESC: 'DLNA allows sharing of media files within your home network.',
                        PRINT_SERVER: 'Print server',
                        PRINT_SERVER_DESC: 'The print server allows sharing of the printer connected to your Fastgate with devices connected to the home network.',
                        FILE_SHARE: 'File sharing',
                        FILE_SHARE_DESC: 'The file sharing service lets you share files present on disks connected to your Fastgate within the home network.',
                        DISKS: {
                            TITLE: 'Storage disks',
                            FS: 'File System',
                            TOT_SPACE: 'Capacity',
                            FREE_SPACE: 'Available',
                            EJECT: 'Eject',
                            EJECT_B: 'Remove safely'
                        },
                        SERVER_NAME: 'Hostname',
                        WORKGROUP: 'Work group',
                        INTERFACE: {
                            TITLE: 'Storage interface',
                            LAN: 'LAN',
                            LANWAN: 'LAN e WAN'
                        },
                        DISK_PROTECTION: 'Disks protection',
                        ID: 'ID',
                        PASS: 'Password',
                        MOBIL_BKUP: 'Mobile backup',
                        MOBIL_BKUP_DESC: 'Mobile Backup uses the UMTS modem connected to your Fastgate, to navigate even without connection.',
                        CONN_STATUS: 'Connection status',
                        SIM_PIN: 'PIN SIM card',
                        APN: 'Access point name (APN)',
                        USER: 'Username',
                        ACTIV_TYPE: {
                            TITLE: 'Kind of activation',
                            MAN: 'Manual',
                            MAN_DESC: 'man Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.',
                            MAN2: 'Manual with scheduled deactivation',
                            MAN2_DESC: 'man 2 Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.',
                            AUTO: 'Automatic',
                            AUTO_DESC: 'auto Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor indicidunt ut labore et dolore magna aliqua.'
                        },
                        CONNECT_BK: 'Activate backup now',
                        DEACTIVATE_AFTER: 'Disable after',
                        SECONDS: 'Seconds'
                    },
                    LAN_CONF: {
                        TITLE: 'LAN SETTINGS',
                        LONG_TITLE: 'LAN SETTINGS ON MAIN NETWORK',
                        FASTGATE_IP: 'Fastgate IP address',
                        IP: 'IP address',
                        MASK: 'Subnet mask',
                        DHCP: 'DHCP Server',
                        DHCP_POOL_RANGE: 'DHCP address pool',
                        VALIDITY: 'Leasing expiration',
                        MODAL_TITLE_ADD : 'Add DHCP static reservation',
                        MODAL_SEARCH_MODE: 'Search mode',
                        MODAL_SEARCH_MODE_AUTO: 'Online devices',
                        MODAL_SEARCH_MODE_MANUAL: 'Manual',
                        MODAL_DEVICE_LIST: 'Available devices',
                        MODAL_DEVICE_NAME: 'Device name',
                        MODAL_ADD_MAC_ADDRESS: 'MAC address',
                        DHCP_DETAILS: {
                            TITLE: 'DHCP reservations',
                            MAC: 'MAC address',
                            ADD_NEW: 'Add DHCP reservation'
                        },
                        IPV6_PREFIX: 'IPV6 prefix (6RD)',
                        ENABLE_IPV6: 'IPV6 on LAN',
                        IPV6_ON: 'ON',
                        IPV6_OFF: 'OFF'
                    }
            },
            MODEM: {
                REFRESH: 'Refresh',
                LED: {
                    TITLE: 'LED LIGHTS',
                    STATUS: {
                        TITLE: 'Status lights',
                        RESULT: 'Outcome',
                        LAST_VERIFICATION: 'Last check',
                        LINE: {
                            NAME: 'Line status',
                            RESULT: {
                                OFF: 'Off',
                                ON: 'Present',
                                NAN: '--'
                            },
                            DESCRIPTION: 'The line status will notify the proper functioning of your Internet connection if the light is green or off. '+
                            'When the light is flashing red it is ongoing synchronization FASTGate with Internet line, which can take several minutes. '+
                            'The steady red light indicates that Internet connectivity is not present: Check the proper connection of FASTGate the Internet line.'
                        },
                        WIFI: {
                            NAME: 'WiFi status',
                            RESULT: {
                                OFF: 'Off',
                                ON: 'OK',
                                NAN: '--'
                            },
                            DESCRIPTION: 'The static white light means that WiFi is working properly. '+
                                    ' A static red light may mean turned off WiFi or high interference channel of your network.'
                        },
                        WPS: {
                            NAME: 'WPS',
                            RESULT: {
                                OFF: 'Off',
                                ON: 'On',
                                CON: 'Connecting',
                                NAN: '--'
                            },
                            DESCRIPTION: 'WPS allows you to add new devices to your network without entering your WiFi password. Press the button on your FASTGate until the green light will flash. '+
                            'Within 120 seconds, press the WPS button also on the device you want to associate with. '+
                            'After the operation a green light will notify you that you are connected. '+
                            'The red light indicates instead that the connection failed: repeat the procedure or configure your device using the credentials WiFi or the QR Code found on the label or sticker on the back of the WiFi credentials modem. '+
                            'If the WiFi is off of your FASTGate also the WPS button allows you to turn it back easily.'
                        }
                    },
                    PRESENCE: 'Ambient light',
                    AUTO_OFF: {
                        TITLE: 'Automatic switch off',
                        DESCRIPTION: 'Switch off the ambient light during the nightime to avoid bothering. This won\'t prevent from wifi performance.'
                    }
                },
                LINE: {
                    TITLE: 'LINE VERIFICATIONS',
                    TITLE_M: 'LINE VERIFICATIONS',
                    LABELS: {
                        STATUS: 'Line status', DETAILS: 'Details', VERIFY: 'Test', RESULT: 'Result',
                        LINE: 'Line', IPV4: 'IPV4 address', HOP_PING: 'Next Hop Ping', DNS_PING: 'First DNS Server Ping'
                    },
                    DESC_END: 'Go to <a href="#/line">Line</a> section to verify the allignement speed.',
                    MESSAGES: {
                        STATUS: {
                            OK: {
                                SHORT: 'OK',
                                DESC: 'No problems found.'
                            },
                            NOK: {
                                SHORT: 'Error',
                                DESC: 'A problem on the line occurred.'
                            }
                        },
                        LINE: {
                            OK: {
                                SHORT: 'Present',
                                DESC: 'The line is active, with available internet services.'
                            },
                            NOK: {
                                SHORT: 'Absent',
                                DESC: 'The line is not active.'
                            }
                        },
                        IPV4: {
                            OK: {
                                SHORT: 'Found, ',
                                DESC: 'The IP address is configured correctly.'
                            },
                            NOK: {
                                SHORT: 'Absent',
                                DESC: 'No IP.'
                            }
                        },
                        HOP: {
                            OK: {
                                SHORT: 'Positive'
                            },
                            NOK: {
                                SHORT: 'Negative'
                            }
                        },
                        DNS: {
                            OK: {
                                SHORT: 'Positive'
                            },
                            NOK: {
                                SHORT: 'Negative'
                            }
                        }
                    }
                },
                WIFI: {
                    TITLE: 'WIFI VERIFICATIONS',
                    LABELS: {
                        STATUS: 'WiFi status', STATUS2: 'Status', DETAILS: 'Details', WIFI: 'WiFi', SECURITY: 'Protection',
                        F5GHZ: 'WiFi 5 GHz', F24GHZ: 'WiFi 2,4 GHz'
                    },
                    MESSAGES: {
                        STATUS: {
                            OK: 'OK', NOK: 'Error'
                        },
                        ACTIVE: 'Active', INACTIVE: 'Inactive'
                    }
                },
                PORTS: {
                    TITLE: 'PORTS VERIFICATIONS',
                    LABELS: {
                        ETH: 'Ethernet port status',
                        USB: 'USB status',
                        OK: 'Connected',
                        NOK: 'Not connected',
                        NAME: 'Name',
                        PORT: 'Port',
                        STATUS: 'Status'
                    }
                }
            },
            VOICE:{
                CALL_LIST:{
                    TITLE: 'CALL LOG',
                    TABLE: {
                        TITLE: 'History',
                        RECEIVED : 'Received',
                        LOST: 'Lost',
                        DONE: 'Done',
                        ALL: 'All',
                        DATE: 'Date',
                        HOURS: 'Hours',
                        NUMBER: 'Number',
                        DURATION: 'Duration',
                        DELETE: 'Delete',
                        DELETE_ALL: 'DELETE ALL'
                    }
                }
            },
            ONT: {
                TECH_INFO: {
                    TITLE: 'ONT',
                    BUTTON: 'GPON-Bridge',
                    INFOTOP: 'Enable the GPON-Bridge mode to use your own additional Router',
                    INFOBOTTOM: '<b>Warning:</b> By enabling the GPON-Bridge mode you will lose Internet connectivity </br> and you will not access the Fastgate from your browser anymore. </br>An additional Router connected to the Fastgate is needed to restore Internet connection',

                },
            }
        }
    });
