#!/usr/bin/lua
---------------------------------------------------------------------------
-- Copyright (c) 2016 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.
---------------------------------------------------------------------------

return function(self, func)
    return function(...)
        return func(self, unpack(arg))
    end
end
