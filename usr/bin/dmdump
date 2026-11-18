#!/usr/bin/env lua

--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local tf = require("datamodel")
local dir = require("lfs").dir
local uci = require("uci")
local attributes = require("lfs").attributes
local match, format = string.match, string.format
local print, loadfile, setfenv, pcall, pairs, ipairs, tostring, type =
      print, loadfile, setfenv, pcall, pairs, ipairs, tostring, type
local huge = math.huge
local concat = table.concat

local g_version = "1.0"  -- the current version of dmdump
local g_objtypes = {}  -- array of all the objectType tables of mappings
local g_numEntriesParams = {}  -- table with objtype paths as keys and array of paramnames as values
local g_mappaths = {}  -- array of all directories to scan for mappings
local g_output_file = "/tmp/datamodel.xml"  -- default output file
local g_default_dm  -- default datamodel, retrieved from the cwmpd config; g_mappaths is filled
                    -- with appropriate values based on this value (unless -m is given)

local function log(fmt, ...)
  print(format(fmt, ...))
end

-- Step 0: parse command line arguments

do
  local help = [[

Dump the supported datamodel of this device to a TR-106 compliant XML file.
It will autodetect whether the datamodel is IGD or Device:2; any other
datamodel is not supported (e.g. Device:1).

Usage: %s [-h | -v] [-d <datamodel> | -m <dir>] [-o <file>]

  -h        Print this help text and exit.
  -d <datamodel> The datamodel to dump; either "igd" or "device2". This
            option is a shortcut to automatically use suitable values
            for the -m option.
            Default: %s
  -m <dir>  Load the mappings recursively starting from this directory.
            Can be specified multiple times.
            Default: %s
  -o <file> Write the output to this file.
            Default: %s
  -v        Print the version (%s) and exit.

Please report any errors or warnings that are printed.
]]
  local datamodel_paths = {
    igd = {
      "/usr/share/transformer/mappings/igd/",
      "/usr/share/transformer/mappings/bbf/"
    },
    device2 = {
      "/usr/share/transformer/mappings/device2/",
      "/usr/share/transformer/mappings/bbf/"
    }
  }
  -- Fetch default datamodel, as configured in cwmpd config.
  -- If not configured then assume IGD.
  local datamodel = tf.get("uci.cwmpd.cwmpd_config.datamodel")
  if datamodel and datamodel[1].value == "Device" then
    g_default_dm = "device2"
  else
    g_default_dm = "igd"
  end

  local i = 1
  local function parse_h()
    log(help, arg[0], g_default_dm, concat(datamodel_paths[g_default_dm], ",\n            "), g_output_file, g_version)
    os.exit(0)
  end

  local function parse_d()
    i = i + 1
    g_mappaths = datamodel_paths[arg[i]] or parse_h()
  end

  local function parse_m()
    i = i + 1
    local path = arg[i] or parse_h()
    -- if path doesn't end with "/" (in ASCII) then add it
    if path:byte(#path) ~= 47 then
      path = path .. "/"
    end
    g_mappaths[#g_mappaths+1] = path
  end

  local function parse_o()
    i = i + 1
    g_output_file = arg[i] or parse_h()
  end

  local function parse_v()
    log("%s %s", arg[0], g_version)
    os.exit(0)
  end

  local args = setmetatable({
    ["-h"] = parse_h,
    ["-d"] = parse_d,
    ["-m"] = parse_m,
    ["-o"] = parse_o,
    ["-v"] = parse_v
  }, {
    __index = parse_h
  })

  while arg[i] do
    args[arg[i]]()
    i = i + 1
  end

  -- If no -d or -m option was provided use our
  -- built-in default.
  if #g_mappaths == 0 then
    g_mappaths = datamodel_paths[g_default_dm]
  end
end

-- Step 1: read all mappings and store the datamodel info

do
  local function table_deep_clone(src, dst)
    for k, v in pairs(src) do
      if type(v) == "table" then
        dst[k] = table_deep_clone(v, {})
      else
        dst[k] = v
      end
    end
    return dst
  end

  --check unhide_pattern
  local function check_unhide_patterns(path, unhide_patterns)
    for _, unhide in ipairs(unhide_patterns) do
      if match(path, unhide) then
        return true
      end
    end
    return false
  end

  --check ignore and vendor patterns
  local function check_ignore_patterns(path, ignore_patterns, vendor_patterns)
    for _, ignore in ipairs(ignore_patterns) do
      if match(path, ignore) then
        return true
      end
    end
    if match(path, "%.X_") and not match(path, "%.X_000E50_") then
      for _, vendor in ipairs(vendor_patterns) do
        if match(path, vendor) then
          return false
        end
      end
      return true
    end
    return false
  end

  -- make support ignore_pattern, vendor_pattern, unhide_pattern
  local function mapping_patterns_support(mapping, patterns)
    local objtype = mapping.objectType
    local name = objtype.name
    if objtype.numEntriesParameter and
       check_ignore_patterns("." .. objtype.numEntriesParameter, patterns.ignore_patterns, patterns.vendor_patterns) then
      objtype.numEntriesParameter = nil
    end
    for pname, ptype in pairs(objtype.parameters) do
      local full_name = name .. pname
      if check_ignore_patterns(full_name, patterns.ignore_patterns, patterns.vendor_patterns) then
        objtype.parameters[pname] = nil
      end
      if ptype.hidden  then
        if check_unhide_patterns(full_name, patterns.unhide_patterns) then
          ptype.hidden = nil
        end
      end
    end
  end

  -- In some mappings (e.g. WANDSLInterfaceConfig.Stats.*) they share
  -- the parameters table. We nil out certain fields to do some sanity
  -- checks at the end and this will wreak havoc unless we detect this
  -- reuse and create copies when needed.
  local function check_parameters_reuse(objtype)
    -- Is there already an objtype with the same parameters table?
    for _, ot in ipairs(g_objtypes) do
      if ot.parameters == objtype.parameters then
        -- Reuse detected; create a copy of the parameters table.
        objtype.parameters = table_deep_clone(ot.parameters, {})
      end
    end
  end

  local cursor = uci.cursor()
  local uci_config = cursor:get_all("transformer.@main[0]")
  local patterns = {}
  patterns.unhide_patterns = uci_config and uci_config.unhide_patterns or {}
  patterns.ignore_patterns = uci_config and uci_config.ignore_patterns or {}
  patterns.vendor_patterns = uci_config and uci_config.vendor_patterns or {}
  cursor:close()

  local function env_register(mapping)
    local objtype = mapping.objectType
    check_parameters_reuse(objtype)
    g_objtypes[#g_objtypes + 1] = objtype
    mapping_patterns_support(mapping, patterns)
    if objtype.numEntriesParameter then
      local parent = objtype.name:match("(.+%.)[^%.]+%.[^%.]+%.$")
      if parent then
        local params = g_numEntriesParams[parent]
        if not params then
          params = {}
          g_numEntriesParams[parent] = params
        end
        params[#params + 1] = objtype.numEntriesParameter
      end
    end
  end

  local function env_mapper(name)
    return require("transformer.mapper." .. name)
  end

  local map_env = setmetatable({
    register = env_register,
    mapper = env_mapper
  }, {
    __index = _G,
    __newindex = function()
      error("global variables are evil", 2)
    end
  })

  local function load_map(file)
    local mapping, errmsg = loadfile(file)
    if not mapping then
      -- file not found or syntax error in map
      return nil, errmsg
    end
    setfenv(mapping, map_env)
    local rc, errormsg = pcall(mapping)
    collectgarbage()
    if not rc then
      -- map didn't load
      return nil, errormsg
    end
    return true
  end

  local function load_maps_recursively(mappath)
    for file in dir(mappath) do
      if file ~= "." and file ~= ".." then
        local path = mappath .. file
        local mode = attributes(path, "mode")
        if mode == "directory" then
          load_maps_recursively(path .. "/")
        elseif mode == "file" and match(file, "%.map$") then
          local rc, errmsg = load_map(path)
          if not rc then
            log("could not load map %s: %s", path, errmsg)
          end
        end
      end
    end
  end

  -- Step 1.1: load all maps
  for _, mappath in ipairs(g_mappaths) do
    load_maps_recursively(mappath)
  end
  if #g_objtypes == 0 then
    log("no mappings found at %s", concat(g_mappaths, " and "))
    os.exit(1)
  end
  log("loaded %d objecttypes from %s", #g_objtypes, concat(g_mappaths, " and "))
  table.sort(g_objtypes, function(objtype1, objtype2) return objtype1.name < objtype2.name end)

  for _, objtype in ipairs(g_objtypes) do
    -- Step 1.2: add NumberOfEntries parameters to the parent objecttypes
    local params = g_numEntriesParams[objtype.name]
    if params then
      for _, param in ipairs(params) do
        objtype.parameters[param] = {
          access = "readOnly",
          type = "unsignedInt"
        }
      end
      g_numEntriesParams[objtype.name] = nil
    end
    -- Step 1.3: add aliasParameter flag
    local param = objtype.parameters[objtype.aliasParameter]
    if param then
      param.is_alias = true
    end
    objtype.aliasParameter = nil
  end
  if next(g_numEntriesParams) then
    log("could not add NumberOfEntries parameters for:")
    for parent, params in pairs(g_numEntriesParams) do
      log("  %s: %s", parent, concat(params, ","))
    end
  end
end

-- Step 2: output datamodel XML
do
  local function fprintf(f, fmt, ...)
    f:write(format(fmt, ...), '\n')
  end

  local function get_param_attribs(name, info)
    local attribs = { format('name="%s"', name) }
    if info.access then
      attribs[#attribs + 1] = format('access="%s"', info.access)
    end
    if info.status then
      attribs[#attribs + 1] = format('status="%s"', info.status)
    end
    if info.activeNotify then
      attribs[#attribs + 1] = format('activeNotify="%s"', info.activeNotify)
    end
    if info.forcedInform then
      attribs[#attribs + 1] = format('forcedInform="%s"', info.forcedInform)
    end
    -- Clear the attribs we used (or explicitly didn't use)
    -- so we can later do a sanity check for possibly new attributes
    -- that the script doesn't support yet.
    info.access = nil
    info.status = nil
    info.activeNotify = nil
    info.forcedInform = nil
    info.pathRef = nil  -- not enough info is in the mappings to use this so ignore for now
    info.targetParent = nil  -- not enough info is in the mappings to use this so ignore for now
    return concat(attribs, " ")
  end

  local function write_size(f, info)
    if info.min or info.max then
      f:write('          <size')
      if info.min then
        f:write(' minLength="', info.min, '"')
      end
      if info.max then
        f:write(' maxLength="', info.max, '"')
      end
      f:write('/>', '\n')
    end
  end

  local function write_syntax(f, info)
    if info.list then
      f:write('        <list')
      if info.minItems then
        f:write(' minItems="', info.minItems, '"')
      end
      if info.maxItems then
        f:write(' maxItems="', info.maxItems, '"')
      end
      if info.min or info.max then
        f:write('>', '\n')
        write_size(f, info)
        f:write('        </list>', '\n')
        info.max = nil -- remove it so we don't output a max again for string parameters
      else
        f:write('/>', '\n')
      end
    end
    if info.is_alias then
      f:write(format('        <dataType ref="Alias"/>\n'))
    elseif info.enumeration or info.max or info.range then
      fprintf(f, '        <%s>', info.type)
      if info.enumeration then
        for _, enum in ipairs(info.enumeration) do
          fprintf(f, '          <enumeration value="%s"/>', enum)
        end
      end
      write_size(f, info)
      if info.range then
        for _, r in ipairs(info.range) do
          f:write('          <range')
          if r.min then
            f:write(format(' minInclusive="%s"', r.min))
          end
          if r.max then
            f:write(format(' maxInclusive="%s"', r.max))
          end
          f:write('/>\n')
        end
      end
      fprintf(f, '        </%s>', info.type)
    else
      fprintf(f, '        <%s/>', info.type)
    end
    if info.default then
      fprintf(f, '        <default type="object" value="%s"/>', info.default)
    end
    -- Clear the attribs we used (or explicitly didn't use)
    -- so we can later do a sanity check for possibly new attributes
    -- that the script doesn't support yet.
    info.is_alias = nil
    info.list = nil
    info.minItems = nil
    info.maxItems = nil
    info.min = nil
    info.max = nil
    info.range = nil
    info.enumeration = nil
    info.type = nil
    info.default = nil
    info.command = nil
  end

  local function write_params(f, params)
    for name, info in pairs(params) do
      fprintf(f, '    <parameter %s>', get_param_attribs(name, info))
      if info.description then
        f:write( '      <description>', '\n')
        f:write( '        ', info.description, '\n')
        f:write( '      </description>', '\n')
      else
        f:write( '      <description/>', '\n')
      end
      fprintf(f, '      <syntax%s>', info.hidden and ' hidden="true"' or '')
      write_syntax(f, info)
      f:write(   '      </syntax>', '\n')
      f:write(   '    </parameter>', '\n')
      info.hidden = nil
      info.description = nil
    end
  end

  local function get_objtype_attribs(objtype)
    local attribs = { format('name="%s"', objtype.name),
      format('access="%s"', objtype.access),
      format('minEntries="%d"', objtype.minEntries) }
    local maxEntries = objtype.maxEntries
    if maxEntries == huge then
      maxEntries = "unbounded"
    else
      maxEntries = tostring(maxEntries)
    end
    attribs[#attribs + 1] = format('maxEntries="%s"', maxEntries)
    if objtype.numEntriesParameter then
      attribs[#attribs + 1] = format('numEntriesParameter="%s"', objtype.numEntriesParameter)
    end
    if objtype.enableParameter then
      attribs[#attribs + 1] = format('enableParameter="%s"', objtype.enableParameter)
    end
    -- Clear the attribs we used (or explicitly didn't use)
    -- so we can later do a sanity check for possibly new attributes
    -- that the script doesn't support yet.
    -- Name is not cleared so we can later generate a useful
    -- error message.
    objtype.access = nil
    objtype.minEntries = nil
    objtype.maxEntries = nil
    objtype.numEntriesParameter = nil
    objtype.enableParameter = nil
    return concat(attribs, " ")
  end

  local function write_objtype(f, objtype)
    fprintf(f, '  <object %s>', get_objtype_attribs(objtype))
    if objtype.description then
      f:write( '    <description>', '\n')
      f:write( '      ', objtype.description, '\n')
      f:write( '    </description>', '\n')
    else
      f:write( '    <description/>', '\n')
    end
    write_params(f, objtype.parameters)
    f:write(   '  </object>', '\n')
    objtype.description = nil
  end

  local igd_header = [[
<?xml version="1.0" encoding="UTF-8"?>
<dm:document xmlns:dm="urn:broadband-forum-org:cwmp:datamodel-1-4"
             xmlns:dmr="urn:broadband-forum-org:cwmp:datamodel-report-0-1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="urn:broadband-forum-org:cwmp:datamodel-1-4 http://www.broadband-forum.org/cwmp/cwmp-datamodel-1-4.xsd urn:broadband-forum-org:cwmp:datamodel-report-0-1 http://www.broadband-forum.org/cwmp/cwmp-datamodel-report.xsd"
             spec="urn:broadband-forum-org:tr-098-1-8-0" file="tr-098-1-8-0.xml">
<import file="tr-069-biblio.xml" spec="urn:broadband-forum-org:tr-069-biblio"/>
<import file="tr-106-1-0-types.xml" spec="urn:broadband-forum-org:tr-106-1-0">
  <dataType name="IPAddress"/>
  <dataType name="IPv4Address"/>
  <dataType name="IPv6Address"/>
  <dataType name="IPPrefix"/>
  <dataType name="IPv4Prefix"/>
  <dataType name="IPv6Prefix"/>
  <dataType name="MACAddress"/>
  <dataType name="StatsCounter32"/>
  <dataType name="StatsCounter64"/>
  <dataType name="Alias"/>
  <dataType name="Dbm1000"/>
  <dataType name="UUID"/>
  <dataType name="IEEE_EUI64"/>
  <dataType name="ZigBeeNetworkAddress"/>
</import>
]]

  local dev2_header = [[
<?xml version="1.0" encoding="UTF-8"?>
<dm:document xmlns:dm="urn:broadband-forum-org:cwmp:datamodel-1-5"
             xmlns:dmr="urn:broadband-forum-org:cwmp:datamodel-report-0-1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="urn:broadband-forum-org:cwmp:datamodel-1-5 http://www.broadband-forum.org/cwmp/cwmp-datamodel-1-5.xsd urn:broadband-forum-org:cwmp:datamodel-report-0-1 http://www.broadband-forum.org/cwmp/cwmp-datamodel-report.xsd"
             spec="urn:broadband-forum-org:tr-181-2-8-0" file="tr-181-2-8-0.xml">
<import file="tr-069-1-1-biblio.xml" spec="urn:broadband-forum-org:tr-069-1-1"/>
<import file="tr-106-1-0-types.xml" spec="urn:broadband-forum-org:tr-106-1-0">
  <dataType name="IPAddress"/>
  <dataType name="IPv4Address"/>
  <dataType name="IPv6Address"/>
  <dataType name="IPPrefix"/>
  <dataType name="IPv4Prefix"/>
  <dataType name="IPv6Prefix"/>
  <dataType name="MACAddress"/>
  <dataType name="StatsCounter32"/>
  <dataType name="StatsCounter64"/>
  <dataType name="Alias"/>
  <dataType name="Dbm1000"/>
  <dataType name="UUID"/>
  <dataType name="IEEE_EUI64"/>
  <dataType name="ZigBeeNetworkAddress"/>
  <dataType name="DiagnosticsState"/>
</import>
]]

  local footer = [[
</model>
</dm:document>
]]

  local urn2version = {
    InternetGatewayDevice = {
      ["urn:broadband-forum-org:tr-069-1-0-0"] = "1.0",
      ["urn:broadband-forum-org:tr-098-1-0-0"] = "1.1",
      ["urn:broadband-forum-org:tr-098-1-1-0"] = "1.2",
      ["urn:broadband-forum-org:tr-143-1-0-2"] = "1.3",
      ["urn:broadband-forum-org:tr-098-1-2-1"] = "1.4",
      ["urn:broadband-forum-org:tr-157-1-0-0"] = "1.5",
      ["urn:broadband-forum-org:tr-157-1-1-0"] = "1.6",
      ["urn:broadband-forum-org:tr-157-1-2-0"] = "1.7",
      ["urn:broadband-forum-org:tr-157-1-3-0"] = "1.8",
      ["urn:broadband-forum-org:tr-098-1-3-0"] = "1.9",
      ["urn:broadband-forum-org:tr-098-1-4-0"] = "1.10",
      ["urn:broadband-forum-org:tr-098-1-5-0"] = "1.11",
      ["urn:broadband-forum-org:tr-098-1-6-0"] = "1.12",
      ["urn:broadband-forum-org:tr-098-1-7-0"] = "1.13",
      ["urn:broadband-forum-org:tr-098-1-8-0"] = "1.14"
    },
    Device = {
      ["urn:broadband-forum-org:tr-181-2-0-1"] = "2.0",
      ["urn:broadband-forum-org:tr-181-2-1-0"] = "2.1",
      ["urn:broadband-forum-org:tr-181-2-2-0"] = "2.2",
      ["urn:broadband-forum-org:tr-181-2-3-0"] = "2.3",
      ["urn:broadband-forum-org:tr-181-2-4-0"] = "2.4",
      ["urn:broadband-forum-org:tr-181-2-5-0"] = "2.5",
      ["urn:broadband-forum-org:tr-181-2-6-0"] = "2.6",
      ["urn:broadband-forum-org:tr-181-2-7-0"] = "2.7",
      ["urn:broadband-forum-org:tr-181-2-8-0"] = "2.8",
      ["urn:broadband-forum-org:tr-181-2-9-0"] = "2.9",
      ["urn:broadband-forum-org:tr-181-2-10-0"] = "2.10",
      ["urn:broadband-forum-org:tr-181-2-11-0"] = "2.11"
    }
  }

  local function search_supported_datamodel(root)
    -- get all instances
    local data = tf.getPN(root .. ".DeviceInfo.SupportedDataModel.", true)
    if not data then
      return
    end
    -- check for each instance whether we know the URN
    local URNs = urn2version[root]
    for _, entry in ipairs(data) do
      local URN = tf.get(entry.path .. "URN")
      if URN then
        local version = URNs[URN[1].value]
        if version then
          return version
        end
      end
    end
  end

  -- retrieve info on the device and software version
  local data, errmsg = tf.get("uci.version.version.@version[0].product",
    "uci.version.version.@version[0].version")
  if not data then
    log("failed to retrieve version info: %s", errmsg)
    os.exit(1)
  end
  -- Find out if we're dumping the IGD or Device:2 datamodel by finding the
  -- root node i.e. the first (because it's sorted) objecttype whose name
  -- only has one dot and it's at the end.
  -- This will determine the XML header and how we find out the main
  -- datamodel version that is implemented.
  local header, dm_version
  local root
  for _, objtype in ipairs(g_objtypes) do
    root = match(objtype.name, "^([^%.]+)%.$")
    if root then
      break
    end
  end
  if root == "InternetGatewayDevice" then
    header = igd_header
    -- For the version try IGD.DeviceSummary first.
    local summary = tf.get("InternetGatewayDevice.DeviceSummary")
    if summary then
      dm_version = match(summary[1].value, "^InternetGatewayDevice:([%d%.]+)%[")
    end
    -- If not there or empty try IGD.DeviceInfo.SupportedDataModel.{i}.
    if not dm_version then
      dm_version = search_supported_datamodel(root)
    end
    if not dm_version then
      log("could not determine datamodel version; is the datamodel loaded in Transformer?")
      os.exit(1)
    end
  elseif root == "Device" then
    header = dev2_header
    -- For Device:2 look at Device.DeviceInfo.SupportedDataModel.{i}.
    dm_version = search_supported_datamodel(root)
    if not dm_version then
      log("could not determine datamodel version; is the datamodel loaded in Transformer?")
      os.exit(1)
    end
  else
    if root then
      log("unknown datamodel '%s'", root)
    else
      log("could not find datamodel root")
    end
    os.exit(1)
  end
  local f, errmsg = io.open(g_output_file, "w")
  if not f then
    log("failed to create output file: %s", errmsg)
    os.exit(1)
  end

  f:write(header)
  fprintf(f, '<!-- datamodel for %s %s -->', data[1].value, data[2].value)
  fprintf(f, '<model name="%s:%s">', root, dm_version)
  root = "^" .. root .. "%."
  for i, objtype in ipairs(g_objtypes) do
    -- Only output objtypes that have have the correct root. Some other objtypes
    -- can be present because those mappings make use of the multiroot helper.
    if match(objtype.name, root) then
      write_objtype(f, objtype)
    else
      g_objtypes[i] = nil
    end
    collectgarbage()
  end
  f:write(footer)
  f:close()
  log("datamodel written to %s", g_output_file)
  -- Sanity check: are there still attributes we didn't use when
  -- generating the output? That could mean new attributes are stored
  -- in the mappings and this script possibly needs to be updated.
  for _, objtype in pairs(g_objtypes) do
    local name = objtype.name
    objtype.name = nil
    -- check for unused parameter attributes
    for param, attribs in pairs(objtype.parameters) do
      for attrib in pairs(attribs) do
        log("WARNING: unused attribute '%s' on %s%s", attrib, name, param)
      end
    end
    objtype.parameters = nil
    -- check for unused objtype attributes
    for attrib in pairs(objtype) do
      log("WARNING: unused attribute '%s' on %s", attrib, name)
    end
  end
end
