local M = {}

function M.mobiled_enable(runtime, enabled)
  local uci = runtime.uci
  local x = uci.cursor()
  local mobiled_changed = false

  x:foreach("mobiled", "device", function(s)
    if s["enabled"] ~= enabled then
      x:set("mobiled", s[".name"], "enabled", enabled)
      mobiled_changed = true
    end
  end)

  if mobiled_changed then
    x:commit("mobiled")
    os.execute("/etc/init.d/mobiled reload")
  end
end

return M
