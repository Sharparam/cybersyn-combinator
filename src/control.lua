local constants = require "scripts.constants"
local config = require "scripts.config"
local log = require("scripts.logger").control
local cc_gui = require "scripts.gui"
local cc_remote = require "scripts.remote"
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

script.on_configuration_changed(function(data)
  if not data.mod_changes[constants.MOD_NAME] then return end
  for player_index, player in pairs(game.players) do
    if player.gui.screen[cc_gui.WINDOW_ID] then
      cc_gui:close(player_index, true)
    end
  end
end)

script.on_load(function()
  if not storage.player_data then return end
  for _, player_data in pairs(storage.player_data) do
    if player_data and player_data.state and player_data.state.combinator then
      setmetatable(player_data.state.combinator, { __index = CybersynCombinator })
    end
  end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  local name = event.setting
  local tbl = config.cs_signals[name]
  if not tbl then return end
  local num = tonumber(settings.global[name].value)
  if not num then return end
  tbl.default = num
  log:debug("default value for ", name, " changed to ", num)
end)

local entity_event_filters = {
  { filter = "type", type = "constant-combinator" },
  { filter = "name", name = constants.ENTITY_NAME, mode = "and" }
}

script.on_event(defines.events.on_player_mined_entity, function(event)
  local player = game.get_player(event.player_index)
  local entity = event.entity
  if not player or not entity then return end
  local pname = player.name
  log:debug(entity.name, "[", entity.unit_number, "] destroyed by ", pname)
  cc_gui:on_entity_destroyed(entity.unit_number)
end, entity_event_filters)

script.on_event(defines.events.on_robot_mined_entity, function(event)
  local entity = event.entity
  if not entity then return end
  log:debug(entity.name, "[", entity.unit_number, "] destroyed by bot")
  cc_gui:on_entity_destroyed(entity.unit_number)
end, entity_event_filters)

script.on_event(defines.events.script_raised_destroy, function(event)
  local entity = event.entity
  if not entity then return end
  log:debug(entity.name, "[", entity.unit_number, "] destroyed by script")
  cc_gui:on_entity_destroyed(entity.unit_number)
end, entity_event_filters)

script.on_event(defines.events.on_built_entity, function(event)
  local player = game.get_player(event.player_index)
  local entity = event.entity
  if not player or not entity then return end
  local pname = player.name
  log:debug(entity.name, "[", entity.unit_number, "] built by ", pname)
  local disable = settings.get_player_settings(player)[constants.SETTINGS.DISABLE_BUILT].value
  local combinator = CybersynCombinator:new(entity, true)
  if not disable then return end
  combinator:disable()
  log:debug(entity.name, "[", entity.unit_number, "] disabled due to per-player setting")
end, entity_event_filters)

--- @param event EventData.script_raised_built|EventData.script_raised_revive
local function on_script_raised_built_or_revive(event)
  local entity = event.entity
  if not entity then return end
  local player = entity.last_user
  local disable = false
  if player then
    log:debug("found relevant player in script_raised_built_or_revive")
    disable = settings.get_player_settings(player)[constants.SETTINGS.DISABLE_BUILT].value == true
  else
    disable = settings.global[constants.SETTINGS.DISABLE_NONPLAYER_BUILT].value == true
  end
  local combinator = CybersynCombinator:new(entity, true)
  if not disable then return end
  combinator:disable()
  log:debug(entity.name, "[", entity.unit_number, "] disabled due to per-player or global setting")
end

script.on_event(defines.events.script_raised_built, on_script_raised_built_or_revive, entity_event_filters)
script.on_event(defines.events.script_raised_revive, on_script_raised_built_or_revive, entity_event_filters)

script.on_event(defines.events.on_robot_built_entity, function(event)
  local entity = event.entity
  if not entity then return end
  local robot = event.robot
  local player = entity.last_user or robot.last_user
  local disable = false
  if player then
    log:debug("found relevant player in robot_built_entity")
    disable = settings.get_player_settings(player)[constants.SETTINGS.DISABLE_BUILT].value == true
  else
    disable = settings.global[constants.SETTINGS.DISABLE_NONPLAYER_BUILT].value == true
  end
  local combinator = CybersynCombinator:new(entity, true)
  if not disable then return end
  combinator:disable()
  log:debug(entity.name, "[", entity.unit_number, "] disabled due to per-player or global setting")
end, entity_event_filters)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local dest = event.destination
  if not dest or not dest.valid or dest.type ~= "constant-combinator" then return end
  if dest.name ~= constants.ENTITY_NAME then return end
  CybersynCombinator:new(dest, true)
end)

cc_gui:register()
cc_remote:register()
