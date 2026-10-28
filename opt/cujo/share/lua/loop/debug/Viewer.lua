-- Project: LOOP Class Library
-- Release: 2.3 beta
-- Title  : Visualization of Lua Values
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local select = _G.select
local type = _G.type
local next = _G.next
local pairs = _G.pairs
local rawget = _G.rawget
local rawset = _G.rawset
local setmetatable = _G.setmetatable
local luatostring = _G.tostring

local package = require "package"
local loaded = package.loaded

local math = require "math"
local huge = math.huge

local string = require "string"
local byte = string.byte
local find = string.find
local format = string.format
local gmatch = string.gmatch
local gsub = string.gsub
local match = string.match
local strrep = string.rep

local table = require "table"
local concat = table.concat

local io = require "io"
local defaultoutput = io.output

local oo = require "loop.base"
local class = oo.class

local debug = loaded.debug
local getmetatable = debug and debug.getmetatable or _G.getmetatable


local idpat = "^[%a_][%w_]*$"
local keywords = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}
local escapecodes = {
	["\a"] = [[\a]],
	["\b"] = [[\b]],
	["\f"] = [[\f]],
	["\n"] = [[\n]],
	["\r"] = [[\r]],
	["\t"] = [[\t]],
	["\v"] = [[\v]],
}
local codefmt = "\\%.3d"


local function escapecode(char)
	return escapecodes[char] or format(codefmt, byte(char))
end

local function escapechar(char)
	return "\\"..char
end

local function addargs(list, ...)
	local count = #list
	for i = 1, select("#", ...) do
		list[count+i] = select(i, ...)
	end
end

local function newline(buffer, linebreak, prefix)
	if linebreak then
		buffer:write(linebreak, prefix)
	else
		buffer:write(" ")
	end
end

local function tostringmetamethod(value)
	local meta = getmetatable(value)
	if type(meta) == "table" then
		return rawget(meta, "__tostring"), meta
	end
end


local Viewer = class{
	maxdepth = -1,
	indentation = "  ",
	linebreak = "\n",
	prefix = "",
	output = defaultoutput(),
}

function Viewer:writenumber(value, buffer)
	buffer:write(luatostring(value))
end

function Viewer:writestring(value, buffer)
	local quote
	if self.noaltquotes then
		quote = self.singlequotes and "'" or '"'
	else
		local other
		if self.singlequotes then
			quote, other = "'", '"'
		else
			quote, other = '"', "'"
		end
		if find(value, quote, 1, true) and not find(value, other, 1, true) then
			quote = other
		end
	end
	if not self.nolongbrackets
	and not find(value, "[^%d%p%w \n\t]") --no illegal chars for long brackets
	and find(value, "[\\"..quote.."\n\t]") -- one char that looks ugly in quotes
	and find(value, "[%d%p%w]") then -- one char that indicates plain text
		local nesting = {}
		if find(value, "%[%[") then
			nesting[0] = true
		end
		for level in gmatch(value, "](=*)]") do
			nesting[#level] = true
		end
		if next(nesting) == nil then
			nesting = ""
		else
			for i = 1, huge do
				if nesting[i] == nil then
					nesting = strrep("=", i)
					break
				end
			end
		end
		local open = find(value, "\n") and "[\n" or "["
		buffer:write("[", nesting, open, value, "]", nesting, "]")
	else
		value = gsub(value, "[\\"..quote.."]", escapechar)
		value = gsub(value, "[^%d%p%w ]", escapecode)
		buffer:write(quote, value, quote)
	end
end

function Viewer:writetable(value, buffer, history, prefix, maxdepth)
	buffer:write("{")
	if not self.nolabels then 
		buffer:write(" --[[",history[value],"]]")
	end
	local key, field = next(value)
	if key ~= nil then
		if maxdepth == 0 then
			buffer:write(" ... ")
		else
			maxdepth = maxdepth - 1
			local newprefix = prefix..self.indentation
			local linebreak = self.linebreak
			if not self.noarrays then
				for i = 1, #value do
					newline(buffer, linebreak, newprefix)
					if not self.noindices then buffer:write("[", i, "] = ") end
					self:writevalue(value[i], buffer, history, newprefix, maxdepth)
					buffer:write(",")
				end
			end
			repeat
				local keytype = type(key)
				if self.noarrays
				or keytype ~= "number"
				or key<=0 or key>#value or (key%1)~=0
				then
					newline(buffer, linebreak, newprefix)
					if not self.nofields
					and keytype == "string"
					and not keywords[key]
					and match(key, idpat)
					then
						buffer:write(key)
					else
						buffer:write("[")
						self:writevalue(key, buffer, history, newprefix, maxdepth)
						buffer:write("]")
					end
					buffer:write(" = ")
					self:writevalue(field, buffer, history, newprefix, maxdepth)
					buffer:write(",")
				end
				key, field = next(value, key)
			until key == nil
			newline(buffer, linebreak, prefix)
		end
	elseif not self.nolabels then
		buffer:write(" ")
	end
	buffer:write("}")
end

Viewer["number"] = Viewer.writenumber
Viewer["string"] = Viewer.writestring
Viewer["table"] = Viewer.writetable

function Viewer:label(value)
	local method, table = tostringmetamethod(value)
	if method ~= nil then
		rawset(table, "__tostring", nil)
		local raw = luatostring(value)
		rawset(table, "__tostring", method)
		if self.metalabels then
			local custom = method(value)
			if raw ~= custom then
				raw = custom.." ("..raw..")"
			end
		end
		return raw
	end
	return luatostring(value)
end

function Viewer:writevalue(value, buffer, history, prefix, maxdepth)
	local luatype = type(value)
	if luatype == "nil" then
		buffer:write("nil")
	elseif luatype == "boolean" then
		buffer:write(value and "true" or "false")
	elseif luatype == "number" then
		self:number(value, buffer)
	elseif luatype == "string" then
		self:string(value, buffer)
	else
		local label = history[value]
		if label == nil then
			if self.metaonly then
				local method = tostringmetamethod(value)
				if method ~= nil then
					label = method(value)
					luatype = nil -- cancel detailed view
				end
			end
			if label == nil then
				label = self.nolabels
				    and luatype
				     or self.labels[value] or self:label(value)
			end
			history[value] = label
			local writer = self[luatype]
			if writer then
				return writer(self, value, buffer, history, prefix, maxdepth)
			end
		end
		buffer:write(label)
	end
end

function Viewer:writeto(buffer, ...)
	local prefix   = self.prefix
	local maxdepth = self.maxdepth
	local history  = self.history or {}
	for i = 1, select("#", ...) do
		if i ~= 1 then buffer:write(", ") end
		self:writevalue(select(i, ...), buffer, history, prefix, maxdepth)
	end
end

function Viewer:write(...)
	self:writeto(self.output, ...)
end

function Viewer:tostring(...)
	local buffer = { write = addargs }
	self:writeto(buffer, ...)
	return concat(buffer)
end

function Viewer:packnames(packages)
	if packages == nil then packages = loaded end
	-- create new table for labeled values
	local labels = { __mode = "k" }
	setmetatable(labels, labels)
	self.labels = labels
	-- label currently loaded packages
	for name, pack in pairs(packages) do
		if labels[pack] == nil then
			labels[pack] = name
			if type(pack) == "table" then
				-- label members of the package
				for field, member in pairs(pack) do
					local kind = type(member)
					if labels[member] == nil
					and (kind == "function" or kind == "userdata")
					and type(field) == "string" and match(field, idpat)
					then
						labels[member] = name.."."..field
					end
				end
			end
		end
	end
end

if loaded then Viewer:packnames(loaded) end

return Viewer
