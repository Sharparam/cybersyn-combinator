local constants = require "scripts.constants"
local config = require "scripts.config"
local log = require("scripts.logger").control
local util = require "scripts.util"
local cc_gui = require "scripts.gui"
local CybersynCombinator = require "scripts.combinator"

local function init_cs_default(name)
  if not settings.global[name] then return end
  local num = tonumber(settings.global[name].value)
  if not num then return end
  config.cs_signals[name].default = num
  log:debug("default value for ", name, " initialized to ", num)
end

init_cs_default(constants.SETTINGS.CS_REQUEST_THRESHOLD)
init_cs_default(constants.SETTINGS.CS_PRIORITY)
init_cs_default(constants.SETTINGS.CS_LOCKED_SLOTS)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  local name = event.setting
  local tbl = config.cs_signals[name]
  if not tbl then return end
  local num = tonumber(settings.global[name].value)
  if not num then return end
  tbl.default = num
  log:debug("default value for ", name, " changed to ", num)
end)

util.on_multi_event(
  {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  },
  --- @param event EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive
  function(event)
    local player = game.get_player(event.player_index)
    local entity = event.created_entity or event.entity
    if not player or not entity then return end
    local pname = player.name
    log:debug(entity.name, "[", entity.unit_number, "] built by ", pname)
    local disable = settings.get_player_settings(player)[constants.SETTINGS.DISABLE_BUILT].value
    if not disable then return end
    local combinator = CybersynCombinator:new(entity)
    combinator:disable()
    log:debug(entity.name, "[", entity.unit_number, "] disabled due to per-player setting")
  end,
  {
    { filter = "type", type = "constant-combinator" },
    { filter = "name", name = constants.ENTITY_NAME, mode = "and" }
  }
)

cc_gui:register()
