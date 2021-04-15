-- Copyright (c) 2019 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.


-- This table contains the list of status codes for registration and request/response interaction.
-- Values from this table are sent to reqResponse_handler.lua for framing the response to TPS/Cloud.
local M = {}

-- Status codes for Registration
M.registerCodes = {
  ["200"] = true, -- Successful
  ["409"] = true, -- Conflict, the gateway was already registered
  ["400"] = false -- Bad request
}

-- Status Codes for get/set/add/del request
M.requestCodes = {
  ["401"] = true, -- Error on Setter request
  ["402"] = true, -- Error on Getter request
  ["400"] = true, -- Other General Errors
  ["403"] = true, -- Error on invalid request
  ["206"] = true, -- Parameter Unavailable Error
}

M.successCode = 200
M.generalError = 400
M.setError = 401
M.getError = 402
M.invalidTypeError = 403
M.partialGetError = 206

-- Status code for Authentication messages
M.authSuccess = 200
M.authError = 400

-- Status code for Event Notification messages
M.delEventError = 404 -- Event to be deleted not found
M.addEventError = 405 -- Duplicated event found

-- Version information for initiating mqtt Registration
M.protocolVersion = "1.0"
M.agentVersion = "001"

-- Request Types for handling Datamodel actions
M.requestTypes = {
  ["set"] = "set",
  ["add"] = "add",
  ["del"] = "del",
  ["setApply"] = "set",
  ["execute"] = "execute",
}

M.proxyApplyType = {
  ["add"] = true,
  ["del"] = true,
  ["setApply"] = true,
}

M.validationReqType = {
  ["set"] = true,
  ["setApply"] = true
}

M.specificCallsPath = "/usr/lib/lua/mqttjson_services/specific_calls/"
M.certfile = "/proc/rip/011a.cert"

return M
