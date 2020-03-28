---------------------------------
--! @file
--! @brief The main device functionality exposed to the state scripts
---------------------------------

local pairs, table, tostring = pairs, table, tostring
local helper = require("mobiled.scripthelpers")
local detector = require('mobiled.detector')
local runtime

local Device = {}
Device.__index = Device

--! @brief Initialize the device. This function will make sure the initialized value in the device_info table is set to true
--! @param desc The unique indentifier used by Mobiled to identify the device
--! @return true on success. nil and an error message on failure

function Device:init_device()
    return self.__plugin.plugin.init_device(self.__plugin_id)
end

--! @brief Destroy any device specific allocations and break the link between plugin and device
--! @param force Will be set to true if the device is already disconnected
--! @return true on success. nil and an error message on failure

function Device:destroy(force)
    return self.__plugin.plugin.destroy_device(self.__plugin_id, force)
end

--! @brief Get IPv4 and IPv6 information
--! @param session_id The PDN for which you want to retrieve the information
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_ip_info(session_id)
    return self.__plugin.plugin.get_ip_info(self.__plugin_id, session_id)
end

--! @brief Get device info like model and manufacturer
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_device_info()
    local info = self.__plugin.plugin.get_device_info(self.__plugin_id)
    if not info then return {} end

    info.dev_desc = self.desc
    if self.info and self.info.network_interfaces then
        info.network_interfaces = table.concat(self.info.network_interfaces, " ")
    end
    if not info.device_config_parameter then
        info.device_config_parameter = self.info.device_config_parameter
    end
    return info
end

--! @brief Get device capabilities like band_selection_support
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_device_capabilities()
    return self.__plugin.plugin.get_device_capabilities(self.__plugin_id)
end

--! @brief Get network info like cell_id and nas_state
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_network_info()
    return self.__plugin.plugin.get_network_info(self.__plugin_id)
end

local function get_ppp_session_info(info, interface)
    local ret = helper.getUbusData(runtime.ubus, "network.interface." .. interface .. "_ppp", "status", {})
    if ret and ret.data and ret.data.pppinfo then
        local pppstate = ret.data.pppinfo.pppstate
        if pppstate == "connecting" or pppstate == "networking" then
            info.session_state = "connecting"
        elseif pppstate == "connected" then
            info.session_state = "connected"
        end
    end
end

--! @brief Get session info like state, duration and packet counters
--! @param session_id The PDN for which you want to retrieve the information
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_session_info(session_id)
    local info, errMsg = self.__plugin.plugin.get_session_info(self.__plugin_id, session_id)
    if type(info) ~= "table" then return nil, errMsg end

    if not info.session_state then info.session_state = "disconnected" end
    if info.proto then
        if info.proto == "dhcp" then
            local ifname = self:get_network_interface(session_id)
            if ifname then
                info.dhcp = {
                    ifname = ifname
                }
            end
        elseif info.proto == "router" then
            if not info.router then info.router = {} end
            local ifname = self:get_network_interface(session_id)
            if ifname then
                info.router.ifname = ifname
            end
        elseif info.proto == "static" then
            local ifname = self:get_network_interface(session_id)
            if ifname then
                info.static = {
                    ifname = ifname
                }
            end
        elseif info.proto == "ppp" then
            if not info.ppp then info.ppp = {} end
            local session = self:get_data_session(session_id)
            if session and session.profile_id then
                local profile = runtime.mobiled.get_profile(session.profile_id)
                if profile then
                    info.ppp.username = profile.username
                    info.ppp.password = profile.password
                    info.ppp.authentication = profile.authentication
                    info.ppp.apn = profile.apn
                end
            end
            get_ppp_session_info(info, session.interface)
        end
        helper.merge_tables(info[info.proto], self:get_ip_info(session_id))
    end

    return info
end

--! @brief Get profile info stored on device
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_profile_info()
    return self.__plugin.plugin.get_profile_info(self.__plugin_id)
end

--! @brief Get SIM info
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_sim_info()
    return self.__plugin.plugin.get_sim_info(self.__plugin_id)
end

--! @brief Get PIN info like pin_state and reties left
--! @param pin_type The PIN for which you want to request this info
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_pin_info(pin_type)
    return self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
end

--! @brief When start is set to true, starts a new network scan. Otherwise returns any previous scan results
--! @param start Whether to start a new network scan or not
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:network_scan(start)
    return self.__plugin.plugin.network_scan(self.__plugin_id, start)
end

--! @brief Send an SMS
--! @param number The number to send the SMS to
--! @param message The message to send
--! @return true on success. nil and an error message on failure

function Device:send_sms(number, message)
    return self.__plugin.plugin.send_sms(self.__plugin_id, number, message)
end

--! @brief Delete an SMS
--! @param message_id The ID of the SMS to delete
--! @return true on success. nil and an error message on failure

function Device:delete_sms(message_id)
    return self.__plugin.plugin.delete_sms(self.__plugin_id, message_id)
end

--! @brief Mark an SMS as read or unread
--! @param message_id The ID of the SMS to mark
--! @return true on success. nil and an error message on failure

function Device:set_sms_status(message_id, status)
    return self.__plugin.plugin.set_sms_status(self.__plugin_id, message_id, status)
end

--! @brief Retrieve info about the available SMS storage
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_sms_info()
    return self.__plugin.plugin.get_sms_info(self.__plugin_id)
end

--! @brief Retrieves the list of SMS messages on the device
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_sms_messages()
    return self.__plugin.plugin.get_sms_messages(self.__plugin_id)
end

--! @brief Set the power mode of the device to online or airplane
--! @param mode The mode to set the device to
--! @return true on success. nil and an error message on failure

function Device:set_power_mode(mode)
    return self.__plugin.plugin.set_power_mode(self.__plugin_id, mode)
end

--! @brief Called periodically by informer.lua
--! @return true on success. nil and an error message on failure

function Device:periodic()
    return self.__plugin.plugin.periodic(self.__plugin_id)
end

--! @brief Unlock the SIM with the given PIN
--! @param pin_type Which pin to unlock
--! @param pin The PIN to use
--! @return true on success. nil and an error message on failure

function Device:unlock_pin(pin_type, pin)
    local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local oldUnlockRetries = info.unlock_retries_left
    local ret, errMsg = self.__plugin.plugin.unlock_pin(self.__plugin_id, pin_type, pin)
    if not ret then
        return ret, errMsg
    end
    info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local newUnlockRetries = info.unlock_retries_left
    if newUnlockRetries and oldUnlockRetries and (newUnlockRetries < oldUnlockRetries) then
        return nil, "Invalid PIN code provided"
    end
    return true
end

--! @brief Change the PIN code to the given PIN
--! @param pin_type Which pin to unlock
--! @param oldPin The current PIN
--! @param newPin The new PIN to use
--! @return true on success. nil and an error message on failure

function Device:change_pin(pin_type, oldPin, newPin)
    local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local oldUnlockRetries = info.unlock_retries_left
    local ret, errMsg = self.__plugin.plugin.change_pin(self.__plugin_id, pin_type, oldPin, newPin)
    if not ret then
        return ret, errMsg
    end
    info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local newUnlockRetries = info.unlock_retries_left
    if newUnlockRetries and oldUnlockRetries and (newUnlockRetries < oldUnlockRetries) then
        return nil, "Invalid PIN code provided"
    end
    return true
end

function Device:__enable_pin(pin_type, pin, enable)
    local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local oldUnlockRetries = info.unlock_retries_left
    local ret, errMsg
    if(enable) then
        ret, errMsg = self.__plugin.plugin.enable_pin(self.__plugin_id, pin_type, pin)
    else
        ret, errMsg = self.__plugin.plugin.disable_pin(self.__plugin_id, pin_type, pin)
    end
    if not ret then
        return ret, errMsg
    end
    info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local newUnlockRetries = info.unlock_retries_left
    if newUnlockRetries and oldUnlockRetries and (newUnlockRetries < oldUnlockRetries) then
        return nil, "Invalid PIN code provided"
    end
    return true
end

--! @brief Enable PIN protection
--! @param pin_type Which pin to unlock
--! @param pin The current PIN
--! @return true on success. nil and an error message on failure

function Device:enable_pin(pin_type, pin)
    return self:__enable_pin(pin_type, pin ,true)
end

--! @brief Disable PIN protection
--! @param pin_type Which pin to unlock
--! @param pin The current PIN
--! @return true on success. nil and an error message on failure

function Device:disable_pin(pin_type, pin)
    return self:__enable_pin(pin_type, pin ,false)
end

--! @brief Unblock the SIM using the given PUK
--! @param pin_type Which pin to unlock
--! @param puk The PUK
--! @param newPin The new PIN to use
--! @return true on success. nil and an error message on failure

function Device:unblock_pin(pin_type, puk, newPin)
    local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local oldUnblockRetries = info.unblock_retries_left
    local ret, errMsg = self.__plugin.plugin.unblock_pin(self.__plugin_id, pin_type, puk, newPin)
    if not ret then
        return ret, errMsg
    end
    info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
    local newUnblockRetries = info.unblock_retries_left
    if newUnblockRetries and oldUnblockRetries and (newUnblockRetries < oldUnblockRetries) then
        return nil, "Invalid PUK code provided"
    end
    return true
end

--! @brief Starts a new PDN connectivity request
--! @param session_id Which PDN to activate
--! @param profile A table containing info like APN, PDP type, username and password
--! @return true on success. nil and an error message on failure

function Device:start_data_session(session_id, profile)
    return self.__plugin.plugin.start_data_session(self.__plugin_id, session_id, profile)
end

--! @brief Stops PDN connectivity
--! @param session_id Which PDN to deactivate
--! @return true on success. nil and an error message on failure

function Device:stop_data_session(session_id)
    return self.__plugin.plugin.stop_data_session(self.__plugin_id, session_id)
end

--! @brief Stops all PDN connectivity
--! @return true on success. nil and an error message on failure

function Device:stop_all_data_sessions()
    local sessions = self:get_data_sessions()
    for _, session in pairs(sessions) do
        self:stop_data_session(session.session_id)
    end
end

--! @brief Register to the network with the given parameters
--! @param params A table containing info like the radio type, the band and earfcn
--! @return true on success. nil and an error message on failure

function Device:register_network(params)
    return self.__plugin.plugin.register_network(self.__plugin_id, params)
end

--! @brief Get radio info like rssi, rsrp and rsrq
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_radio_signal_info()
    return self.__plugin.plugin.get_radio_signal_info(self.__plugin_id)
end

--! @brief Creates the default attach profile. Some modules require doing this before they register to the network
--! @param profile A table containing info like APN, PDP type, username and password
--! @return true on success. nil and an error message on failure

function Device:create_default_context(profile)
    return self.__plugin.plugin.create_default_context(self.__plugin_id, profile)
end

--! @brief Functionality depends on the plugin
--! @return true on success. nil and an error message on failure

function Device:debug()
    return self.__plugin.plugin.debug(self.__plugin_id)
end

--! @brief Upgrades the device firmware using the given path
--! @param path The path where the firmware image can be found
--! @return true on success. nil and an error message on failure

function Device:firmware_upgrade(path)
    return self.__plugin.plugin.firmware_upgrade(self.__plugin_id, path)
end

--! @brief Get firmware upgrade info like status
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_firmware_upgrade_info()
    return self.__plugin.plugin.get_firmware_upgrade_info(self.__plugin_id)
end

--! @brief Activate a PDN on a given device
--! @param session_id Which session to activate
--! @param profile_id The profile to use
--! @param interface Which Netifd interface the data session is linked to
--! @param optional Indicates if this PDN connectivity request is optional
--! @return true on success. nil and an error message on failure

function Device:activate_data_session(session_id, profile_id, interface, optional)
    for i=#self.__session_profile_map,1,-1 do
        local m = self.__session_profile_map[i]
        if m.session_id == session_id then
            if m.profile_id == profile_id then
                m.deactivate = false
                return true
            else
                local info = self:get_session_info(session_id)
                if info and info.session_state ~= "disconnected" then
                    return nil, "Session " .. tostring(m.session_id) .. " is activated using profile " .. tostring(m.profile_id) .. ". It needs to be deactivated first."
                else
                    table.remove(self.__session_profile_map, i)
                end
            end
        end
        if m.profile_id == profile_id then
            return nil, "Profile " .. tostring(m.profile_id) .. " is already activated on data session " .. tostring(m.session_id) .. ". It needs to be deactivated first."
        end
    end
    table.insert(self.__session_profile_map, { session_id = session_id, profile_id = profile_id, deactivate = false, changed = false, interface = interface })
    return true
end

function Device:deactivate_data_session(session_id, interface)
    for _, m in pairs(self.__session_profile_map) do
        if m.session_id == session_id then
            m.deactivate = true
            return true
        end
    end
    return nil, "deactivate_data_session: No such data session " .. tostring(session_id)
end

function Device:remove_data_session(session_id)
    for i=#self.__session_profile_map,1,-1 do
        local m = self.__session_profile_map[i]
        if m.session_id == session_id then
            table.remove(self.__session_profile_map, i)
            return true
        end
    end
    return nil, "remove_data_session: No such data session " .. tostring(session_id)
end

function Device:get_data_session(session_id)
    for _, m in pairs(self:get_data_sessions()) do
        if m.session_id == session_id then
            return m
        end
    end
    return nil, "get_data_session: No such data session " .. tostring(session_id)
end

function Device:get_data_sessions()
    return self.__session_profile_map
end

--! @brief Get the name of the plugin which is used by the device
--! @return The name of the plugin

function Device:get_plugin_name()
    if self.__plugin then return self.__plugin.name end
    return nil
end

--! @brief Get the corresponding network interface for a given data session
--! @param session_id The data session to get the network interface for
--! @return The name of the network interface or nil when not found
function Device:get_network_interface(session_id)
    if self.__plugin.plugin.get_network_interface then
        local ifname = self.__plugin.plugin.get_network_interface(self.__plugin_id, session_id)
        if ifname then
            return ifname
        end
    end
    if self.info and self.info.network_interfaces then
        return self.info.network_interfaces[session_id+1]
    end
    return nil
end

--! @brief Execute a qualification test command
--! @param command The qualification test command to be executed
--! @return true on success. nil and an error message on failure

function Device:execute_command(command)
    local status = runtime.mobiled.get_state(self.sm.dev_idx)
    local active

    if status == "QualTest" then
        active = "IN"
    else
        active = "NOT IN"
    end
    runtime.log:info("Execute command while " .. active .. " Qualification Test mode: '" .. command .. "'")
    local ret, err = self.__plugin.plugin.execute_command(self.__plugin_id, command)
    runtime.log:info("Execute command " .. command .. " returned.")
    return ret, err
end

--! @brief Establish a voice call to a given number
--! @param number The number to call
--! @return true on success. nil and an error message on failure

function Device:dial(number)
    if self.__plugin.plugin.dial then
        return self.__plugin.plugin.dial(self.__plugin_id, number)
    end
    return nil, "Not supported"
end

--! @brief Stop a voice call with a given call_id
--! @param call_id The call to stop
--! @return true on success. nil and an error message on failure

function Device:end_call(call_id)
    if self.__plugin.plugin.end_call then
        return self.__plugin.plugin.end_call(self.__plugin_id, call_id)
    end
    return nil, "Not supported"
end

--! @brief Answer a voice call with a given call_id
--! @param call_id The call to answer
--! @return true on success. nil and an error message on failure

function Device:accept_call(call_id)
    if self.__plugin.plugin.accept_call then
        return self.__plugin.plugin.accept_call(self.__plugin_id, call_id)
    end
    return nil, "Not supported"
end

--! @brief Get info about a call with call_id
--! @param call_id The call to get info from
--! @return true on success. nil and an error message on failure

function Device:call_info(call_id)
    if self.__plugin.plugin.call_info then
        return self.__plugin.plugin.call_info(self.__plugin_id, call_id)
    end
    return nil, "Not supported"
end

--! @brief Multi party call actions
--! @param call_id The call to apply the action to
--! @param action The action to execute
--! @return true on success. nil and an error message on failure

function Device:multi_call(call_id, action)
    if self.__plugin.plugin.multi_call then
        return self.__plugin.plugin.multi_call(self.__plugin_id, call_id, action)
    end
    return nil, "Not supported"
end

--! @brief Supplementary services actions
--! @param service Which service to use
--! @param action The action to execute
--! @param forwarding_type Optional, call forwarding type
--! @param forwarding_number Optional, call forwarding number
--! @return true on success. nil and an error message on failure

function Device:supplementary_service(service, action, forwarding_type, forwarding_number)
    if self.__plugin.plugin.supplementary_service then
        return self.__plugin.plugin.supplementary_service(self.__plugin_id, service, action, forwarding_type, forwarding_number)
    end
    return nil, "Not supported"
end

--! @brief Get a list of errors from the device
--! @return a list of errors

function Device:get_errors()
    if self.__plugin.plugin.get_errors then
        return self.__plugin.plugin.get_errors(self.__plugin_id) or {}
    end
    return {}
end

--! @brief Login on a router mode dongle
--! @param username The user name
--! @param password The user password
--! @return true on success. nil and an error message on failure

function Device:login(username, password)
    if self.__plugin.plugin.login then
        return self.__plugin.plugin.login(self.__plugin_id, username, password)
    end
    return nil, "Not supported"
end

local M = {}

function M.create(rt, params, plugin)
    runtime = rt

    local device = {
        __session_profile_map = {},
        desc = params.dev_desc,
        type = params.dev_type,
        __plugin = plugin,
        info = {
            network_interfaces = params.network_interfaces,
            firmware_upgrade = {
                status = "not_running"
            }
        },
        errors = {}
    }

    local id, errMsg = device.__plugin.plugin.add_device(params)
    if not id then return nil, errMsg end
    --[[ 
        The ID assigned here is used internally in the plugin to identifty the device 
        for cases where multiple devices use the same plugin
    ]]--
    device.__plugin_id = id
    setmetatable(device, Device)

    helper.merge_tables(device.info, detector.info(device))

    return device
end

return M
