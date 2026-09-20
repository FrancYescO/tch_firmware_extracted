#!/usr/bin/env lua
-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---------------------------------
-- Retry mechanism framework
---------------------------------

runtime = {}

retry = {}

ack_retry_array                    = {}
wait_ack_retry_time_interval       = {}
response_retry_array               = {}
wait_retry_time_interval           = {}

function reset_timeouts(object)
    object.current_ack_timer_tick  = object.ack_timeout + 1;
    object.current_resp_timer_tick = object.response_timeout + 1;
    object.current_ack_wait_tick   = object.wait_time_ack_timeout + 1;
    object.current_resp_wait_tick  = object.wait_time_response_timeout + 1;
    return
end

function reset_ack_retry_cnt(object)
    object.current_ack_retry_cnt = object.ack_retry_cnt;
    return;
end

function reset_resp_retry_cnt(object)
    object.current_response_retry_cnt = object.response_retry_cnt;
    return
end

function register_callback(object, response_timeout_callback, arg)
    object.ack_timeout_callback    = function (self, arg)
                                        runtime.log:info("In ack compl callback for "..self.request_key..", "..self.uuid);
                                        self.uuid = response_timeout_callback(arg);
                                     end

     object.ack_callback_args       = arg
     object.response_timeout_callback  = function (self, arg)
                                        runtime.log:info("In resp_cb callback for "..self.request_key..", "..self.uuid);
                                        self.uuid = response_timeout_callback(arg);
                                     end

    object.response_callback_args  = arg

    object.uuid                    = response_timeout_callback(arg);

    object.failure_callback        = function(self, arg)
                                        runtime.log:info("In failure callback for "..self.request_key..", "..self.uuid);
                                     end
    object.failure_callback_args   = nil

    if object.uuid and object.ack_timeout_callback and object.ack_timeout then
        reset_timeouts(object)
        reset_ack_retry_cnt(object)
        reset_resp_retry_cnt(object)
        table.insert(ack_retry_array, object)
    end
end

retry.register_callback = register_callback;

function register_failure_callback(object, register_failure_callback, arg)
    object.failure_callback_args    = arg;
    object.failure_callback         = function (self, arg)
                                        runtime.log:info("In failure callback for "..self.request_key);
                                        register_failure_callback(arg);
                                     end
    return
end

retry.register_failure_callback = register_failure_callback

function retry.ack_recv_handler(uuid)
    local response_retry_obj = nil;
    local ack_retry_index    = nil;
    local ack_retry_obj      = nil;
    for ack_retry_index, ack_retry_obj in ipairs(ack_retry_array)
    do
        if ack_retry_obj.uuid == uuid then

            table.remove(ack_retry_array, ack_retry_index)
            if ack_retry_obj.response_key ~= nil then
                ack_retry_obj.uuid                       = 0;
                reset_timeouts(ack_retry_obj);
                reset_ack_retry_cnt(ack_retry_obj);

                table.insert(response_retry_array, ack_retry_obj)
            end
            return
        end
    end
    return
end

function retry.immediate_retry_handler_on_badresp(response_key)
    local response_retry_index = nil
    local response_retry_obj   = nil

    for response_retry_index, response_retry_obj in ipairs(response_retry_array)
    do
        if response_retry_obj.response_key == response_key then
            table.remove(response_retry_array, response_retry_index)

            reset_timeouts(response_retry_obj)

            if response_retry_obj.current_response_retry_cnt ~= 0 then
                response_retry_obj.current_response_retry_cnt = response_retry_obj.current_response_retry_cnt - 1;
                response_retry_obj:response_timeout_callback(response_retry_obj.response_callback_args)
                if response_retry_obj.uuid ~= 0 then
                    reset_ack_retry_cnt(response_retry_obj)
                    table.insert(ack_retry_array, response_retry_obj)
                end
            end
            return
        end
    end
end

function retry.response_recv_handler(response_key)
    local response_retry_index = nil
    local response_retry_obj   = nil

    runtime.log:info("\"retry.response_recv_handler\" resp_key to find : "..response_key)
    for response_retry_index, response_retry_obj in ipairs(response_retry_array)
    do
        if response_retry_obj.response_key == response_key then
            table.remove(response_retry_array, response_retry_index)
            return
        end
    end
end

function retry.check_existing_retry(request_key)

    local list_all_tables = {ack_retry_array, wait_ack_retry_time_interval, wait_retry_time_interval, response_retry_array};

    local k = nil;
    local v = nil;
    for k,v in ipairs(list_all_tables) do
        for obj_index, retry_obj in ipairs(v)
        do
            if retry_obj.request_key == request_key then
                runtime.log:info(retry_obj.request_key.." found")
                return "found"
            end
        end
    end
    return "";
end

local sec = 1;

function iterate_ack_retry_queue()

    local ack_retry_index = 1;
    while (ack_retry_index <= #ack_retry_array)
    do
        local ack_retry_obj = ack_retry_array[ack_retry_index];
        ack_retry_obj.current_ack_timer_tick = ack_retry_obj.current_ack_timer_tick - 1;
        runtime.log:info("currnt_ack_tick["..ack_retry_obj.request_key.."]: "..ack_retry_obj.current_ack_timer_tick.." , ack_retry["..ack_retry_obj.current_ack_retry_cnt.." ], resp_retry["..ack_retry_obj.current_response_retry_cnt.."]");
        if ack_retry_obj.current_ack_timer_tick == 0 then
            if ack_retry_obj.current_ack_retry_cnt == 0 then
                --if retry count is zero, remove permanently
                table.remove(ack_retry_array, ack_retry_index)
                if ack_retry_obj.failure_callback ~= nil then
                    ack_retry_obj:failure_callback(ack_retry_obj.failure_callback_args)
                end
            else

                --if ack_timeout is '0', then send to wait time ack timeout
                table.remove(ack_retry_array, ack_retry_index)

                reset_timeouts(ack_retry_obj);
                table.insert(wait_ack_retry_time_interval, ack_retry_obj)
            end
        else
            ack_retry_index = ack_retry_index + 1;
        end
        runtime.log:info("arr_len: "..#ack_retry_array)

    end
    return
end

function iterate_ack_wait_retry_queue()
    local wait_ack_retry_time_index = 1;
    while (wait_ack_retry_time_index <= #wait_ack_retry_time_interval)
    do
        local wait_ack_retry_time_obj = wait_ack_retry_time_interval[wait_ack_retry_time_index]

        wait_ack_retry_time_obj.current_ack_wait_tick = wait_ack_retry_time_obj.current_ack_wait_tick - 1;
        runtime.log:info("currnt_wait_ack_tick["..wait_ack_retry_time_obj.request_key.."]: "..wait_ack_retry_time_obj.current_ack_wait_tick.." , ack_retry["..wait_ack_retry_time_obj.current_ack_retry_cnt.." ], resp_retry["..wait_ack_retry_time_obj.current_response_retry_cnt.."]");
        if wait_ack_retry_time_obj.current_ack_wait_tick == 0 then

            table.remove(wait_ack_retry_time_interval, wait_ack_retry_time_index)

            reset_timeouts(wait_ack_retry_time_obj);
            wait_ack_retry_time_obj:ack_timeout_callback(wait_ack_retry_time_obj.ack_callback_args)
            wait_ack_retry_time_obj.current_ack_retry_cnt = wait_ack_retry_time_obj.current_ack_retry_cnt - 1;
            table.insert(ack_retry_array, wait_ack_retry_time_obj)
        else
            wait_ack_retry_time_index = wait_ack_retry_time_index + 1
        end
    end
    return;
end

function iterate_response_wait_retry_queue()
    local wait_retry_time_index = 1;

    while (wait_retry_time_index <= #wait_retry_time_interval )
    do
        local wait_retry_time_obj = wait_retry_time_interval[wait_retry_time_index];

        wait_retry_time_obj.current_resp_wait_tick = wait_retry_time_obj.current_resp_wait_tick - 1;
        runtime.log:info("currnt_wait_response_tick["..wait_retry_time_obj.request_key.."]: "..wait_retry_time_obj.current_resp_wait_tick.." , ack_retry["..wait_retry_time_obj.current_ack_retry_cnt.." ], resp_retry["..wait_retry_time_obj.current_response_retry_cnt.."]");

        if wait_retry_time_obj.current_resp_wait_tick == 0 then
            table.remove(wait_retry_time_interval, wait_retry_time_index)

            reset_timeouts(wait_retry_time_obj)
            wait_retry_time_obj.current_response_retry_cnt = wait_retry_time_obj.current_response_retry_cnt - 1;
            wait_retry_time_obj:response_timeout_callback(wait_retry_time_obj.response_callback_args)
            if wait_retry_time_obj.uuid ~= 0 then
                reset_ack_retry_cnt(wait_retry_time_obj)
                table.insert(ack_retry_array, wait_retry_time_obj)
            end
        else
            wait_retry_time_index = wait_retry_time_index + 1
        end
    end
    return
end


function iterate_response_queue()

    local response_retry_index = 1
    while (response_retry_index <= #response_retry_array)
    do
        local response_retry_obj = response_retry_array[response_retry_index]

        response_retry_obj.current_resp_timer_tick = response_retry_obj.current_resp_timer_tick - 1;
        runtime.log:info("currnt_response_tick["..response_retry_obj.request_key.." ,"..response_retry_obj.response_key.."]: "..response_retry_obj.current_resp_timer_tick.." , ack_retry["..response_retry_obj.current_ack_retry_cnt.." ], resp_retry["..response_retry_obj.current_response_retry_cnt.."]");
        if response_retry_obj.current_resp_timer_tick == 0 then
            if response_retry_obj.current_response_retry_cnt == 0 then
                table.remove(response_retry_array, response_retry_index);
                if response_retry_obj.failure_callback ~= nil then
                    response_retry_obj:failure_callback(response_retry_obj.failure_callback_args)
                end
            else
                table.remove(response_retry_array, response_retry_index)

                reset_timeouts(response_retry_obj);
                table.insert(wait_retry_time_interval, response_retry_obj)
            end
        else
            response_retry_index = response_retry_index + 1
        end
    end
    return
end


function one_sec_timer()
    runtime.log:info(sec.." sec")
    sec = sec + 1;
    runtime.log:info("ack_retry_array              : "..#ack_retry_array);
    runtime.log:info("wait_ack_retry_time_interval : "..#wait_ack_retry_time_interval);
    runtime.log:info("wait_retry_time_interval     : "..#wait_retry_time_interval);
    runtime.log:info("response_retry_array         : "..#response_retry_array);

    iterate_ack_retry_queue();
    iterate_ack_wait_retry_queue()
    iterate_response_wait_retry_queue()
    iterate_response_queue()
    runtime.retry.timer:set(1000);
    return
end

function retry.init(rt)
    runtime = rt
    runtime.retry = {}
    runtime.retry.timer = runtime.uloop.timer(one_sec_timer);
    runtime.retry.timer:set(1000);
    return
end

return retry

