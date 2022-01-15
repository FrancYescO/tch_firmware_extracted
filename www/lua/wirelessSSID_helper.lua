local ipairs, string = ipairs, string
local format, match = string.format, string.match
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local frequency = {}
local M = {}

local function getFrequencyBand(v)
  if frequency[v] then
    return frequency[v]
  end
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands",v)
  local radio = proxy.get(path)[1].value
  frequency[v] = radio
  return radio
end

local function displayOnCard(index)
  return not index or match(index,"[l|w]an") or match(index, "^VLAN%d$")
end

function M.getSSID()
  local ssid_list = content_helper.convertResultToObject("uci.wireless.wifi-iface.",proxy.get("uci.wireless.wifi-iface."))
  local network_map = {}
  for _,v in ipairs(ssid_list) do
    network_map[format("%s%s",v.paramindex, v.ssid)] = v.network
  end

  ssid_list = {}
  for _, v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
    local path = v.path
	if path == "rpc.wireless.ssid.@wl0." or path == "rpc.wireless.ssid.@wl1." then
		local values = proxy.get(path .. "radio" , path .. "ssid", path .. "oper_state")
		if values then
		  local index = format("@%s%s", match(path, "rpc.wireless.ssid.@([%w%_]+)."), values[2].value)
		  -- In cards it should display only the Main SSID and TG-234 SSID's Fix for NG-43454
		  if displayOnCard(network_map[index]) then
			local ap_display_name = proxy.get(path .. "ap_display_name")[1].value
			local display_ssid
			if ap_display_name ~= "" then
			  display_ssid = ap_display_name
			elseif proxy.get(path .. "stb")[1].value == "1" then
			  display_ssid = "IPTV"
			else
			  display_ssid = values[2].value
			end
			ssid_list[#ssid_list+1] = {
			  radio = getFrequencyBand(values[1].value),
			  ssid = display_ssid,
			  state = values[3].value,
			}
		  end
		end
	end
  end
  table.sort(ssid_list, function(a,b)
    return a.radio < b.radio and a.ssid < b.ssid
  end)
  return ssid_list
end

return M
