local constants = require "scripts.constants"
local startup = settings.startup

local slot_count_wagon = tonumber(startup[constants.SETTINGS.SLOT_COUNT_WAGON].value)

if not slot_count_wagon then
  error("wagon slot count is not a valid number")
end

--- @class CybersynSignal
--- @field slot uint
--- @field default integer
--- @field min integer
--- @field max integer

local config = {
  --- @type table<string, CybersynSignal>
  cs_signals = {
    ["cybersyn-request-threshold"] = {
      slot = 1,
      default = 2000,
      min = 1,
      max = constants.INT32_MAX
    },
    ["cybersyn-locked-slots"] = {
      slot = 2,
      default = 0,
      min = 0,
      max = slot_count_wagon
    },
    ["cybersyn-priority"] = {
      slot = 3,
      default = 0,
      min = constants.INT32_MIN,
      max = constants.INT32_MAX
    }
  }
}

return config
