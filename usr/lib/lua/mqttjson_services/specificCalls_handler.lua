-- Copyright (c) 2020 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.
--
-- This table contains the list of calls/features available under specific_calls directory.
-- Values from this table are sent to respective handlers for framing the response to TPS/Cloud.

local M = {}

M.features = {
  ["getdevicelist"]  = "getDeviceListHandler",
  ["gettimeout"] = "getTimeoutListHandler",
  ["addnewextender"] = "getExtenderRSSI"
}

return M
