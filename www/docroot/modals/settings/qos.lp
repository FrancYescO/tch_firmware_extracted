--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local session = ngx.ctx.session
  local content_helper = require("web.content_helper")
  local post_helper = require("web.post_helper")
  local proxy = require("datamodel")
  local json = require("dkjson")
  local vdf_helper = require("vodafone_helper")
  local validateNetmask = vdf_helper.validateNetmask
  local validateBoolean = post_helper.validateBoolean
  local getOrValidation = post_helper.getOrValidation
  local getValInEnum = post_helper.getValidateInEnumSelect
  local pairs, ipairs, tonumber = pairs, ipairs, tonumber
  local untaint_mt = require("web.taint").untaint_mt
  local string = string
  local format, match, gmatch, lower = string.format, string.match, string.gmatch, string.lower
  local table = table
  local setmetatable = setmetatable
  local interfacesList = proxy.getPN("uci.network.interface.", true)
  local interfaces = {}

  -- These interfaces will not be available for QoS rules configuration since they are managed automatically by wansensing
  local notRequiredInterfaces = {
    ["ull_data"] = true,
    ["ull_video"] = true,
    ["FTTH_TIVO"] = true,
    ["FTTH_data_ipoe"] = true,
    ["FTTH_data_pppoe"] = true,
    ["FTTH_data_pppoe_NEBA"] = true,
    ["vdsl_ull_data_ipoe"] = true,
    ["vdsl_ull_data_pppoe"] = true,
    ["vdsl_ull_video"] = true,
    ["vdsl_ull_voice"] = true,
    ["adsl_wholesales"] = true,
    ["adsl_wholesales_NEBA"] = true,
  }

  local reservedValues = {
    gwIP   = "uci.network.interface.@lan.ipaddr",
    qtnMac = "uci.env.var.qtn_eth_mac",
  }
  content_helper.getExactContent(reservedValues)

  reservedValues["bcast"] = "192.168.0.255"
  reservedValues["specialBcast"] = "255.255.255.255"

  local qtnIP = content_helper.getMatchedContent("sys.proc.net.arp.",{ hw_address = lower(reservedValues.qtnMac)})

  for _, v in pairs(interfacesList) do
    if not notRequiredInterfaces[match(v.path, "@(.+)%.")] then
      interfaces[#interfaces+1] = {match(v.path, "@(.+)%.")}
    end
  end

  -- Interface can be set as empty if user selects No Interface from GUI for a QoS rule
  interfaces[#interfaces+1] = {""}

  -- According to Openwrt IPv4 route specification,255.255.255.255 is assumed which makes target a host address
  local SubnetMask = {{"255.255.255.255"}}

  local protocolList = {
    { "1",   "ICMP"     },
    { "2",   "IGMP"     },
    { "6",   "TCP"      },
    { "17",  "UDP"      },
    { "47",  "GRE"      },
    { "50",  "ESP"      },
    { "51",  "AH"       },
    { "132", "SCTP"     },
    { "-1",  T"All "    },
  }

  local protocolMap = setmetatable({
    ["1"]   = "ICMP",
    ["2"]   = "IGMP",
    ["6"]   = "TCP",
    ["17"]  = "UDP",
    ["47"]  = "GRE",
    ["50"]  = "ESP",
    ["51"]  = "AH",
    ["132"] = "SCTP",
    ["-1"]  = T"All"
  }, untaint_mt)

  local queueMap = setmetatable({}, untaint_mt)

  local queueList = setmetatable({}, untaint_mt)

  local ethProto = setmetatable({
    { "4", "IP" },
    { "802.1Q", "802.1Q" },
    { "97", "PPPoE" },
    { "41", "IPv6" },
  }, untaint_mt)

  local ethProtomap = setmetatable({
    ["all"]  = "IP",
    ["icmp"] = "IP",
    ["tcp"]  = "IP",
    ["udp"]  = "IP",
    ["gre"]  = "IP",
    ["esp"]  = "IP",
    ["ah"]  = "IP",
    ["sctp"] = "IP",
    ["udplite"] = "IP",
    ["4"]   =  "IP",
    ["802.1Q"] = "802.1Q",
    ["97"] = "PPPoE",
    ["41"] = "IPv6",
  }, untaint_mt)


  --- Check that the given value is a valid Port(1-65535).
  -- Empty string is also valid
  -- @param #string port The port number
  -- @return true or nil
  local function validatePort(port)
    if port then
      if port == "" then
        return true
      else
        return post_helper.validateStringIsPort(port)
      end
    end
    return nil
  end

  local validateDSCPCheck = post_helper.getValidateNumberInRange(0, 63)
  local validateDSCPMark = post_helper.getValidateNumberInRange(0, 63)
  local validateEthernetPriorityCheck = post_helper.getValidateNumberInRange(0, 7)
  local validateUpstreamBandwidth = post_helper.getValidateNumberInRange(0, 2147483647)
  local validateName = post_helper.getValidateStringLengthInRange(1, 63)
  local function validateUpstream(data, postdata, key)
     if data ~= ""  then
         return validateUpstreamBandwidth(data)
     end
     postdata["bandwidth"]  = "-1"
     return true
  end
  -- Below table QoSParameters contains all the parameters appearing for either rule/l2classify
  local QoSParameters  = {
    [1]  = "index",
    [2]  = "Order",
    [3]  = "DSCPMark",
    [4]  = "Interface",
    [5]  = "EthernetProtocol",
    [6]  = "ProtocolExclude",
    [7]  = "Protocol",
    [8]  = "SourceIPExclude",
    [9]  = "SourceIP",
    [10] = "SourceMask",
    [11] = "DestIPExclude",
    [12] = "DestIP",
    [13] = "DestMask",
    [14] = "SourcePort",
    [15] = "SourcePortRangeMax",
    [16] = "DestPort",
    [17] = "DestPortRangeMax",
    [18] = "SourceMACAddress",
    [19] = "SourceMACMask",
    [20] = "SourceMACExclude",
    [21] = "DestMACAddress",
    [22] = "DestMACMask",
    [23] = "DestMACExclude",
    [24] = "DSCPCheck",
    [25] = "EthernetPriorityCheck",
    [26] = "Name",
    [27] = "Queue",
    [28] = "Enable",
    [29] = "Ruletype",
  }

  -- Below table QosParamsRule contains list of params used only for QoS rule
  local QoSParamsRule  = {
    [1]  = "index",
    [2]  = "Interface",
    [3]  = "ProtocolExclude",
    [4]  = "Protocol",
    [5]  = "SourceIPExclude",
    [6]  = "SourceIP",
    [7]  = "SourceMask",
    [8]  = "DestIPExclude",
    [9]  = "DestIP",
    [10] = "DestMask",
    [11] = "SourcePort",
    [12] = "SourcePortRangeMax",
    [13] = "DestPort",
    [14] = "DestPortRangeMax",
    [15] = "DSCPCheck",
    [16] = "EthernetPriorityCheck",
    [17] = "Name",
    [18] = "Queue",
    [19] = "Enable",
  }

  -- Below table QoSParamsRuletable is used to extract parameters related only to "rule" while editing
  local QoSParamsRuletable  = {
   ["index"] = true,
   ["Order"] = true,
   ["Interface"] = true,
   ["ProtocolExclude"] = true,
   ["Protocol"] = true,
   ["SourceIPExclude"] = true,
   ["SourceIP"] = true,
   ["SourceMask"] = true,
   ["DestIPExclude"] = true,
   ["DestIP"] = true,
   ["DestMask"] = true,
   ["SourcePort"] = true,
   ["SourcePortRangeMax"] = true,
   ["DestPort"] = true,
   ["DestPortRangeMax"] = true,
   ["DSCPCheck"] = true,
   ["EthernetPriorityCheck"] = true,
   ["Name"] = true,
   ["Queue"] = true,
   ["Enable"] = true,
  }

  -- Below table emptyParams is used to consider params which can be provided empty values while adding
  local emptyParams = {
    ["Name"] = true,
    ["Interface"] = true,
    ["Protocol"] = true,
    ["EthernetProtocol"] = true,
    ["SourceIP"] = true,
    ["DestIP"] = true,
    ["SourcePort"] = true,
    ["SourcePortRangeMax"] = true,
    ["DestPort"] = true,
    ["DestPortRangeMax"] = true,
    ["SourceMACAddress"] = true,
    ["SourceMACMask"] = true,
    ["DestMACAddress"] = true,
    ["DestMACMask"] = true,
    ["DSCPMark"] = true,
  }

  local setEmptyParams = {
    ["Name"] = true,
    ["Interface"] = true,
    ["SourceIP"] = true,
    ["DestIP"] = true,
    ["SourcePort"] = true,
    ["SourcePortRangeMax"] = true,
    ["DestPort"] = true,
    ["DestPortRangeMax"] = true,
  }

  local QoSPortParameters = {
    "SourcePort",
    "SourcePortRangeMax",
    "DestPort",
    "DestPortRangeMax",
  }

  local QoSValidations = {
    Name                  = post_helper.getOptionalValidation(validateName),
    Interface             = post_helper.getOptionalValidation(post_helper.getValidateInEnumSelect(interfaces)),
    EthernetProtocol      = post_helper.getOptionalValidation(post_helper.getValidateInEnumSelect(ethProto)),
    Protocol              = post_helper.getValidateInEnumSelect(protocolList),
    SourceIP              = post_helper.getOptionalValidation(post_helper.getAndValidation(post_helper.validateStringIsIP, post_helper.reservedIPValidation)),
    DestIP                = post_helper.getOptionalValidation(post_helper.getAndValidation(post_helper.validateStringIsIP, post_helper.reservedIPValidation)),
    SourceMACAddress      = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    SourceMACMask         = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    SourceMask            = getOrValidation(validateNetmask, getValInEnum(SubnetMask)),
    DestMACAddress        = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    DestMACMask           = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    DestMask              = getOrValidation(validateNetmask, getValInEnum(SubnetMask)),
    DSCPMark              = validateDSCPMark,
    DSCPCheck             = validateDSCPCheck,
    EthernetPriorityCheck = validateEthernetPriorityCheck,
    status                = validateBoolean,
    ProtocolExclude       = validateBoolean,
    SourceIPExclude       = validateBoolean,
    DestIPExclude         = validateBoolean,
    SourceMACExclude      = validateBoolean,
    DestMACExclude        = validateBoolean,
    bandwidth             = validateUpstream,
    Enable                = validateBoolean,
  }

  -- compares QoSRulesFromGUI with QoSRulesInDM
  -- rules that have same values for all params except name, index and order are considered as duplicates
  -- if duplicates found, sends error response to GUI and stops further exectuion
  local function checkDuplicateQoSRules(QoSRulesFromGUI)
    local excludedParams = {
      index = true,
      Order = true,
      Name = true,
    }
    local QoSRulesInDM = session:retrieve("QOSRules")
    for _, DMRule in ipairs(QoSRulesInDM) do
      local duplicate, checked = true, false
      if DMRule.paramindex ~= QoSRulesFromGUI.index then -- don't check the same rule for duplicate
        for _, param in ipairs(QoSParameters) do
          if QoSRulesFromGUI[param] and not excludedParams[param] then -- this param got changed by user
            checked = true
            if DMRule[param] ~= QoSRulesFromGUI[param] then
              duplicate = false
              break
            end
          end
        end
        if checked and duplicate then
          ngx.header.content_type = "application/json"
          ngx.print('{ "status":"error" }')
          ngx.exit(ngx.HTTP_OK)
        end
      end
    end
  end

  -- function validateQos is to validate the QoS values during a POST
  -- QoSRules table contain the QoS rules (That need to be edited or added)
  -- If valid, Returns QoSValues table containing all QoS values sent from GUI
  -- nil if any validation fails
  local function validateQos(QoSRules, QoSPorts, totalRules)
    local QosValues = {}
    local QoSValidMap = {}
    for row = 1, totalRules do
      -- Populate QosValues table with all QoS values sent from GUI
      for index, QosParam in ipairs(QoSParameters) do
        -- Only update the row if it has an index
        if QoSRules[row]["index"] and QoSRules[row]["index"] ~= "" then
          if not (validatePort(QoSPorts[row].SourcePort) and
                  validatePort(QoSPorts[row].SourcePortRangeMax) and
                  validatePort(QoSPorts[row].DestPort) and
                  validatePort(QoSPorts[row].DestPortRangeMax)) then
            return nil
          end
          if (QoSPorts[row].SourcePortRangeMax ~= "" and
              tonumber(QoSPorts[row].SourcePort) > tonumber(QoSPorts[row].SourcePortRangeMax)) or
             (QoSPorts[row].DestPortRangeMax ~= "" and
              tonumber(QoSPorts[row].DestPort) > tonumber(QoSPorts[row].DestPortRangeMax)) then
            return nil
          end
          if QoSRules[row][QosParam] and (QoSRules[row][QosParam] ~= "" or setEmptyParams[QosParam]) and QosParam ~= "index" then
            if QoSRules[row]["Rowtype"] == "l2classify" then
              QosValues[QosParam .. row .. "l2classify"] = QoSRules[row][QosParam]
            else
              QosValues[QosParam .. row] = QoSRules[row][QosParam]
            end
          end
        end
      end
      -- Populate QoSValidMap table with validation function for each QoS value sent from GUI
      for index, parameter in ipairs(QoSParameters) do
        if parameter ~= "Ruletype" then
          QoSValidMap[QoSParameters[index] .. row] = QoSValidations[parameter]
        end
      end
    end
    local validQoSValues = content_helper.validateObject(QosValues, QoSValidMap)
    if validQoSValues then
      return QosValues
    end
  end

  -- Check if request is POST
  if ngx.req.get_method() == "POST" then
    local postargs = ngx.req.get_post_args()
    local QoSRows = tonumber(postargs.rows)
    local QoSTable = json.decode(postargs.QoSTable)
    local QoSPorts = json.decode(postargs.QoSPorts)

    -- Assign keys to all tables inside QoSTable
    -- Don't assign keys inside QosTable for a QoS rule that need to be deleted
    for row = 1, QoSRows do

      -- Adding/editing/deleting depends on the value of index of a rule
      -- If index is new, a new rule of type rule need to be added
      -- If index has value of l2classify, a new rule of type l2classify need to be added
      -- If value of index is not empty, then index corresponding to that rule need to be edited
      -- If index contains values eg:del%d, then that rule need to be deleted

      local paramsIndex = 1
      local isDeletedRow =  tonumber(QoSTable[row][1]:match("del(%d*)"))
      local editIndex = tonumber(QoSTable[row][1]) -- If index is equal to instance, this rule need to be edited
      local ruleType = QoSTable[row][29] -- This element helps in determining type of QoS rule

      -- Check if the QoS rule in this row is to be deleted; if yes we delete it here itself without populating this rule in the QosTable
      if isDeletedRow then
        local path

         -- Before deletion check the type of QoS rule that need to be deleted
        if ruleType == "rule" then
          path = format("rpc.qos.classification.rule.%s.", isDeletedRow)
        else
          path = format("rpc.qos.classification.l2classify.%s.", isDeletedRow)
        end
        proxy.del(path)

      -- The below methods are used to populate QoSTable with key as parameter and value(value of the paramter) for a QoS rule

      -- Check if the newly added row is of type rule
      elseif QoSTable[row][1] == "new" and ruleType == "rule" then
        for index = 1, #QoSTable[row] do

          -- Dont assign key for Order as it is readonly
          if QoSParameters[index] ~= "Order" then
            if QoSParamsRuletable[QoSParameters[index]] then

              if (QoSTable[row][index] ~= "" or (QoSTable[row][index] == "" and emptyParams[QoSParameters[index]])) and index ~= 29 then
                QoSTable[row][QoSParamsRule[paramsIndex]] = QoSTable[row][index]
                paramsIndex = paramsIndex + 1
              end
            end
          end
        end

      -- Check if the newly added row is of type l2classify
      elseif ruleType == "l2classify" and QoSTable[row][1] == "l2classify" then
        for index = 1, #QoSParameters do
          if QoSParameters[paramsIndex] ~= "Order" then
            if QoSTable[row][index] ~= "" or (QoSTable[row][index] == "" and emptyParams[QoSParameters[index]]) then
              if index == 29 then
                QoSTable[row]["Rowtype"] = ruleType
              else
                QoSTable[row][QoSParameters[paramsIndex]] = QoSTable[row][index]
                paramsIndex = paramsIndex + 1
                QoSTable[row][index] = nil
              end
            end
          else
            paramsIndex = paramsIndex + 1
          end
        end

        -- Check if the row is to be edited from rule of type l2classify to classify
      elseif editIndex and ruleType == "l2Toclassify" then
        for index = 1, #QoSParameters do
          if QoSParameters[index] ~= "Order" then
            if QoSParamsRuletable[QoSParameters[index]] then
              if (QoSTable[row][index] ~= "" or (QoSTable[row][index] == "" and emptyParams[QoSParameters[index]])) and index ~= 29 then
                QoSTable[row][QoSParameters[index]] = QoSTable[row][index]
                QoSTable[row][index] = nil
              end
            end
          end
        end

      -- Check if the row is to be edited of type rule
      elseif editIndex and (ruleType == "rule") then
        for index = 1, #QoSParameters do
          if QoSParameters[index] ~= "Order" then
            if QoSParamsRuletable[QoSParameters[index]] then
              if (QoSTable[row][index] ~= "" or (QoSTable[row][index] == "" and emptyParams[QoSParameters[index]])) and index ~= 29 then
                QoSTable[row][QoSParameters[index]] = QoSTable[row][index]
                QoSTable[row][index] = nil
              end
            end
          end
        end

      -- Check if the row is to be edited of type l2classify
      elseif editIndex and ruleType == "l2classify" then
        for index = 1, #QoSParameters do
          if QoSParameters[paramsIndex] ~= "Order" then
            if QoSTable[row][index] ~= "" or (QoSTable[row][index] == "" and emptyParams[QoSParameters[index]]) then
              if index == 29 then
                QoSTable[row]["Rowtype"] = ruleType
              else
                QoSTable[row][QoSParameters[paramsIndex]] = QoSTable[row][index]
                QoSTable[row][index] = nil
              end
            end
          end
          paramsIndex = paramsIndex + 1
        end
      end
      for index = 1, 4 do
        QoSPorts[row][QoSPortParameters[index]] = QoSPorts[row][index]
        QoSPorts[row][index] = nil
      end
    end
    local QOSPath = {}
    local QoSStatus = {
      status    = postargs.QoSStatus,
      bandwidth = postargs.QoSBW,
    }

    -- validateQos function returns all QoS rules(Deleted rule is removed) if all fields of each QoS rule are valid

    -- Duplicate check
    -- for i, v in ipairs(QoSTable) do
    --   -- print(v)
    --   if v.index and (v.index == "new" or v.index:match("^%d+$")) then -- if the rule is added/modified, check duplicates
    --     print({["gonna check duplicate for"] = v})
    --     checkDuplicateQoSRules(v)
    --   end
    -- end

    local validQosValues = validateQos(QoSTable, QoSPorts, QoSRows)
    local isValid  = true
    local isValidQos  = true

    -- If all rules are valid, proceed with add/edit/delete
    if validQosValues then
      for row = 1, #QoSTable do

        local QoSRulePaths = {}
        local QoSType = QoSTable[row][29]
        local indexValue = QoSTable[row]["index"]

        -- If index exists, proceed with add/edit
        if indexValue then

          -- Add a new QoS rule if index has value new or l2classify
          if indexValue == "new" or indexValue == "l2classify" then

            -- Check if the rule is of type rule to be added
            if QoSType == "rule" then
              for _, parameter in ipairs(QoSParamsRule) do
                QoSRulePaths[parameter .. row] = parameter
              end
              content_helper.addNewObject("rpc.qos.classification.rule.", validQosValues, QoSRulePaths)

            -- Check if the rule is l2classify to be added
            elseif indexValue == "l2classify" then
              for _, parameter in ipairs(QoSParameters) do
                if parameter ~= "Rowtype" then
                  QoSRulePaths[parameter .. row .. "l2classify"] = parameter
                end
              end
              local ruleIndex = content_helper.addNewObject("rpc.qos.classification.l2classify.", validQosValues, QoSRulePaths)

              if validQosValues[format("Protocol%sl2classify", row)] and ethProtomap[validQosValues[format("EthernetProtocol%sl2classify", row)]] == "IP" then

                -- Explicitly we set the value sent from GUI for Protocol otherwise, default value is set (Applicable for both rule and l2classify)
                proxy.set({[format("rpc.qos.classification.l2classify.%s.Protocol", ruleIndex)] = validQosValues[format("Protocol%sl2classify", row)]})
              else

                -- Explicitly we set the value sent from GUI for Ethernet Protocol otherwise, default value is set (Applicable for both rule and l2classify)
                proxy.set({[format("rpc.qos.classification.l2classify.%s.EthernetProtocol", ruleIndex)] = validQosValues[format("EthernetProtocol%sl2classify", row)]})
              end
              proxy.set({[format("rpc.qos.classification.l2classify.%s.ProtocolExclude", ruleIndex)] = validQosValues[format("ProtocolExclude%sl2classify", row)]})
            end
          else

            -- Editing a QoS rule section starts here
            -- Edit a QoS rule if index is not empty
            -- If index not empty, a QoS rule of type rule/l2classify has to be edited
            local index = tonumber(indexValue)
            if index then

              -- Check if the rule was edited by changing from l2classify to classify
              if QoSType == "l2Toclassify" then
                  for _, parameter in ipairs(QoSParamsRule) do
                    QoSRulePaths[parameter .. row] = parameter
                  end
                  content_helper.addNewObject("rpc.qos.classification.rule.", validQosValues, QoSRulePaths)
                  proxy.del(format("rpc.qos.classification.l2classify.%s.", index))
              else

                -- Check if the rule to be edited is of type rule
                if QoSType == "rule" then

                  -- Populate QoSRulePaths table with all QoS Parameters paths
                  for _, parameter in ipairs(QoSParamsRule) do
                    QoSRulePaths[parameter .. row] = format("rpc.qos.classification.rule.%s.%s", index, parameter)
                  end
                else

                  -- Editing l2classify rule
                  for _, parameter in ipairs(QoSParameters) do
                    if parameter ~= "Rowtype" then
                      QoSRulePaths[parameter .. row .. "l2classify"] = format("rpc.qos.classification.l2classify.%s.%s", index, parameter)
                     end
                  end
                end
                isValidQos = content_helper.setObject(validQosValues, QoSRulePaths)
                if QoSType == "rule" and validQosValues[format("DSCPMark%s", row)] then
                  proxy.set({[format("rpc.qos.classification.rule.%s.DSCPMark", index)] = validQosValues[format("DSCPMark%s", row)]})
                end
                if not isValidQos then
                  break
                end
              end
            end
          end
        end
      end

      -- Validating and setting necessary QoS parameters(Enable and bandwidth)
      QOSPath["status"] = "rpc.qos.Enable"
      QOSPath["bandwidth"] = "rpc.wanethernetinterfaceconfig.ShapingRate"
      isValid =  content_helper.validateObject(QoSStatus, QoSValidations) and content_helper.setObject(QoSStatus, QOSPath)
    end
    ngx.header.content_type = "application/json"
    if validQosValues and isValidQos and isValid then
      proxy.apply()
      ngx.print('{ "status":"success" }')
    else
      ngx.print('{ "status":"error" }')
    end
    ngx.exit(ngx.HTTP_OK)
  end
  --End of POST

 -- Catergorizing each QoS rule based on type
  local QOSPathRule = "rpc.qos.classification.rule."
  local QOSPathL2classify = "rpc.qos.classification.l2classify."

  local qosParams = {
    status    = "rpc.qos.Enable",
    bandwidth = "rpc.wanethernetinterfaceconfig.ShapingRate",
    QueueList = "rpc.qos.QueueList",
  }
  content_helper.getExactContent(qosParams)

  for queue in gmatch(qosParams.QueueList, "[^,]+") do
    queueMap[queue] = true
    queueList[#queueList+1] = { queue }
  end

  QoSValidations.Queue = post_helper.getValidateInEnumSelect(queueList)
local QOSRules   = content_helper.convertResultToObject(QOSPathRule, proxy.get(QOSPathRule), function(a,b)
    return tonumber(a.paramindex) < tonumber(b.paramindex)
  end)
  local l2Classify =  content_helper.convertResultToObject(QOSPathL2classify, proxy.get(QOSPathL2classify), function(a,b)
    return tonumber(a.paramindex) < tonumber(b.paramindex)
  end)
-- Merging all QoS rule into one table(QOSRules)
  for _,v in ipairs(l2Classify) do
    table.insert(QOSRules, v)
  end

  -- Store all QoSRules in session to validate them during POST
  -- session:store("QOSRules", QOSRules)

  ngx.print('\
\
<div class="row no-margin-right">\
  <div class="col-xs-12 col-md-8 col-sm-8">\
    <h1>');  ngx.print(T"Quality of Service"); ngx.print('</h1> </div>\
  </div>\
  <div class="h3-content vdf-table">\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Quality of Service"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <div class="button ');  if qosParams.status == "1" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('" id="qos-btn-status"></div>\
      </div>\
    </div>\
    <div class="vdf-row" id="qos-div-bw" style="');  if qosParams.status == "1" then  ngx.print('display:table-row');  else  ngx.print('display:none');  end  ngx.print('">\
      <div class="left">\
        <span>');  ngx.print(T"FTTH Upstream Bandwidth in kbps"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <input type="text" id="qos-txt-bw"value=\'');  if qosParams.bandwidth == "-1" then  else  ngx.print(qosParams.bandwidth); end  ngx.print('\'>\
      </div>\
    </div>\
  </div>\
  <div class="qos" id="qos-table-details" style="');  if qosParams.status == "1" then  ngx.print('display:block');  else  ngx.print('display:none');  end  ngx.print('">\
    <h3><span>');  ngx.print(T"Quality of Service Rules"); ngx.print('</span></h3>\
    <div class="h3-content" id="qos-table">\
      <div class="desktop table policy-routing with-on-off">\
        <div class="table-row table-row-head">\
          <div class="table-col">\
            <span>');  ngx.print(T"Name"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Order"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Match criteria"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Action"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
        </div>\
        <div class="table-row no-rule italic" ');  if #QOSRules ~= 0 then  ngx.print(' style="display:none" ');  end  ngx.print('>\
          <div class="table-col ">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            ');  ngx.print(T"No Rule Defined"); ngx.print('\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
        </div>\
        ');  
          local row = 0
          for _, v in pairs(QOSRules) do
            if not (match(v.SourceIP, "[+:]") or match(v.DestIP, "[+:]")) then
              row = row + 1
          ngx.print('\
            <div class="table-row qos-rule ');  if v.Enable == "0" then  ngx.print(' op40  ');  end   ngx.print('">\
              <input type="hidden" name="index" class="index" value="');  ngx.print(v.paramindex); ngx.print('">\
              <input type="hidden" name="Order" class="Order" value="');  ngx.print(row); ngx.print('">\
              <input type="hidden" name="DSCPMark" class="DSCPMark" value="');  ngx.print(v.DSCPMark); ngx.print('">\
              <input type="hidden" name="Interface" class="Interface" value="');  ngx.print(v.Interface); ngx.print('">\
              <input type="hidden" name="EthernetProtocol" class="EthernetProtocol" value="');  ngx.print(v.EthernetProtocol); ngx.print('">\
              <input type="hidden" name="ProtocolExclude" class="ProtocolExclude" value="');  ngx.print(v.ProtocolExclude); ngx.print('">\
              <input type="hidden" name="Protocol" class="Protocol" value="');  ngx.print(v.Protocol); ngx.print('">\
              <input type="hidden" name="SourceIPExclude" class="SourceIPExclude" value="');  ngx.print(v.SourceIPExclude); ngx.print('">\
              <input type="hidden" name="SourceIP" class="SourceIP" value="');  ngx.print(v.SourceIP); ngx.print('">\
              <input type="hidden" name="SourceMask" class="SourceMask" value="');  ngx.print(v.SourceMask); ngx.print('">\
              <input type="hidden" name="DestIPExclude" class="DestIPExclude" value="');  ngx.print(v.DestIPExclude); ngx.print('">\
              <input type="hidden" name="DestIP" class="DestIP" value="');  ngx.print(v.DestIP); ngx.print('">\
              <input type="hidden" name="DestMask" class="DestMask" value="');  ngx.print(v.DestMask); ngx.print('">\
              <input type="hidden" name="SourcePort1" class="SourcePort1" value="');  ngx.print(v.SourcePort); ngx.print('">\
              <input type="hidden" name="SourcePort2" class="SourcePort2" value="');  ngx.print(v.SourcePortRangeMax); ngx.print('">\
              <input type="hidden" name="DestPort1" class="DestPort1" value="');  ngx.print(v.DestPort); ngx.print('">\
              <input type="hidden" name="DestPort2" class="DestPort2" value="');  ngx.print(v.DestPortRangeMax); ngx.print('">\
              <input type="hidden" name="SourceMACAddress" class="SourceMACAddress" value="');  ngx.print(v.SourceMACAddress); ngx.print('">\
              <input type="hidden" name="SourceMACMask" class="SourceMACMask" value="');  ngx.print(v.SourceMACMask); ngx.print('">\
              <input type="hidden" name="SourceMACExclude" class="SourceMACExclude" value="');  ngx.print(v.SourceMACExclude); ngx.print('">\
              <input type="hidden" name="DestMACAddress" class="DestMACAddress" value="');  ngx.print(v.DestMACAddress); ngx.print('">\
              <input type="hidden" name="DestMACMask" class="DestMACMask" value="');  ngx.print(v.DestMACMask); ngx.print('">\
              <input type="hidden" name="DestMACExclude" class="DestMACExclude" value="');  ngx.print(v.DestMACExclude); ngx.print('">\
              <input type="hidden" name="DSCPCheck" class="DSCPCheck" value="');  ngx.print(v.DSCPCheck); ngx.print('">\
              <input type="hidden" name="EthernetPriorityCheck" class="EthernetPriorityCheck" value="');  ngx.print(v.EthernetPriorityCheck); ngx.print('">\
              <input type="hidden" name="Name" class="Name" value="');  ngx.print(v.Name); ngx.print('">\
              <input type="hidden" name="Queue" class="Queue" value="');  ngx.print(queueMap[v.Queue] and v.Queue or "LOW_PRI"); ngx.print('">\
              <input type="hidden" name="Enable" class="Enable" value="');  ngx.print(v.Enable); ngx.print('">\
              <input type="hidden" name="RuleType" class="RuleType" value="');  ngx.print(v.RuleType); ngx.print('">\
              <div class="table-col pr_Name">');  ngx.print(v.Name); ngx.print('</div>\
              <div class="table-col RowNumber">');  ngx.print(row); ngx.print('</div>\
              <div class="table-col">\
              ');  
                if v["Interface"] ~= "" then
                  ngx.print(format("<span class='pr_Interface show'>%s: %s</span>", T"Interface", v["Interface"]))
                else
                  ngx.print(format("<span class='pr_Interface hide'>%s: %s</span>", T"Interface", v["Interface"]))
                end
                if ((v["Protocol"] ~= "" and v.ProtocolExclude == "0") and (v.RuleType == "rule" or (v.RuleType == "l2classify" and ethProtomap[v["EthernetProtocol"]] == "IP"))) then
                  ngx.print(format("<span class='pr_Protocol show'>%s: %s</span>", T"IP Protocol", protocolMap[v["Protocol"]]))
                else
                  ngx.print(format("<span class='pr_Protocol hide'>%s: %s</span>", T"IP Protocol", protocolMap[v["Protocol"]]))
                end
                if v.RuleType == "l2classify" then
                  if v["EthernetProtocol"] ~= "" then
                    ngx.print(format("<span class='pr_EthernetProtocol show'>%s: %s</span>", T"Ethernet Protocol", ethProtomap[v["EthernetProtocol"]]))
                  else
                    ngx.print(format("<span class='pr_EthernetProtocol hide'>%s: %s</span>", T"Ethernet Protocol", ethProtomap[v["EthernetProtocol"]]))
                  end
                end
                if v["SourceIP"] ~= "" and v.SourceIPExclude == "0" then
                  ngx.print(format("<span class='pr_SourceIP show'>%s: %s</span>", T"Source IP", v["SourceIP"]))
                else
                  ngx.print(format("<span class='pr_SourceIP hide'>%s: %s</span>", T"Source IP", v["SourceIP"]))
                end
                if (v.RuleType == "rule" or  ethProtomap[v["EthernetProtocol"]] == "IP") and v.SourceIPExclude == "0" then
                  ngx.print(format("<span class='pr_SourceMask show'>%s: %s</span>", T"Prefix Length", v["SourceMask"]))
                else
                  ngx.print(format("<span class='pr_SourceMask hide'>%s: %s</span>", T"Prefix Length", v["SourceMask"]))
                end
                if v["DestIP"] ~= "" and v.DestIPExclude == "0" then
                  ngx.print(format("<span class='pr_DestIP show'>%s: %s</span>", T"Destination IP", v["DestIP"]))
                else
                  ngx.print(format("<span class='pr_DestIP hide'>%s: %s</span>", T"Destination IP", v["DestIP"]))
                end
                if (v.RuleType == "rule" or  ethProtomap[v["EthernetProtocol"]] == "IP") and v.DestIPExclude == "0" then
                  ngx.print(format("<span class='pr_DestMask show'>%s: %s</span>", T"Subnet Mask", v["DestMask"]))
                else
                  ngx.print(format("<span class='pr_DestMask hide'>%s: %s</span>", T"Subnet Mask", v["DestMask"]))
                end
                if (v["SourcePort"] ~= "" and v.RuleType ~= "l2classify") or (v["SourcePort"] ~= "" and  ethProtomap[v["EthernetProtocol"]] == "IP") then
                  if v["SourcePortRangeMax"] == "" or v["SourcePortRangeMax"] == "" then
                    v["SourcePortRangeMax"] = ""
                  else
                    v["SourcePortRangeMax"] = "-" .. v["SourcePortRangeMax"]
                  end
                  ngx.print(format("<span class='pr_SourcePort show'>%s: %s%s</span>", T"Source Port", v["SourcePort"], v["SourcePortRangeMax"]))
                else
                  ngx.print(format("<span class='pr_SourcePort hide'>%s: %s-%s</span>", T"Source Port", v["SourcePort"], v["SourcePortRangeMax"]))
                end
                if (v["DestPort"] ~= "" and v.RuleType ~= "l2classify") or (v["DestPort"] ~= "" and  ethProtomap[v["EthernetProtocol"]] == "IP") then
                  if v["DestPortRangeMax"] == "" or v["DestPortRangeMax"] == "" then
                    v["DestPortRangeMax"] = ""
                  else
                    v["DestPortRangeMax"] = "-" .. v["DestPortRangeMax"]
                  end
                  ngx.print(format("<span class='pr_DestPort show'>%s: %s%s</span>", T"Destination Port", v["DestPort"], v["DestPortRangeMax"]))
                else
                  ngx.print(format("<span class='pr_DestPort hide'>%s: %s-%s</span>", T"Destination Port", v["DestPort"], v["DestPortRangeMax"]))
                end
                if v.RuleType == "l2classify" then
                  if v["SourceMACAddress"] ~= "" and v.SourceMACExclude == "0" then
                    ngx.print(format("<span class='pr_SourceMACAddress show'>%s: %s</span>", T"Source MAC", v["SourceMACAddress"]))
                    ngx.print(format("<span class='pr_SourceMACMask show'>%s: %s</span>", T"Source MAC Mask", v["SourceMACMask"]))
                  else
                    ngx.print(format("<span class='pr_SourceMACAddress hide'>%s: %s</span>", T"Source MAC", v["SourceMACAddress"]))
                    ngx.print(format("<span class='pr_SourceMACMask hide'>%s: %s</span>", T"Source MAC Mask", v["SourceMACMask"]))
                  end
                  if v["DestMACAddress"] ~= "" and v.DestMACExclude == "0" then
                    ngx.print(format("<span class='pr_DestMACAddress show'>%s: %s</span>", T"Dest MAC", v["DestMACAddress"]))
                    ngx.print(format("<span class='pr_DestMACMask show'>%s: %s</span>", T"Dest MAC Mask", v["DestMACMask"]))
                  else
                    ngx.print(format("<span class='pr_DestMACAddress hide'>%s: %s</span>", T"Dest MAC", v["DestMACAddress"]))
                    ngx.print(format("<span class='pr_DestMACMask hide'>%s: %s</span>", T"Dest MAC Mask", v["DestMACMask"]))
                  end
                end
                if v["DSCPCheck"] ~= "0" then
                  ngx.print(format("<span class='pr_DSCPCheck'>%s: %s</span><br/>", T"DSCP Check", v["DSCPCheck"]))
                else
                  ngx.print(format("<span class='pr_DSCPCheck hide'>%s: %s</span>", T"DSCP Check", v["DSCPCheck"]))
                end
                ngx.print('\
              </div>\
              <div class="table-col">\
              ');  
                ngx.print(format("<span class='pr_Queue'>%s: %s</span>", T"Queue", v.Queue))
                if v.RuleType == "rule" then
                  if v["DSCPMark"] ~= "-1" then
                    ngx.print(format("<span class='pr_DSCPMark show'>%s: %s</span>", T"DSCP", v["DSCPMark"]))
                  else
                    ngx.print(format("<span class='pr-col text-overflow pr_DSCPMark hide'>%s: %s</span>", T"DSCP", v["DSCPMark"]))
                  end
                end
                if v["EthernetPriorityCheck"] and v["EthernetPriorityCheck"] ~= "" then
                  v["EthernetPriorityCheck"] = tonumber(v["EthernetPriorityCheck"])
                  if (v["EthernetPriorityCheck"] >=0 and v["EthernetPriorityCheck"]<=7) and (ethProtomap[v["EthernetProtocol"]] == "IP" or ethProtomap[v["EthernetProtocol"]] == "802.1Q" or v.RuleType == "rule") then
                    ngx.print(format("<span class='pr_EthernetPriorityCheck show'>%s: %s</span>", T"Mark 802.1D Priority", v["EthernetPriorityCheck"]))
                  else
                    ngx.print(format("<span class='pr_EthernetPriorityCheck hide'>%s: %s</span>", T"Mark 802.1D Priority", v["EthernetPriorityCheck"]))
                  end
                else
                  ngx.print(format("<span class='pr_EthernetPriorityCheck hide'>%s: %s</span>", T"Mark 802.1D Priority", v["EthernetPriorityCheck"]))
                end
                ngx.print('\
              </div>\
              <div class="table-col">\
                <input class="button editbutton button-edit mapping" id="qos-btn-edit');  ngx.print(row); ngx.print('" value="" type="button" data-toggle="modal" data-target="#editAccessControlModal" />\
              </div>\
              <div class="table-col">\
                <input class="button deletebutton button-delete mapping" id="qos-btn-delete');  ngx.print(row); ngx.print('" value="" type="button" />\
              </div>\
              <div class="table-col text-right">\
                <div style="pointer-events:all" class="button qosEnable ');  if v.Enable == "1" then   ngx.print(' button-on ');  else   ngx.print(' button-off ');  end  ngx.print('" id="qos-btn-enable');  ngx.print(row); ngx.print('" type="button"/>\
              </div>\
            </div>\
          ');  end  ngx.print('\
        ');  end  ngx.print('\
        <div class="table-row add-btn-wrapper" id="qos-row-last">\
          <div class="table-col ">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col tR">\
            <input class="button button-add mapping" id="qos-btn-add" value="" type="button" data-toggle="modal" data-target="#addQosModal">\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
');  
  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("apply-cancel.lp")
  ngx.print('\
\
<!-- Edit Popup Modal-->\
<div class="modal fade" id="editAccessControlModal" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Quality of Service"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none ">\
              <span>');  ngx.print(T"Name"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-info-editName" type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Order"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <span id="qos-info-editOrder"></span>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Match Criteria"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Interface"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-editInterface">\
                  ');  
                    ngx.print(format('<option value="">%s</option>', T"No Interface"))
                    for i = 1, #interfaces do
                      ngx.print(format('<option value="%s">%s</option>', interfaces[i][1], interfaces[i][1]))
                    end
                    ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Ethernet Protocol"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-editEthProto" onchange="changeFields(\'Editing\')">\
                  ');  
                    for _,v in ipairs(ethProto) do
                      ngx.print(format('<option value="%s">%s</option>', v[1], v[2]))
                    end
                    ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"IP Protocol"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-editIPProto">\
                  ');  
                    for _,v in ipairs(protocolList) do
                      ngx.print(format('<option value="%s">%s</option>', v[1], v[2]))
                    end
                    ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-protocol" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-protocol"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source IP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editSrcIP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Prefix Length"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editIPPrefixLength">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-srcIP" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-srcIP"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Destination IP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editDestIP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Subnet Mask"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editIPSubnetMask">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-destIP" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-destIP"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2 portHideOnEdit">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source Port"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-editSrcPort1"> -\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-editSrcPort2">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp2 portHideOnEdit">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Destination Port"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-editDestPort1"> -\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-editDestPort2">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source MAC"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editSrcMAC">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"MAC Mask"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editSrcMACMask">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-srcMAC" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-srcMAC"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Destination MAC"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editDestMAC">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"MAC Mask"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editDestMACMask">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-destMAC" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-destMAC"></label>\
            </div>\
          </div>\
          <!--TODO\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>IP Length</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5" type="text"> -\
              <input class="max5" type="text">\
            </div>\
          </div>\
          -->\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"DSCP Check"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editDSCPCheck">\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Action"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Queue"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-editQueue">\
                ');  
                  for i = 1, #queueList do
                    ngx.print(format('<option value="%s">%s</option>', queueList[i][1], queueList[i][1]))
                  end
                  ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin dscpHideOnEdit">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"DSCP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editDSCP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin editethp3">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Mark 802.1D Priority"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel editMarkPriority">\
                <select id="qos-sel-editMarkPriority">\
                  <option value="0">0</option>\
                  <option value="1">1</option>\
                  <option value="2">2</option>\
                  <option value="3">3</option>\
                  <option value="4">4</option>\
                  <option value="5">5</option>\
                  <option value="6">6</option>\
                  <option value="7">7</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" value="');  ngx.print(T"Apply"); ngx.print('" id="qos-btn-editSave" type="button" data-dismiss="modal" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="qos-btn-editCancel" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<!-- ADD Popup Modal-->\
<div class="modal fade" id="addQosModal" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Quality of Service"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none ">\
              <span>');  ngx.print(T"Name"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-info-addName" type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Order"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <span id="qos-info-addOrder"></span>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Match Criteria"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Interface"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-addInterface">\
                  ');  
                    ngx.print(format('<option value="">%s</option>', T"No Interface"))
                    for i = 1, #interfaces do
                      ngx.print(format('<option value="%s">%s</option>', interfaces[i][1], interfaces[i][1]))
                    end
                    ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Ethernet Protocol"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-addEthProto" onchange ="changeFields(\'Adding\')">\
                  ');  
                    for  _,v in ipairs(ethProto) do
                      ngx.print(format('<option value="%s">%s</option>', v[1], v[2]))
                    end
                    ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"IP Protocol"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-addIPProto">\
                  ');  
                    for _,v in ipairs(protocolList) do
                      ngx.print(format('<option value="%s">%s</option>', v[1], v[2]))
                    end
                    ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-add-protocol" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-add-protocol"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source IP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addSrcIP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Prefix Length"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addIPPrefixLength">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-add-srcIP" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-add-srcIP"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Destination IP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addDestIP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Subnet Mask"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addIPSubnetMask">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-add-destIP" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-add-destIP"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2 portHideOnAdd">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source Port"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-addSrcPort1"> -\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-addSrcPort2">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp2 portHideOnAdd">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Destination Port"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-addDestPort1"> -\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-addDestPort2">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source MAC"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addSrcMAC">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"MAC Mask"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addSrcMACMask">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-add-srcMAC" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-add-srcMAC"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Destination MAC"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addDestMAC">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"MAC Mask"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addDestMACMask">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-add-destMAC" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-add-destMAC"></label>\
            </div>\
          </div>\
          <!--TODO\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>IP Length</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5" type="text"> -\
              <input class="max5" type="text">\
            </div>\
          </div>\
          -->\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"DSCP Check"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addDSCPCheck">\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Action"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Queue"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="qos-sel-addQueue">\
                ');  
                for i = 1, #queueList do
                  ngx.print(format('<option value="%s">%s</option>', queueList[i][1], queueList[i][1]))
                end
                  ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin dscpHideOnAdd">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"DSCP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-addDSCP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin ethp3">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Mark 802.1D Priority"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel addMarkPriority">\
                <select id="qos-sel-addMarkPriority">\
                  <option value="0">0</option>\
                  <option value="1">1</option>\
                  <option value="2">2</option>\
                  <option value="3">3</option>\
                  <option value="4">4</option>\
                  <option value="5">5</option>\
                  <option value="6">6</option>\
                  <option value="7">7</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" value="');  ngx.print(T"Apply"); ngx.print('" id="qos-btn-addSave" type="button" data-dismiss="modal" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="qos-btn-addCancel" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
  var reservedValues = {\
    "');  ngx.print(reservedValues["gwIP"]); ngx.print('" :  true,\
    "');  ngx.print(reservedValues["bcast"]); ngx.print('" : true,\
    "');  ngx.print(reservedValues["specialBcast"]); ngx.print('" : true,\
    ');  if next(qtnIP) then   ngx.print('\
    "');  ngx.print(qtnIP[1].ip_address); ngx.print('" : true,\
    ');  end  ngx.print('\
  }\
  var qtnMac = "');  ngx.print(lower(reservedValues["qtnMac"])); ngx.print('"\
  var numberOfRules = "');  ngx.print(#QOSRules); ngx.print('"\
</script>\
<script src="js/global-min.js"></script>\
<script src="js/settings/qos.js"></script>\
\
'); 