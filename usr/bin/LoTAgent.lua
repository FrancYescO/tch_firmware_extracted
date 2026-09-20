#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2017 Technicolor                                           **
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
local logger = require("transformer.logger")
local log = logger.new("LoTAgent", 2)

local ubus = require("ubus")
local uciCursor = require("uci").cursor(nil, "/var/state")
local json = require("dkjson")
local mime = require("mime")
local floor, sub, format, upper, char = math.floor, string.sub, string.format, string.upper, string.char
local execute, time, date, difftime = os.execute, os.time, os.date, os.difftime
local uloop = require("uloop")
local open   = io.open
local write  = io.write
local close  = io.close
local popen  = io.popen

local encrypted_ouput_file = "/tmp/encrypted_ouput_file.out"
local cipher_enabled       = tonumber(uciCursor:get("lot","lot_config", "cipher_enabled"))
local cipher_type          = uciCursor:get("lot","lot_config", "cipher_type")
local key                  = uciCursor:get("lot","lot_config", "key")
local iv                   = uciCursor:get("lot","lot_config", "vector")
local cipher_para_valid    = cipher_type and key and iv

local ubusConn
ubusConn = ubus.connect()

if not ubusConn then
  log:error("Failed to connect to ubus")
end


uloop.init()

------------------------------------------------------
-- Invokes shell command processor
------------------------------------------------------
-- @param cmd: Shell command to execute
-- @return Output of command executed
local function runShell(cmd)
    local out = ""
    if cmd and cmd ~= "" then
        local p = popen(cmd, "r")
        if p then
            out = p:read("*all")
            p:close()
        end
    end
    return out
end

------------------------------------------------------
-- Use openssl command to encrypt input message
-- by using pre-configured key and vector, and store the
-- encrypted message to tmp file
------------------------------------------------------
-- @param msg   message to be encrypted
-- @return Output of runShell() function, which should be the final of ciphertext or empty string on error/data not available
local function encrypt2file(msg)
    local result = ""

    if msg and msg ~= "" and cipher_para_valid then
        result = runShell(format("echo -n '%s' | openssl enc %s -K %s -iv %s", msg, cipher_type, key, iv))
    else
        return nil
    end

    --since coap-client can only send encrypted message by using file, we save the encrypted message to a tmp file
    local f = open(encrypted_ouput_file, "w")
    if f then
        f:write(result)
        f:close()
    end

    return result
end

function timestampsConversion(currentTime,delayage)
   return date("!%Y-%m-%dT%TZ",currentTime-delayage)
end

--convert to Json format
function writeToJson(data)
   return json.encode(data, { indent = true, buffer = buffer })
end

-- Vise Payload Convert
function vsiePayloadConvert(data,oui)
    local vsie = data
    local lengthOui = #oui
    local currentOui = sub(data,5,#oui+4)
    if currentOui == oui then
       return sub(data,#oui+5,#data)
    end
end

-- sleep
function sleep(n)
   execute("sleep " .. n)
end

function coapSeverSend(data, coapServer)
      for i=1, #data do
          if data and data[i] ~= nil then
              if cipher_enabled == 1 then
                  local ret = encrypt2file(data[i])
                  if ret ~= nil and ret ~= "" then
                      runShell(format("coap-client -m put -N coap://%s -f %s -B 0.1", coapServer, encrypted_ouput_file))
                  else
                      log:error("Encryption error !! Did you configure an unsupported cipher type/key/iv?")
                  end
              else
                  runShell(format(" echo -n '%s' | coap-client -m put -N coap://%s -f - -B 0.1", data[i], coapServer))
              end
          end
      end
end

-- hex to ascii convert
function string.fromhex(str)
  return(str:gsub('..',function(cc)
    return char(tonumber(cc,16))
    end))
end
--payload construction
function payloadConstruction(probeRequest, currentTime, interval, vendorSpecificie)
    local apsData = {}
    local transactionId = "1"
    for k,v in pairs(probeRequest) do
        local apData = {}
        apData[1] = transactionId
        apData[2] = k
        age = v["age"]
        apData[3] = timestampsConversion(currentTime, age)
        if v["vsie"] ~= nil then
            local currentVise = v["vsie"]
            if vendorSpecificie ~= nil then
                local desiredVisePayload = vsiePayloadConvert(currentVise,vendorSpecificie)
                if desiredVisePayload ~= nil then
                    local visePayloadBase64 = mime.b64(string.fromhex(upper(desiredVisePayload)))
                    apData[4] = visePayloadBase64
                    if age < interval then
                       apsData[ #apsData+1 ] = writeToJson(apData)
                    end
                end
            end
        end
    end
    return apsData
end

--group packet repeat send
local function lotGroupPayloadSend(currentTime, interval, coapServer, retries, retriesDelay, vendorSpecificie)
    local radioData = ubusConn:call("wireless.radio.monitor", "get", { name = "radio_2G" })
    local radiodata = radioData and radioData.radio_2G
    local probeRequest = radiodata and radiodata.probe_request
    if probeRequest ~= nil and currentTime ~= nil and interval ~= nil then
        local apsData = payloadConstruction(probeRequest, currentTime, interval, vendorSpecificie)
        if apsData ~= nil and coapServer ~= nil then
            coapSeverSend(apsData, coapServer)
            if retries ~= nil and retriesDelay ~= nil then
               local MaxRetries = floor(interval/retries)
               if retries < MaxRetries then
                   for i = 1, retries do
                      sleep(retriesDelay)
                      coapSeverSend(apsData, coapServer)
                   end
               end
            end
        end
    end
end


local vendorSpecificie = uciCursor:get("lot","lot_config", "vendorspecificie")
local retries = tonumber(uciCursor:get("lot","lot_config","retries"))
local retriesDelay = tonumber(uciCursor:get("lot","lot_config","retrydelay"))
local interval = tonumber(uciCursor:get("lot","lot_config","interval"))
local coapServer = uciCursor:get("lot","lot_config","server_url")
local lotTimer
--confirm send status
function confirmSendStatus()
    lotTimer:set(interval*1000)
    local LoT_status = uciCursor:get("lot","state","extendedstatus")
    if LoT_status ~= nil and LoT_status == "LISTENING" then
        local currentTime = time()
        if interval ~= nil and coapServer ~= nil and currentTime ~= nil then
            lotGroupPayloadSend(currentTime, interval, coapServer, retries, retriesDelay, vendorSpecificie)
        end
    end
end

lotTimer = uloop.timer(confirmSendStatus)
confirmSendStatus()

uloop.run()
