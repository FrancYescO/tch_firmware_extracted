--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

UCI_CONFIG=os.getenv("UCI_CONFIG")

local base="transformer.tests."

if UCI_CONFIG then
    --assume we are running on host
    ON_HOST = true
    base = "test.integration."
end

-- first arrange for the test to be run in the given order.
-- there seem to be dependencies between the tests (ideally there shouldn't,
-- but as these tests are run against the same running instance of transformer
-- this is hard to avoid.)
-- override lunit.testcase and lunit.testcases to make sure the testcases are
-- executed in the order given
local testcases = {}

local lunit = require 'lunit'

-- register testcase, remember order
local testcase = lunit.testcase
lunit.testcase = function(m)
	testcase(m)
	testcases[#testcases+1] = m._NAME
end

-- return the testcases in the order they were added
-- iteration state is kept in a closure
lunit.testcases = function()
	local index = 0
	local function iter()
		index = index + 1
		return testcases[index]
	end
	return iter
end

require(base.."get")
require(base.."set")
require(base.."errors")
require(base.."add")
require(base.."del")
require(base.."gpn")
require(base.."resolve")
require(base.."nrentries")
require(base.."getlist")
require(base.."xde")
require(base.."subscribe")
require(base.."get_abort")

