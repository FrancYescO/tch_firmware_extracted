--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')


  local ngx = ngx
  local content_helper = require("web.content_helper")
  local post_helper = require("web.post_helper")
  local proxy = require("datamodel")
  local json = require("dkjson")
  local bit = require("bit")
  local vdf_helper = require("vodafone_helper")
  local validateNetmask = vdf_helper.validateNetmask
  local pairs, ipairs, tonumber = pairs, ipairs, tonumber
  local untaint_mt = require("web.taint").untaint_mt

  local string = string
  local format, match, gmatch = string.format, string.match, string.gmatch
  local CSRFtoken = ngx.ctx.session:getCSRFtoken()

  local interfacesList = proxy.getPN("uci.network.interface.", true)

  local interfaces = {}

  for _, v in pairs(interfacesList) do
    interfaces[#interfaces+1] = {match(v.path, "@(.+)%.")}
  end

  local protocolList = {
    { "1",   "ICMP"     },
    { "6",   "TCP"      },
    { "17",  "UDP"      },
    { "50",  "ESP"      },
    { "51",  "AH"       },
    { "132", "SCTP"     },
    { "136", "UDPLite"  },
    { "-1",  T"All "    },
  }

  local protocolMap = setmetatable({
    ["1"]   = "ICMP",
    ["6"]   = "TCP",
    ["17"]  = "UDP",
    ["50"]  = "ESP",
    ["51"]  = "AH",
    ["132"] = "SCTP",
    ["136"] = "UDPLite",
    ["-1"]  = T"All"
  }, untaint_mt)

  local queueMap = setmetatable({}, untaint_mt)

  local queueList = setmetatable({}, untaint_mt)

  local ethProto = setmetatable({
    { "IP" },
    { "802.1Q" },
    { "PPPoE" },
    { "IPv6" },
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

  local validateEthernetPriorityCheck = post_helper.getValidateNumberInRange(0, 7)
  local validateUpstreamBandwidth = post_helper.getValidateNumberInRange(0, 2147483647)
  local validateName = post_helper.getValidateStringLengthInRange(1, 63)

  local QoSParameters  = {
    "index",
    "Order",
    "DSCPMark",
    "Interface",
    "EthernetProtocol",
    "ProtocolExclude",
    "Protocol",
    "SourceIPExclude",
    "SourceIP",
    "SourceMask",
    "DestIPExclude",
    "DestIP",
    "DestMask",
    "SourcePort",
    "SourcePortRangeMax",
    "DestPort",
    "DestPortRangeMax",
    "SourceMACAddress",
    "SourceMACMask",
    "SourceMACExclude",
    "DestMACAddress",
    "DestMACMask",
    "DestMACExclude",
    "DSCPCheck",
    "EthernetPriorityCheck",
    "Name",
    "Queue",
    "Enable",
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
    EthernetProto         = post_helper.getOptionalValidation(post_helper.getValidateInEnumSelect(ethProto)),
    Protocol              = post_helper.getValidateInEnumSelect(protocolList),
    SourceIP              = post_helper.getOptionalValidation(post_helper.validateStringIsIP),
    SourceMask            = validateNetmask,
    DestIP                = post_helper.getOptionalValidation(post_helper.validateStringIsIP),
    SourceMACAddress      = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    SourceMACMask         = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    SourceMACExclude      = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    DestMACAddress        = post_helper.getOptionalValidation(post_helper.validateStringIsMAC),
    DestMask              = validateNetmask,
    EthernetPriorityCheck = validateEthernetPriorityCheck,
    status                = post_helper.validateBoolean,
    ProtocolExclude       = post_helper.validateBoolean,
    SourceIPExclude       = post_helper.validateBoolean,
    DestIPExclude         = post_helper.validateBoolean,
    SourceMACExclude      = post_helper.validateBoolean,
    DestMACExclude        = post_helper.validateBoolean,
    bandwidth             = validateUpstreamBandwidth,
    Enable                = validateBoolean,
  }

  -- If valid, Returns QoSValues table containing all QoS values sent from GUI
  -- nil if any validation fails
  local function validateQos(QoSRules, QoSPorts, totalRules)
    local QosValues = {}
    local QoSValidMap = {}
    for row = 1, totalRules do
      -- Populate QosValues table with all QoS values sent from GUI
      for index, QosParam in ipairs(QoSParameters) do
        -- Only update the row if it has an index
        if QoSRules[row]["index"] ~= "" then
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
          if QoSRules[row][QosParam] and QosParam ~= "index" then
            QosValues[QosParam .. row] = QoSRules[row][QosParam]
          end
        end
      end
      -- Populate QoSValidMap table with validation function for each QoS value sent from GUI
      for index, parameter in ipairs(QoSParameters) do
        QoSValidMap[QoSParameters[index] .. row] = QoSValidations[parameter]
      end
    end
    local validQoS, msg = content_helper.validateObject(QosValues, QoSValidMap)
    if validQoS then
      return QosValues
    end
  end

  if ngx.req.get_method() == "POST" then
    local postargs = ngx.req.get_post_args()
    local QoSRows = tonumber(postargs.rows)
    local QoSTable = json.decode(postargs.QoSTable)
    local QoSPorts = json.decode(postargs.QoSPorts)

    -- Assign keys to all tables inside QoSTable
    for row = 1, QoSRows do
      for index = 1, #QoSParameters do
        QoSTable[row][QoSParameters[index]] = QoSTable[row][index]
        QoSTable[row][index] = nil
      end
      for index = 1, 4 do
        QoSPorts[row][QoSPortParameters[index]] = QoSPorts[row][index]
        QoSPorts[row][index] = nil
      end
    end

    local QoSPaths = {}
    local QoSStatus = {
      status    = postargs.QoSStatus,
      bandwidth = postargs.QoSBW
    }
    local validQos = validateQos(QoSTable, QoSPorts, QoSRows)

    if validQos then
      for row = 1, #QoSTable do
        local index = tonumber(QoSTable[row].index)
        if index then
          -- Populate QoSPaths table with all QoS Parameters paths
          for _, parameter in ipairs(QoSParameters) do
            QoSPaths[parameter .. row] = format("rpc.qos.classification.%s.%s", index, parameter )
          end
        end
      end
      QoSPaths["status"] = "rpc.qos.Enable"
      validQos["status"] = postargs.QoSStatus
      QoSPaths["bandwidth"] = "rpc.wanethernetinterfaceconfig.ShapingRate"
      validQos["bandwidth"] = postargs.QoSBW
      validQos =  content_helper.validateObject(QoSStatus, QoSValidations) and content_helper.setObject(validQos, QoSPaths)
    end
    ngx.header.content_type = "application/json"
    if validQos then
      proxy.apply()
      ngx.print('{ "status":"success" }')
    else
      ngx.print('{ "status":"error" }')
    end
    ngx.exit(ngx.HTTP_OK)
  end

  local QOSPath = "rpc.qos.classification."
  local QOSList = content_helper.convertResultToObject(QOSPath, proxy.get(QOSPath), function(a,b)
    return tonumber(a.paramindex) < tonumber(b.paramindex)
  end)

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

  QoSValidations.Queue = post_helper.getValidateInEnumSelect(queueList),

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
        <input type="text" id="qos-txt-bw" value="');  ngx.print(qosParams.bandwidth); ngx.print('">\
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
          <div class="table-row no-rule italic" style="display:none">\
              <div class="table-col ">\
                  &nbsp;\
              </div>\
              <div class="table-col">\
                  &nbsp;\
              </div>\
              <div class="table-col">\
                  No Rule Defined\
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
       ');  for i, v in pairs(QOSList) do  ngx.print('\
          <div class="table-row ');  if v.Enable == "0" then  ngx.print(' op40  ');  end   ngx.print('">\
            <input type="hidden" name="index" class="index" value="');  ngx.print(v.paramindex); ngx.print('">\
            <input type="hidden" name="Order" class="Order" value="');  ngx.print(v.Order); ngx.print('">\
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
            <input type="hidden" name="Queue" class="Queue" value="');  ngx.print(queueMap[v.Queue] and v.Queue or "HIGH_PRI"); ngx.print('">\
            <input type="hidden" name="Enable" class="Enable" value="');  ngx.print(v.Enable); ngx.print('">\
            <input type="hidden" class="RuleType" value="');  ngx.print(v.RuleType); ngx.print('">\
            <div class="table-col pr_Name">');  ngx.print(v.Name); ngx.print('</div>\
            <div class="table-col">');  ngx.print(v.Order); ngx.print('</div>\
            <div class="table-col">\
            ');  
              if v["Interface"] ~= "" then
                ngx.print(format("<span class='pr_Interface show'>%s: %s</span>", T"Interface", v["Interface"]))
              else
                ngx.print(format("<span class='pr_Interface hide'>%s: %s</span>", T"Interface", v["Interface"]))
              end
              if v["Protocol"] ~= "" then
                ngx.print(format("<span class='pr_Protocol show'>%s: %s</span>", T"IP Protocol", protocolMap[v["Protocol"]]))
              else
                ngx.print(format("<span class='pr_Protocol hide'>%s: %s</span>", T"IP Protocol", protocolMap[v["Protocol"]]))
              end
              if v.RuleType == "l2classify" then
                if v["EthernetProtocol"] ~= "" then
                  ngx.print(format("<span class='pr_EthernetProtocol show'>%s: %s</span>", T"Ethernet Protocol", v["EthernetProtocol"]))
                else
                  ngx.print(format("<span class='pr_EthernetProtocol hide'>%s: %s</span>", T"Ethernet Protocol", v["EthernetProtocol"]))
                end
              end
              if v["SourceIP"] ~= "" and v.SourceIPExclude == "0" then
                ngx.print(format("<span class='pr_SourceIP show'>%s: %s</span>", T"Source IP", v["SourceIP"]))
                ngx.print(format("<span class='pr_SourceMask show'>%s: %s</span>", T"Prefix Length", v["SourceMask"]))
              else
                ngx.print(format("<span class='pr_SourceIP hide'>%s: %s</span>", T"Source IP", v["SourceIP"]))
                ngx.print(format("<span class='pr_SourceMask hide'>%s: %s</span>", T"Prefix Length", v["SourceMask"]))
              end
              if v["DestIP"] ~= "" and v.DestIPExclude == "0" then
                ngx.print(format("<span class='pr_DestIP show'>%s: %s</span>", T"Destination IP", v["DestIP"]))
                ngx.print(format("<span class='pr_DestMask show'>%s: %s</span>", T"Subnet Mask", v["DestMask"]))
              else
                ngx.print(format("<span class='pr_DestIP hide'>%s: %s</span>", T"Destination IP", v["DestIP"]))
                ngx.print(format("<span class='pr_DestMask hide'>%s: %s</span>", T"Subnet Mask", v["DestMask"]))
              end
              if v["SourcePort"] ~= "" then
                if v["SourcePortRangeMax"] == "" or v["SourcePortRangeMax"] == "" then
                  v["SourcePortRangeMax"] = ""
                else
                  v["SourcePortRangeMax"] = "-" .. v["SourcePortRangeMax"]
                end
                ngx.print(format("<span class='pr_SourcePort show'>%s: %s%s</span>", T"Source Port", v["SourcePort"], v["SourcePortRangeMax"]))
              else
                ngx.print(format("<span class='pr_SourcePort hide'>%s: %s-%s</span>", T"Source Port", v["SourcePort"], v["SourcePortRangeMax"]))
              end
              if v["DestPort"] ~= "" then
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
              if v["DSCPMark"] ~= "-1" then
                ngx.print(format("<span class='pr_DSCPMark show'>%s: %s</span>", T"DSCP", v["DSCPMark"]))
              else
                ngx.print(format("<span class='pr-col text-overflow pr_DSCPMark hide'>%s: %s</span>", T"DSCP", v["DSCPMark"]))
              end
              if v["EthernetPriorityCheck"] ~= "0" then
                ngx.print(format("<span class='pr_EthernetPriorityCheck show'>%s: %s</span>", T"Mark 802.1D Priority", v["EthernetPriorityCheck"]))
              else
                ngx.print(format("<span class='pr_EthernetPriorityCheck hide'>%s: %s</span>", T"Mark 802.1D Priority", v["EthernetPriorityCheck"]))
              end
              ngx.print('\
            </div>\
            <div class="table-col">\
                <input class="button button-edit mapping" id="qos-btn-edit');  ngx.print(i); ngx.print('" value="" type="button" data-toggle="modal" data-target="#editAccessControlModal" />\
            </div>\
            <div class="table-col">\
                <div style="pointer-events:all" class="button qosEnable ');  if v.Enable == "1" then   ngx.print(' button-on ');  else   ngx.print(' button-off ');  end  ngx.print('" id="qos-btn-enable');  ngx.print(i); ngx.print('" type="button"/>\
            </div>\
          </div>\
        ');  end  ngx.print('\
      </div>\
    </div>\
</div>\
\
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
                <select id="qos-sel-editEthProto">\
                  ');  
                    ngx.print(format('<option value="">%s</option>', T"No Protocol"))
                    for i = 1, #ethProto do
                      ngx.print(format('<option value="%s">%s</option>', ethProto[i][1], ethProto[i][1]))
                    end
                    ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
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
          <div class="form-group padding-top-bottom-20 no-margin l2classify">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-protocol" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-protocol"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source IP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editSrcIP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Prefix Length"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editIPPrefixLength">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-srcIP" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-srcIP"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Destination IP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editDestIP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Subnet Mask"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editIPSubnetMask">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Exclude"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input id="qos-exclude-destIP" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="qos-exclude-destIP"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"Source Port"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-editSrcPort1"> -\
              <input class="max5 num-only" maxlength="5" type="text" id="qos-txt-editSrcPort2">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
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
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"DSCP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text" id="qos-txt-editDSCP">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
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
<!-- ADD Popup Modal--><!-- TODO\
<div class="modal fade" id="addAccessControlModal" role="dialog" data-backdrop="static">\
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
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Order</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
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
              <span>Interface</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="devicesSelectEdit">\
                  <option>All</option>\
                  <option>LAN</option>\
                  <option>LAN1</option>\
                  <option>LAN2</option>\
                  <option>LAN3</option>\
                  <option>Local</option>\
                  <option>WLAN</option>\
                  <option>WAN1</option>\
                  <option>WAN2</option>\
                  <option>WAN3</option>\
                  <option>WAN4</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Ethernet Protocol</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="devicesSelectEdit">\
                  <option value="">IP</option>\
                  <option value="">802.1Q</option>\
                  <option value="">PPPoE</option>\
                  <option value="">IPv6</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>IP Protocol</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="devicesSelectEdit">\
                  <option>All</option>\
                  <option>TCP</option>\
                  <option>UDP</option>\
                  <option>ICMPv6</option>\
                  <option>IGMPv6</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>Exclude</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-6 modal-padding-lrt-none">\
              <input id="exclude" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="exclude"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Source IP</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Prefix Length</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>Exclude</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-6 modal-padding-lrt-none">\
              <input id="exclude2" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="exclude2"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Destination IP</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Subnet Mask</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>Exclude</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-6 modal-padding-lrt-none">\
              <input id="exclude3" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="exclude3"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Source Port</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5" type="text"> -\
              <input class="max5" type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Destination Port</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5" type="text"> -\
              <input class="max5" type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Source MAC</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>MAC Mask</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>Exclude</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-6 modal-padding-lrt-none">\
              <input id="exclude4" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="exclude4"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Destination MAC</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>MAC Mask</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-6 modal-padding-lrt-none">\
              <span>Exclude</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-6 modal-padding-lrt-none">\
              <input id="exclude5" class="checkbox checkbox-checked show-hide-guest-pw" data-id="1" checked="checked" type="checkbox">\
              <label for="exclude5"></label>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>IP Length</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input class="max5" type="text"> -\
              <input class="max5" type="text">\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>DSCP Check</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <input type="text">\
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
                <select id="devicesSelectEdit">\
                  <option>0</option>\
                  <option>1</option>\
                  <option>2</option>\
                  <option>3</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>');  ngx.print(T"DSCP"); ngx.print('</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <span></span>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 col-xs-12 modal-padding-lrt-none">\
              <span>Mark 802.1D Priority</span>\
            </div>\
            <div class="col-md-7 col-sm-7 col-xs-12 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="devicesSelectEdit">\
                  <option>0</option>\
                  <option>1</option>\
                  <option>2</option>\
                  <option>3</option>\
                  <option>4</option>\
                  <option>5</option>\
                  <option>6</option>\
                  <option>7</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" value="Apply"  type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="Cancel" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
-->\
<script src="js/global.js"></script>\
<script src="js/qos.js"></script>\
'); 