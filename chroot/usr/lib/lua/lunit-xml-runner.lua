require "lunit"

module( "lunit-xml-runner", package.seeall )

-- helper function to create a timestamp that can be used in the 
-- xml output that will be generated
local function create_timestamp()
  local ts = os.date("%Y-%m-%dT%H:%M:%S%z")
  return ts
end

-- define a metatable for a testobject
local test_mt = {
  __newindex = function(t, k, v)
    -- if the verdict is not "pass" we will change the total_failed counter
    -- in the parenting testcase "object"
    if k == "verdict" then
      if v ~= "pass" then
        t.__testsuite.__total_failed = t.__testsuite.__total_failed + 1
      end
    end
    rawset(t, k, v)
  end
}

-- define a metatable for a testcase object
local testcase_mt = {
  __index = function(t, testcasename)
    local testcase = { __testsuite = t }
    setmetatable(testcase, test_mt)
    t[testcasename] = testcase
    -- increase the number of tests that are associated with this testsuite
    t.__total_tests = t.__total_tests + 1
    return testcase
  end
}

-- define a metatable for a testsuite object
local testsuite_mt = {
  __index = function(t, testsuitename)
    local testsuite = {
      __timestamp = create_timestamp(),
      __total_tests = 0,
      __total_failed = 0
    }
    setmetatable(testsuite, testcase_mt)
    t[testsuitename] = testsuite
    return testsuite
  end
}

-- create a "root container" in other words: a collection of testsuites 
local testsuites = {}
setmetatable(testsuites, testsuite_mt)

-- this will be called before every testrun. But since we don't need any
-- information yet at this point - and the information that we could get
-- will be provided later as well - we won't do anything in the begin phase
function begin()
  -- NOP
end

function run(testcasename, testname)
  -- NOP
end

-- helper definition of the pattern that fullname in the following functions will
-- provide. We will "capture -> ()" all characters that are not ". -> ^%." starting
-- from the beginning of the string until we come to a dot or to the end of the string  
local pattern = "(.+)%.([^%.]+)$"
local pattern2="([^:]+):?"

-- the error function will be called by lunit when a test results in an error
function err(fullname, message, traceback)
  local testsuitename, testcasename = string.match(fullname, pattern)
  testcasename = string.match(testcasename, pattern2)
  local testcase = testsuites[testsuitename][testcasename]
  testcase.verdict = "error"
  testcase.traceback = traceback
  testcase.msg = tostring(message)
end

-- the fail function will be called by lunit when a test results in a fail
function fail(fullname, where, message, usermessage)
  local testsuitename, testcasename = string.match(fullname, pattern)
  testcasename = string.match(testcasename, pattern2)
  local testcase = testsuites[testsuitename][testcasename]
  testcase.verdict = "fail"
  testcase.faillocation = where
  testcase.msg = message
  testcase.usrmsg = tostring(usermessage)
end

-- the pass function will be called by lunit when a test results in a pass
function pass(testsuitename, testcasename)
  local testcase = testsuites[testsuitename][testcasename]
  testcase.verdict = "pass"
end

local entities = { ['<'] = "&lt;", ['>'] = "&gt;", ['&'] = "&amp;",
                   ['"'] = "&quot;", ["'"] = "&#39;", ["\\"]="&#92;"}
                   
function xml_escape(s)
  return s:gsub('[<>&"\'\\]', entities)
end



function done()
  -- open a file and write the testresults in an xml format to the file
  -- the testresults will be written to the tmp-folder unless overridden with an env var
  local filename = os.getenv("LUNIT_OUTPUTFILE") or "/tmp/lunit_testresults.xml"
  -- try to open the result file; if it already exists then append a
  -- number and try again
  local pattern = "(.+%D)(%d*)(%.[^%.]*)$"
  while true do
    local f = io.open(filename, "r")
    if not f then
      break
    end
    f:close()
    local prefix, number, suffix = filename:match(pattern)
    assert(prefix and suffix, "weird filename")
    number = tonumber(number)
    number = number and (number + 1) or 1
    suffix = suffix or ""
    filename = prefix .. number .. suffix
  end
  local f = assert(io.open(filename, "w+"))
  local function writef(format, ...)
    f:write( string.format(format, ...) )
  end
  writef('<testsuites>\n')
  for testsuitename, testsuite in pairs(testsuites) do
    writef('  <testsuite name="%s" tests="%d" failures="%d" timestamp="%s">\n',
      testsuitename, testsuite.__total_tests, testsuite.__total_failed, testsuite.__timestamp)
    testsuite.__total_tests = nil
    testsuite.__total_failed = nil
    testsuite.__timestamp = nil
    for testcasename, testcase in pairs(testsuite) do
      if testcase.verdict == "pass" then
        writef('    <testcase name="%s" classname="%s.%s"/>\n', testcasename, testsuitename, testcasename)
      elseif testcase.verdict == "fail" then
        writef('    <testcase name="%s" classname="%s.%s">\n', testcasename, testsuitename, testcasename)
        if testcase.usrmsg then
          writef('      <error message="%s">FAIL:%s:%s</error>\n', xml_escape(testcase.msg), xml_escape(testcase.faillocation), xml_escape(testcase.usrmsg))
        else
          writef('      <error message="%s">FAIL:%s</error>\n', xml_escape(testcase.msg), xml_escape(testcase.faillocation))
        end
        writef('    </testcase>\n')
      elseif testcase.verdict == "error" then
        writef('    <testcase name="%s" classname="%s.%s">\n', testcasename, testsuitename, testcasename)
        if testcase.traceback then
          writef('      <error message="%s">ERROR:%s</error>\n', xml_escape(testcase.msg), xml_escape(table.concat(testcase.traceback, "\n\t")))
        else
          writef('      <error message="%s">ERROR</error>\n', xml_escape(testcase.msg))
        end
        writef('    </testcase>\n')
      else
        print("should not get here!!")
      end
    end
    writef('  </testsuite>\n')
  end
  writef('</testsuites>\n')
  testsuites = {}
  setmetatable(testsuites, testsuite_mt)
  f:close()
end
