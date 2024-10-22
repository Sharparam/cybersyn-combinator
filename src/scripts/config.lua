local constants = require "scripts.constants"
local startup = settings.startup

local slot_rows = tonumber(startup[constants.SETTINGS.SLOT_ROWS].value)
local slot_count_wagon = tonumber(startup[constants.SETTINGS.SLOT_COUNT_WAGON].value)

if not slot_rows then
  error("slot rows setting is not a valid number")
end

if slot_rows < 0 then
  error("slot rows is negative")
end

if not slot_count_wagon then
  error("wagon slot count is not a valid number")
end

--- @class CybersynSignal
--- @field slot uint
--- @field default integer
--- @field min integer
--- @field max integer

local config = {
  --- @type uint
  slot_rows = slot_rows --[[@as uint]],
  --- @type uint
  slot_cols = 10,
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

config.slot_count = config.slot_rows * config.slot_cols

return config
