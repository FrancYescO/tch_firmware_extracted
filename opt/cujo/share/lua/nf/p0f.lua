--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local function format_ipsig(sig)
    return string.format('%u:%u+%s:%u', sig.version, sig.ttl, sig.dist,
        sig.opt_len)
end

local function format_tcpsig(sig)
    return string.format('%u:%s,%u:%s', sig.mss, sig.win, sig.ws,
        table.concat(sig.options, ','))
end

-- luacheck: globals p0f_tcpsig
function p0f_tcpsig(sig_ip, sig_tcp, quirks, payload)
    local ip_stuff = format_ipsig(sig_ip)
    local tcp_stuff = format_tcpsig(sig_tcp)
    return string.format('%s:%s:%s:%s', ip_stuff, tcp_stuff,
        table.concat(quirks, ','), payload and '+' or '0')
end

-- luacheck: globals p0f_httpsig
function p0f_httpsig(version, user_agent)
    return string.format('%s:User-Agent::%s', version, user_agent)
end
