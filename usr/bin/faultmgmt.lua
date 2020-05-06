#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2016 Technicolor                                           **
-- ** All Rights Reserved                                                      **
-- **                                                                          **
-- ** This program contains proprietary information which is a trade           **
-- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- ** to retain this program in confidence and is not permitted to use or      **
-- ** make copies thereof other than as permitted in a written agreement       **
-- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- **                                                                          **
-- ******************************************************************************

local ubus = require("ubus")
local uloop = require("uloop")

local logger = require("transformer.logger")
local log = logger.new("faultmgmt", 6)

local cursor = require("uci").cursor()

local open = io.open
local format = string.format
local find = string.find
local match = string.match
local gmatch = string.gmatch
local lower = string.lower
local insert = table.insert
local remove = table.remove
local concat = table.concat
local date = os.date
local time = os.time

local fm_event_monitor = require("faultmgmt_event_monitor")

local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local type = type
local error = error
local xpcall = xpcall


-- UBUS connection
local ubus_conn

local acs_problem = {
  "9000 Method not supported",
  "9001 Request Denied",
  "9002 Internal error",
  "9003 Invalid arguments",
  "9004 Resources exceeded",
  "9005 Invalid parameter name",
  "9006 Invalid parameter type",
  "9007 Invalid parameter value",
  "9008 Attempt to set a non-writable parameter",
  "9009 Notification request rejected",
  "9010 Download failure",
  "9011 Upload failure",
  "9012 Unsupported protocol for file transfer",
  "Error on socket"
}

local client_problem = {
  "400 Bad Request",
  "401 Unauthorized",
  "402 Payment Required",
  "403 Forbidden",
  "404 Not Found",
  "405 Method Not Allowed",
  "406 Not Acceptable",
  "407 Proxy Authentication Required",
  "408 Request Timeout",
  "409 Conflict",
  "410 Gone",
  "411 Length Required",
  "412 Conditional Request Failed",
  "413 Request Entity Too Large",
  "414 Request-URI Too Long",
  "415 Unsupported Media Type",
  "416 Unsupported URI Scheme",
  "417 Unknown Resource-Priority",
  "420 Bad Extension",
  "421 Extension Required",
  "422 Session Interval Too Small",
  "423 Interval Too Brief",
  "424 Bad Location Information",
  "428 Use Identity Header",
  "429 Provide Referrer Identity",
  "430 Flow Failed",
  "433 Anonymity Disallowed",
  "436 Bad Identity-Info",
  "437 Unsupported Certificate",
  "438 Invalid Identity Header",
  "439 First Hop Lacks Outbound Support",
  "470 Consent Needed",
  "480 Temporarily Unavailable",
  "481 Call/Transaction Does Not Exist",
  "482 Loop Detected.",
  "483 Too Many Hops",
  "484 Address Incomplete",
  "485 Ambiguous",
  "486 Busy Here",
  "487 Request Terminated",
  "488 Not Acceptable Here",
  "489 Bad Event",
  "491 Request Pending",
  "493 Undecipherable",
  "494 Security Agreement Required",
}

local server_problem = {
  "500 Server Internal Error",
  "501 Not Implemented",
  "502 Bad Gateway",
  "503 Service Unavailable",
  "504 Server Time-out",
  "505 Version Not Supported",
  "513 Message Too Large",
  "580 Precondition Failure",
}
-- default supported alarm structure is:
-- {
--   ["EventType String"] = {
--     name = "string.",
--     ManagedObjectInstance = {
--       InternetGatewayDevice = "string",
--       Device = "string"
--     } or nil,
--     ["ProbableCause String"] = {
--       name = "string."
--       SpecificProblem = {
--         "string1",
--          ... ...
--         "stringN",
--       } or nil,
--       PerceivedSeverity = "string",
--       ReportingMechanism = "string",
--     },
--     ... ...
--     ["ProbableCause String"] = {
--     }
--   },
--   ... ...
--   ["EventType String"] = {
--   }
-- }
-- One supported alarm name is combined by three parts: "EventType name", "ProbableCause name" and "SpecificProblem id"
-- When SpecificProblem is nil, the id is "0".  For example, "Kernel Panic",
-- Its EventType name is "kernel_", "ProbableCause name" is "panic_" and SpecificProblem is nil.
-- The unique name of "Kernel Panic" is "kernel_panic_0".
--
-- The supported alarm UCI configuration can also be hierarchy according to name rule.
-- If section name is set to "EventType name", all the parameters in this EventType will be customized to UCI configuration.
-- the same action is when section name is set to "EventType name""ProbableCause name",
-- all the parameters in this level will be customized to UCI configuration
-- and its priority is higher than section name is only "EventType"

local default_supported_alarms = {
  ['CPE kernel'] = {
    name = 'kernel_',
    ['Kernel Panic'] = {
      name = 'panic_',
      PerceivedSeverity = 'Critical',
      ReportingMechanism = '0 Expedited',
    },
    ['Kernel Oops'] = {
      name = 'oops_',
      PerceivedSeverity = 'Critical',
      ReportingMechanism = '0 Expedited',
    },
  },
  ['DHCP client'] = {
    name = 'dhcpc_',
    ['NO OFFER/ACK'] = {
      name = 'ack_',
      SpecificProblem = {
        'No response was received from DHCP server',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['DHCPNAK'] = {
      name = 'nak_',
      SpecificProblem = {
        'Not specified',
        'Requested address is in wrong network',
        'Client lease expired',
        'Requested address has been allocated',
        'Requested address is invalid',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Request success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANIPConnection.{i}.DHCPClient',
      Device = 'Device.DHCPv4.Client.{i}, Device.DHCPv6.Client.{i},',
    },
  },
  ['DHCP server'] = {
    name = 'dhcps_',
    ['NO REQUEST/ACK'] = {
      name = 'ack_',
      SpecificProblem = {
        'No response was received from DHCP client',
      },
      PerceivedSeverity = 'Warning',
      ReportingMechanism = '2 Logged',
    },
    ['DHCPDECLINE'] = {
      name = 'decline_',
      SpecificProblem = {
        'Client reports the supplied address is already in use',
      },
      PerceivedSeverity = 'Warning',
      ReportingMechanism = '2 Logged',
    },
    ['IP provisioning success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '2 Logged',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.LANDevice.{i}.LANHostConfigManagement',
      Device = 'Device.DHCPv4.Server, Device.DHCPv6.Server',
    },
  },
  ['ACS provisioning'] = {
    name = 'acs_',
    ['Firmware upgrade error'] = {
      name = 'upgradeerror_',
      SpecificProblem = {
        'download upgrade image failed',
        'upgrade failed',
        'programming new firmware failed',
        'starting new firmware failed',
        'no URL specified',
      },
      PerceivedSeverity = 'Critical',
      ReportingMechanism = '0 Expedited',
    },
    ['Firmware upgrade success'] = {
      name = 'upgradesuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '0 Expedited',
    },
    ['Download and apply config file error'] = {
      name = 'dcfgerror_',
      SpecificProblem = {
        'download failed',
        'script execution failed',
        'reboot failed, setting error',
        'no URL specified',
      },
      PerceivedSeverity = 'Critical',
      ReportingMechanism = '0 Expedited',
    },
    ['Download and apply config file success'] = {
      name = 'dcfgsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '0 Expedited',
    },
    ['Upload vendor config file error'] = {
      name = 'ucfgerror_',
      SpecificProblem = {
        'Generate vendor config file failed',
        'Upload vendor config file failed',
        'no URL specified',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Upload vendor config file success'] = {
      name = 'ucfgsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['Upload vendor log file error'] = {
      name = 'logerror_',
      SpecificProblem = {
        'Generate vendor log file failed',
        'Upload vendor log file failed',
        'no URL specified',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Upload vendor log file success'] = {
      name = 'logsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['SetParameterValues error'] = {
      name = 'spverror_',
      SpecificProblem = acs_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['SetParameterValues success'] = {
      name = 'spvsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['GetParameterValues error'] = {
      name = 'gpverror_',
      SpecificProblem = acs_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['GetParameterValues success'] = {
      name = 'gpvsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['AddObject error'] = {
      name = 'adderror_',
      SpecificProblem = acs_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['AddObject success'] = {
      name = 'addsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['DeleteObject error'] = {
      name = 'delerror_',
      SpecificProblem = acs_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['DeleteObject success'] = {
      name = 'delsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['GetParameterAttributes error'] = {
      name = 'gpaerror_',
      SpecificProblem = acs_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['GetParameterAttributes success'] = {
      name = 'gpasuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['GetParameterNames error'] = {
      name = 'gpnerror_',
      SpecificProblem = acs_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['GetParameterNames success'] = {
      name = 'gpnsuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['SetParameterAttributes error'] = {
      name = 'spaerror_',
      SpecificProblem = acs_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['SetParameterAttributes success'] = {
      name = 'spasuccess_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ['Inform error'] = {
      name = 'informerror_',
      SpecificProblem = {
        'Failed to create Inform request',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Inform success'] = {
      name = 'informsuccess_',
      SpecificProblem = {
        'Succeeded to create Inform request',
      },
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.ManagementServer',
      Device = 'Device.ManagementServer',
    },
  },
  ['SIP register'] = {
    name = 'sipr_',
    ['Cannot contact server'] = {
      name = 'contact_',
      SpecificProblem = {
        'Unable to contact SIP server.',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['No response'] = {
      name = 'resp_',
      SpecificProblem = {
        'No response was received from SIP server.',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Client failure'] = {
      name = 'client_',
      SpecificProblem = client_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Server failure'] = {
      name = 'server_',
      SpecificProblem = server_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Register success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.Services.VoiceService.{i}.VoiceProfile.{i}.Line.{i}.SIP',
      Device = 'Device.Services.VoiceService.{i}.SIP.Client.{i},',
    },
  },
  ['SIP call'] = {
    name = 'sipc_',
    ['Cannot contact server'] = {
      name = 'contact_',
      SpecificProblem = {
        'Unable to contact SIP proxy.',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['No response'] = {
      name = 'resp_',
      SpecificProblem = {
        'No response was received from SIP proxy.',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Client failure'] = {
      name = 'client_',
      SpecificProblem = client_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Server failure'] = {
      name = 'server_',
      SpecificProblem = server_problem,
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Call success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.Services.VoiceService.{i}.VoiceProfile.{i}.Line.{i}.SIP',
      Device = 'Device.Services.VoiceService.{i}.SIP.Client.{i},',
    },
  },
  ['WiFi association'] = {
    name = 'wifi_',
    ['Authentication failure'] = {
      name = 'failure_',
      PerceivedSeverity = 'Warning',
      ReportingMechanism = '2 Logged',
    },
    ['Authentication success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '2 Logged',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.LANDevice.{i}.WLANConfiguration.{i},',
      Device = 'Device.WiFi.AccessPoint.{i},',
    },
  },
  ['DNS lookup'] = {
    name = 'dns_',
    ['Cannot contact server'] = {
      name = 'contact_',
      SpecificProblem = {
        'Unable to contact DNS server',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['No response'] = {
      name = 'resp_',
      SpecificProblem = {
        'No response was received from DNS server.',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Lookup failure'] = {
      name = 'failure_',
      SpecificProblem = {
        'NXDOMAIN',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Lookup success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANIPConnection.{i}.DNSServers,\
      InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANPPPConnection.{i}.DNSServers',
      Device = 'Device.DNS.Client.Server.{i}',
    },
  },
  ['xDSL'] = {
    name = 'dsl_',
    ['xDSL error'] = {
      name = 'error_',
      PerceivedSeverity = 'Critical',
      ReportingMechanism = '0 Expedited',
    },
    ['xDSL success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '0 Expedited',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.WANDevice.{i}.WANDSLInterfaceConfig',
      Device = 'Device.DSL.Line.{i},',
    },
  },
  ['Default GW'] = {
    name = 'dgw_',
    ['No response'] = {
      name = 'resp_',
      PerceivedSeverity = 'Critical',
      ReportingMechanism = '0 Expedited',
    },
    ['Link success'] = {
      name = 'success_',
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '0 Expedited',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANIPConnection.{i}.DefaultGateway,\
      InternetGatewayDevice.WANDevice.{i}.WANConnectionDevice.{i}.WANPPPConnection.{i}.DefaultGateway',
      Device = 'Device.Routing.Router.{i}.IPv4Forwarding.{i}.DestIPAddress, Device.Routing.Router.{i}.IPv6Forwarding.{i}.NextHop',
    },
  },
  ['NTP'] = {
    name = 'ntp_',
    ['Synchronizing failure'] = {
      name = 'failure_',
      SpecificProblem = {
        'Client failed to synchronize with NTP server',
      },
      PerceivedSeverity = 'Major',
      ReportingMechanism = '1 Queued',
    },
    ['Synchronizing success'] = {
      name = 'success_',
      SpecificProblem = {
        'Client succeeded to synchronize with NTP server',
      },
      PerceivedSeverity = 'Cleared',
      ReportingMechanism = '1 Queued',
    },
    ManagedObjectInstance = {
      InternetGatewayDevice = 'InternetGatewayDevice.Time.',
      Device = 'Device.Time.',
    },
  },
}
-- table for customizing supported alarms, priority is higher then defined supported alarms
-- uci supported event table structure is like following:
-- {
--   [name] = {
--     EventType = nil or 'xxxxx',
--     ProbableCause = nil or 'xxxxx',
--     SpecificProblem = nil or 'xxxxx',
--     PerceivedSeverity = nil or 'xxxxx' ,
--     ReportingMechanism = nil or 'xxxxx',
--   }
--   ...
--   ...
--   [name] = {
--     EventType = nil or 'xxxxx',
--     ProbableCause = nil or 'xxxxx',
--     SpecificProblem = nil or 'xxxxx',
--     PerceivedSeverity = nil or 'xxxxx' ,
--     ReportingMechanism = nil or 'xxxxx',
--   }
-- }
local uci_supported_alarms = {}

-- event table structure is like following:
-- {
--   [1] = {} -- table including:
--               - EventType, -- can get ManagedObjectInstance and default [EventType] table and name
--               - ProbableCause, -- can get PerceivedSeverity and default [EventType][ProbableCause] table and name
--               - id, -- get SpecificProblem value
--               - EventTime, -- for current alarm, this represents AlarmChangedTime
--               - AlarmIdentifier,
--               - NotificationType, -- served for event
--               - AdditionalText,
--               - AdditionalInformation
--               - AlarmRaisedTime, served for alarm
--             The table is shared by all the recorded tables (Expedited/Queued, History and Current Alarm)
--   ...
--   ...
--   [N] = {}
-- }
-- table for saving expedited events
local expedited_events = {}
-- pointer for FIFO replacing
local expedited_pointer = 0
-- maximum expedited table size
local expedited_size

-- table for saving queued events
local queued_events = {}
-- pointer for FIFO replacing
local queued_pointer = 0
-- maximum queued table size
local queued_size

-- table for saving history events
local history_events = {}
-- pointer for FIFO replacing
local history_pointer = 0
-- maximum history table size
local history_size

-- alarm table structure is the same as event structure
-- {
--   [1] = {}  -- changed alarm: table has the same structure described on the event table
--   ...
--   ...
--   [N] = {}
-- }
-- table for saving current alarms
local current_alarms = {}
-- maximum current table size
local current_size

-- maximum allowed event table size
local max_event_tbsize = 100

-- saving all the unique name
local name_set = {}


local unknown_time = "0001-01-01T00:00:00Z"
local datamodel

local event_tables = {
  expedited = { events = expedited_events },
  queued = { events = queued_events },
  history = { events = history_events },
  current = { events = current_alarms },
}

local function init_event_table(size)
  local t = {}
  for i=1,size do
    t[i] = {}
  end
  return t
end

local uci_mapping = {
  Enable = 'enabled',
  EventType = 'event_type',
  ProbableCause = 'probable_cause',
  SpecificProblem = 'specific_problem',
  PerceivedSeverity = 'perceived_severity',
  ReportingMechanism = 'reporting_mechanism',
  ManagedObjectInstance = 'managed_object'
}

local function get_tb_size(size)
  if type(size) ~= "number" or size < 0 then
    return 0
  end
  if size > max_event_tbsize then
    return max_event_tbsize
  else
    return size
  end
end

local function init()
  local config = "faultmgmt"
  local section = "global"

  -- get global parameters
  local global = cursor:get_all(config, section)
  -- set tables size
  expedited_size = get_tb_size(tonumber(global["expedited_event_tbsize"]))
  queued_size = get_tb_size(tonumber(global["queued_event_tbsize"]))
  history_size = get_tb_size(tonumber(global["history_event_tbsize"]))
  current_size = get_tb_size(tonumber(global["maxcurrent_alarm_tbsize"]))

  event_tables.expedited.size = expedited_size
  event_tables.queued.size = queued_size

  -- set datamodal
  datamodel = global["datamodel"] or "InternetGatewayDevice"

  -- get custo supported alarms from UCI configuration file
  cursor:foreach(config, "supportedalarm", function(s)
    uci_supported_alarms[s['.name']] = {}
    for k,v in pairs(uci_mapping) do
      uci_supported_alarms[s['.name']][k] = s[v]
    end
  end)

  -- initialize name set
  for etype,tetype in pairs(default_supported_alarms) do
    for pcause,tpcause in pairs(tetype) do
      if tpcause.name then
        if not tpcause.SpecificProblem  then
          id = 0
          name = format("%s%s%d", tetype.name, tpcause.name, id)
          name_set[name] = true
        else
          for id,v in ipairs(tpcause.SpecificProblem) do
            name = format("%s%s%d", tetype.name, tpcause.name, id)
            name_set[name] = true
          end
        end
      end
    end
  end

  -- write notification setting to cwmp configuration files
  local expedited_notify = format("%s.FaultMgmt.ExpeditedEvent.|Active", datamodel)
  local queued_notify = format("%s.FaultMgmt.QueuedEvent.|Passive", datamodel)
  config = "cwmpd"
  section = "cwmpd_config"
  local option = "notifications"
  local notifications = cursor:get(config, section, option) or {}

  if match(concat(notifications, " "), expedited_notify) == nil then
    insert(notifications, expedited_notify)
  end

  if match(concat(notifications, " "), queued_notify) == nil then
    insert(notifications, queued_notify)
  end
  cursor:set(config, section, option, notifications)
  cursor:commit(config)
end

local function add_alarm_to_table(t, size, event)
  if type(t) ~= "table" or type(event) ~= "table" then
    return false
  end
  if size <= 0 then
    return false
  end

  local oldest_time = event.EventTime
  local oldest_id = 0

  -- determine alarm is existed or not
  for k,v in ipairs(t) do
    if (v.EventType == event.EventType and
      v.ProbableCause == event.ProbableCause and
      v.id == event.id ) then
      event.AlarmRaisedTime = v.AlarmRaisedTime
      t[k] = event
      return "ChangedAlarm"
    end
    -- find the oldest entry
    if v.EventTime < oldest_time then
      oldest_time = v.EventTime
      oldest_id = k
    end
  end

  if #t < size then
    t[#t + 1] = event
  else
    t[oldest_id] = event
  end
  return "NewAlarm"
end

-- clear all events this type event when the EventType is in the clear_all table
local clear_all = {
  ["DHCP client"] = true,
  ["DHCP server"] = true,
  ["SIP register"] = true,
  ["SIP call"] = true,
  ["DNS lookup"] = true,
  ["Default GW"] = true,
}

local function clear_alarm_from_table(t, event)
  local alarmtype = nil
  if type(t) ~= "table" or type(event) ~= "table" then
    return false
  end
  local reserved = {}
  for k,v in ipairs(t) do
    if (v.EventType ~= event.EventType or ( not clear_all[event.EventType] and
      match(v.ProbableCause, "^(.*)%s[^%s]+$") ~= match(event.ProbableCause, "^(.*)%s[^%s]+$"))) then
      reserved[#reserved + 1] = v
    else
      if not alarmtype then
        alarmtype = "ClearedAlarm"
      end
    end
  end
  return reserved, alarmtype
end

local function add_event_to_table(t, p, size, event)
  if type(t) ~= "table" or type(event) ~= "table" then
    return false
  end
  if p < 0 or p > size then
    return false
  end
  if p == size then
    p = 1
  else
    p = p + 1
  end
  t[p] = event
  return p
end

local function get_parameter_value(event_type, probable_cause, id, param, default, maxlen)
  if not default_supported_alarms[event_type] or
    not default_supported_alarms[event_type][probable_cause] or
    type(id) ~= "number" or
    type(param) ~= "string" then
    return ""
  end

  local tetype = default_supported_alarms[event_type]
  local tpcause = tetype[probable_cause]
  local name = format("%s%s%d", tetype.name, tpcause.name, id)
  -- for different level configuration
  local spec_cfg  = uci_supported_alarms[name]
  local cause_cfg = uci_supported_alarms[tpcause.name]
  local type_cfg  = uci_supported_alarms[tetype.name]

  local value = default
  if type(default) == "table" then
    value = default[param]
  end

  -- different config has different priority, more specification more higher priority
  value = (spec_cfg and spec_cfg[param]) or
  (cause_cfg and cause_cfg[param]) or
  (type_cfg and type_cfg[param]) or value or ""

  if maxlen and type(value) == "string" then
    value = value:sub(1,maxlen)
  end

  return value
end

-- Generate a unique key
-- This function will generate a 16byte key by reading data from dev/urandom
local key = ("%02X"):rep(8)
local fd = assert(open("/dev/urandom", "r"))
local function generate_key()
  local bytes = fd:read(8)
  return key:format(bytes:byte(1,8))
end


-- Handles an alarm event update on UBUS
-- UBUS message has two formats, one is error:
--    {"FaultMgmt.Event": {
--      "Source":"modulename",
--      "EventType":"value",
--      "ProbableCause":"value",
--      "SpecificProblem":"value",
--      "AdditionalText":"value",
--      "AdditionalInformation":"value"
--    }}
-- the other is success:
--    {"FaultMgmt.Event": {
--      "Source":"modulename",
--      "EventType":"value",
--      "ProbableCause":"xxx success",
--      "AdditionalText":"value",
--      "AdditionalInformation":"value"
--    }}
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_event_update(msg)
  if (type(msg) ~= "table" or
    type(msg.EventType) ~= "string" or
    type(msg.ProbableCause) ~= "string" or
    default_supported_alarms[msg.EventType] == nil or
    default_supported_alarms[msg.EventType][msg.ProbableCause] == nil or
    type(default_supported_alarms[msg.EventType][msg.ProbableCause]) ~= "table" or
    default_supported_alarms[msg.EventType][msg.ProbableCause].name == nil
    ) then
    log:info("Ignoring improper event")
    return
  end

  local etype = msg.EventType
  local pcause = msg.ProbableCause
  local tetype = default_supported_alarms[etype]
  local tpcause = tetype[pcause]
  local tsproblem = tpcause.SpecificProblem
  local id = 0

  if type(tsproblem) == "table" then
    for k,v in ipairs(tsproblem) do
      if msg.SpecificProblem == v or find(msg.SpecificProblem, v) then
        id = k
      end
    end
  end

  if (id == 0 and (tsproblem or (msg.SpecificProblem and msg.SpecificProblem ~= ""))) then
    log:info("Ignoring improper event")
    return
  end

  local enabled = get_parameter_value(etype, pcause, id, "Enable")
  -- if uci set enabled to '0', suppressing event
  if enabled == '0' then
    log:info("Suppressing disabled event")
    return
  end

  -- ReportingMechanism is an enumerate of  "0 Expedited", "1 Queued", "2 Logged", and "3 Disabled"
  local mechanism = get_parameter_value(etype, pcause, id, "ReportingMechanism", tpcause)
  -- if reporting mechanism is "3 Disabled", suppressed event
  if mechanism == "3 Disabled" then
    log:info("Suppressing disabled event")
    return
  end

  local event = {}
  event.EventType = msg.EventType
  event.ProbableCause = msg.ProbableCause
  event.id = id
  event.EventTime = tonumber(time())
  event.AlarmRaisedTime = event.EventTime
  event.AlarmIdentifier = generate_key()
  event.AdditionalText = msg.AdditionalText and msg.AdditionalText:sub(1,256) or ""
  event.AdditionalInformation = msg.AdditionalInformation and msg.AdditionalInformation:sub(1,256) or ""

  local severity = get_parameter_value(etype, pcause, id, "PerceivedSeverity", tpcause)

  local cause = match(msg.ProbableCause, "^(.*) success$")
  if cause or severity == "Cleared" then
    -- clear event from current alarm table
    current_alarms, event.NotificationType = clear_alarm_from_table(current_alarms, event)
    event_tables.current.events = current_alarms
  else
    -- add event to current alarm table, and return the notification type(NewAlarm or ChangedAlarm)
    event.NotificationType = add_alarm_to_table(current_alarms, current_size, event)
  end
  if event.NotificationType then
    -- add event to history table
    history_pointer= add_event_to_table(history_events, history_pointer, history_size, event)

    local smsg = {}
    if mechanism == "0 Expedited" then
      expedited_pointer = add_event_to_table(expedited_events, expedited_pointer, expedited_size, event)
      if expedited_pointer then
        smsg.Key = format("%s|%d", "expedited", expedited_pointer)
        ubus_conn:send('faultmgmt.expeditedevent', smsg)
      end
    elseif mechanism == "1 Queued" then
      queued_pointer = add_event_to_table(queued_events, queued_pointer, queued_size, event)
      if queued_pointer then
        smsg.Key = format("%s|%d", "queued", queued_pointer)
        ubus_conn:send('faultmgmt.queuedevent', smsg)
      end
    end
  end
end

-- Callback function when 'faultmgmt.event get' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_get(req, msg)
  -- table name set is: "supported", "expedited", "queued", "history", "current"
  local table_name = msg['table_name']
  local response = {}
  local key
  local name
  local id

  if table_name == "supported" then
    for etype,tetype in pairs(default_supported_alarms) do
      for pcause,tpcause in pairs(tetype) do
        if tpcause.name then
          if not tpcause.SpecificProblem  then
            id = 0
            name = format("%s%s%d", tetype.name, tpcause.name, id)
            response[name] = {}
            response[name].EventType = get_parameter_value(etype, pcause, id, "EventType", etype, 64)
            response[name].ProbableCause = get_parameter_value(etype, pcause, id, "ProbableCause", pcause, 64)
            response[name].SpecificProblem = get_parameter_value(etype, pcause, id, "SpecificProblem", nil, 128)
            response[name].PerceivedSeverity = get_parameter_value(etype, pcause, id, "PerceivedSeverity", tpcause)
            response[name].ReportingMechanism =  get_parameter_value(etype, pcause, id, "ReportingMechanism", tpcause)
          else
            for id,v in ipairs(tpcause.SpecificProblem) do
              name = format("%s%s%d", tetype.name, tpcause.name, id)
              response[name] = {}
              response[name].EventType = get_parameter_value(etype, pcause, id, "EventType", etype, 64)
              response[name].ProbableCause = get_parameter_value(etype, pcause, id, "ProbableCause", pcause, 64)
              response[name].SpecificProblem = get_parameter_value(etype, pcause, id, "SpecificProblem", v, 128)
              response[name].PerceivedSeverity = get_parameter_value(etype, pcause, id, "PerceivedSeverity", tpcause)
              response[name].ReportingMechanism =  get_parameter_value(etype, pcause, id, "ReportingMechanism", tpcause)
            end
          end
        end
      end
    end
  else
    local event_table = event_tables[table_name]
    local utc_time
    local instance
    local dummy = {
      EventTime = unknown_time,
      AlarmIdentifier = "",
      NotificationType = "",
      ManagedObjectInstance = "",
      EventType = "",
      ProbableCause = "",
      SpecificProblem = "",
      PerceivedSeverity = "",
      AdditionalText = "",
      AdditionalInformation = ""
    }

    if not event_table then
      log:info("table name is invalid.")
      return false
    end

    local alarms = event_table.events
    local size = event_table.size

    local etype
    local pcause
    local tetype
    local tpcause
    local id

    for i,alarm in ipairs(alarms) do
      id = alarm.id
      etype = alarm.EventType
      pcause = alarm.ProbableCause
      tetype = default_supported_alarms[etype]
      tpcause = tetype[pcause]
      -- here key will be as igd/dev2 multiple instance key
      key = format("%s|%d", table_name, i)
      response[key] = {}

      utc_time = date("%Y-%m-%dT%H:%M:%SZ", alarm["EventTime"])
      if table_name == "current" then
        response[key].AlarmChangedTime = utc_time
        response[key].AlarmRaisedTime = date("%Y-%m-%dT%H:%M:%SZ", alarm.AlarmRaisedTime)
      else
        response[key].EventTime = utc_time
        response[key].NotificationType = alarm.NotificationType
      end

      id = alarm.id
      response[key].EventType = get_parameter_value(etype, pcause, id, "EventType", etype, 64)
      response[key].ProbableCause = get_parameter_value(etype, pcause, id, "ProbableCause", pcause, 64)
      if id ~= 0 then
        response[key].SpecificProblem = get_parameter_value(etype, pcause, id, "SpecificProblem", tpcause.SpecificProblem[id], 128)
      else
        response[key].SpecificProblem = get_parameter_value(etype, pcause, id, "SpecificProblem", nil, 128)
      end
      response[key].PerceivedSeverity = get_parameter_value(etype, pcause, id, "PerceivedSeverity", tpcause)
      instance = get_parameter_value(etype, pcause, id, "ManagedObjectInstance", tetype, 512)
      if type(instance) == "table" then
        response[key].ManagedObjectInstance = instance[datamodel]
      else
        response[key].ManagedObjectInstance = instance
      end

      response[key].AlarmIdentifier = alarm.AlarmIdentifier
      response[key].AdditionalText = alarm.AdditionalText
      response[key].AdditionalInformation = alarm.AdditionalInformation
    end

    -- for expedited and queued table, add the unpopulated entry
    if size and size > #alarms then
      local n = #alarms + 1
      for i=n,size do
        key = format("%s|%d", table_name, i)
        response[key] = dummy
      end
    end
  end

  ubus_conn:reply(req, response)
end

local mechanisms = {
  ["0 Expedited"] = true,
  ["1 Queued"] = true,
  ["2 Logged"] = true,
  ["3 Disabled"] = true
}
-- Callback function when 'faultmgmt.event set' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_set(req, msg)
  local name = msg['alarm_name']
  local mechanism = msg['reporting_mechanism']

  if not name or not name_set[name] then
    log:info("Name is invalid.")
    ubus_conn:reply(req, {error = "Name is invalid."})
    return false
  end

  if not mechanism or not mechanisms[mechanism] then
    log:info("Reporting mechanism is invalid.")
    ubus_conn:reply(req, {error = "Reporting mechanism is invalid."})
    return false
  end

  local config = "faultmgmt"
  if not uci_supported_alarms[name] then
    uci_supported_alarms[name] = {}
    cursor:set(config, name, "supportedalarm")
  end
  uci_supported_alarms[name].ReportingMechanism = mechanism

  cursor:set(config, name, "reporting_mechanism", mechanism)
  cursor:commit(config)
  ubus_conn:reply(req, {ok = "Successfully set"})
  return true

end

local function errhandler(err)
  log:critical(err)
  for line in gmatch(debug.traceback(), "([^\n]*)\n") do
    log:critical(line)
  end
end

-- Main code
init()

uloop.init()
ubus_conn = ubus.connect()
if not ubus_conn then
  log:error("Failed to connect to ubus")
end

-- Register RPC callback
ubus_conn:add( { ['faultmgmt.event'] = {
  get = { handle_rpc_get, {["table_name"] = ubus.STRING} },
  set = { handle_rpc_set, {["alarm_name"] = ubus.STRING, ["reporting_mechanism"] = ubus.STRING } },
} } )

-- Register event listener
ubus_conn:listen({
  ['FaultMgmt.Event'] = handle_event_update,
  ['mmpbxrvsipnet.status'] = handle_event_update,
})

-- Start event monitor
fm_event_monitor.create_defaultGW_monitor()
-- Idle loop
while true do
  xpcall(uloop.run,errhandler)
end
