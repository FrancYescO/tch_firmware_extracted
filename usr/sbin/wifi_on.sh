#!/usr/bin/env lua

local proxy = require("datamodel")

proxy.set("uci.button.button.@watcher.lastmodifiedbyuser", os.date("%FT%TZ", os.time()))

proxy.apply()
