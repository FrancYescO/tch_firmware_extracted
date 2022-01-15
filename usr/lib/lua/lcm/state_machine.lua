--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 - 2018         Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]
local pairs, ipairs = pairs, ipairs

-- see package_states.dot for the state machine
local s_valid_states = {}
local s_persistent_states = {}

local function State(name, persistent)
  s_valid_states[name] = true
  if persistent then
    s_persistent_states[name] = true
  end
  return name
end

local s_stable_states = {
  NEW          = State("new", true),
  DOWNLOADED   = State("downloaded"),
  INSTALLED    = State("installed", true),
  RUNNING      = State("running"),
  RETIRED      = State("retired", true),
  GONE         = State("gone"),
}

local s_transient_states = {
  DOWNLOADING  = State("downloading"),
  INSTALLING   = State("installing"),
  UNINSTALLING = State("uninstalling"),
  STARTING     = State("starting"),
  STOPPING     = State("stopping"),
}

local success_edge = 1
local manual_edge = 2
local failure_edge = 100
local external_edge = 500

-- TODO figure out 'stopped' transition
local s_edges = {
--name               = {                           from,                              to,   edge_weight},
  download           = {            s_stable_states.NEW,  s_transient_states.DOWNLOADING,   manual_edge},
  download_complete  = { s_transient_states.DOWNLOADING,      s_stable_states.DOWNLOADED,  success_edge},
  download_fail      = { s_transient_states.DOWNLOADING,         s_stable_states.RETIRED,  failure_edge},
  install            = {     s_stable_states.DOWNLOADED,   s_transient_states.INSTALLING,   manual_edge},
  remove             = {     s_stable_states.DOWNLOADED,         s_stable_states.RETIRED,   manual_edge},
  install_complete   = {  s_transient_states.INSTALLING,       s_stable_states.INSTALLED,  success_edge},
  install_fail       = {  s_transient_states.INSTALLING,      s_stable_states.DOWNLOADED,  failure_edge},
  uninstall          = {      s_stable_states.INSTALLED, s_transient_states.UNINSTALLING,   manual_edge},
  start              = {      s_stable_states.INSTALLED,     s_transient_states.STARTING,   manual_edge},
  start_complete     = {    s_transient_states.STARTING,         s_stable_states.RUNNING,  success_edge},
  start_fail         = {    s_transient_states.STARTING,       s_stable_states.INSTALLED,  failure_edge},
  stop               = {        s_stable_states.RUNNING,     s_transient_states.STOPPING,   manual_edge},
  stopped            = {        s_stable_states.RUNNING,       s_stable_states.INSTALLED, external_edge},
  stop_complete      = {    s_transient_states.STOPPING,       s_stable_states.INSTALLED,  success_edge},
  stop_fail          = {    s_transient_states.STOPPING,         s_stable_states.RUNNING,  failure_edge},
  uninstall_complete = {s_transient_states.UNINSTALLING,         s_stable_states.RETIRED,  success_edge},
  uninstall_fail     = {s_transient_states.UNINSTALLING,       s_stable_states.INSTALLED,  failure_edge},
  purge              = {        s_stable_states.RETIRED,            s_stable_states.GONE,   manual_edge},
  redownload         = {        s_stable_states.RETIRED,  s_transient_states.DOWNLOADING,   manual_edge},
}

local reverse_lookup_edges = {}
local edges_from_node = {}

for edge, edge_properties in pairs(s_edges) do
  local from_node = edge_properties[1]
  local to_node = edge_properties[2]
  reverse_lookup_edges[from_node.."_"..to_node] = edge
  if not  edges_from_node[from_node] then
    edges_from_node[from_node] = {}
  end
  local starting_from_node = edges_from_node[from_node]
  starting_from_node[#starting_from_node + 1] = edge
end

local M = {
  s_stable_states = s_stable_states,
  s_transient_states = s_transient_states,
  s_valid_states = s_valid_states,
}

function M.is_transient_state(state)
  for _, transient_state in pairs(s_transient_states) do
    if transient_state == state then
      return true
    end
  end
  return false
end

function M.is_persistent_state(state)
  return s_persistent_states[state] or false
end

function M.is_valid_state(state)
  return s_valid_states[state] or false
end

local function find_shortest_path(start_node, destination_node)
  if not s_valid_states[start_node] or not s_valid_states[destination_node] then
    return nil, "One of the given paths is an invalid state"
  end
  local unvisited, weights, previous_node = {}, {}, {}
  for state in pairs(s_valid_states) do
    unvisited[state] = true
    weights[state] = 10000
  end
  weights[start_node] = 0
  local current_node = start_node
  while unvisited[destination_node] and current_node do
    local transitions = edges_from_node[current_node]
    if transitions then
      for _, edge in ipairs(transitions) do
        local neighbor_node = s_edges[edge][2]
        local edge_weight = s_edges[edge][3]
        if weights[current_node] + edge_weight < weights[neighbor_node] then
          weights[neighbor_node] = weights[current_node] + edge_weight
          previous_node[neighbor_node] = current_node
        end
      end
    end
    unvisited[current_node] = nil
    local next_node
    for state in pairs(unvisited) do
      if weights[state] < 10000 and (not next_node or weights[next_node] > weights[state]) then
        next_node = state
      end
    end
    current_node = next_node
  end
  if unvisited[destination_node] then
    return nil, "Can't reach the desired destination node from the current start node"
  end
  local shortest_path = {destination_node}
  current_node = destination_node
  while current_node ~= start_node do
    shortest_path[#shortest_path + 1] = previous_node[current_node]
    current_node = previous_node[current_node]
  end
  return shortest_path
end

function M.find_next_state(current_state, end_state)
  if current_state == end_state then
    -- Already where we need to be
    return end_state
  end
  local shortest_path, errmsg = find_shortest_path(current_state, end_state) -- path will be in reverse order
  if not shortest_path then
    return nil, errmsg
  end
  local next_state = shortest_path[#shortest_path - 1] -- Guaranteed to have two entries (beginning and end)
  local transition = current_state .. "_" .. next_state
  return next_state, reverse_lookup_edges[transition]
end

local function get_typed_transition(current_state, type)
  local edges_from_current = edges_from_node[current_state]
  if not edges_from_current then
    return nil
  end
  for _, edge in ipairs(edges_from_current) do
    if s_edges[edge][3] == type then
      return s_edges[edge][2], edge
    end
  end
end

function M.get_success_transition(current_state)
  return get_typed_transition(current_state, success_edge)
end

function M.get_failure_transition(current_state)
  return get_typed_transition(current_state, failure_edge)
end

return M
