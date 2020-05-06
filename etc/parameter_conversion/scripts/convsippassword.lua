local crypto = require("tch.simplecrypto")
local uc = require("uciconv")
local oldConfig = uc.uci('old')
local newConfig = uc.uci('new')

oldConfig:foreach("mmpbxrvsipnet", "profile", function(s)
    local subsPassword = {}
    local section = s[".name"]
    local decryptedPassword
    local encryptedPassword
    if (s.password ~= nil and s.password ~= '') then
        decryptedPassword = crypto.decrypt(s.password) or s.password
        encryptedPassword = crypto.encrypt_keysel(decryptedPassword,crypto.AES_256_CBC, crypto.RIP_RANDOM_A)
        if encryptedPassword then
            newConfig:set("mmpbxrvsipnet", section, "password", encryptedPassword)
        end
    end
    if type(s.subscription_password) == 'table' then
        for _,value in ipairs(s.subscription_password) do
            if (value ~= nil and value ~= '') then
                decryptedPassword = crypto.decrypt(value) or value
                encryptedPassword = crypto.encrypt_keysel(decryptedPassword,crypto.AES_256_CBC, crypto.RIP_RANDOM_A)
                if encryptedPassword then
                    subsPassword[#subsPassword+1] = encryptedPassword
                end
            end
        end
        newConfig:set("mmpbxrvsipnet", section, "subscription_password", subsPassword)
    end
end)
newConfig:commit("mmpbxrvsipnet")
