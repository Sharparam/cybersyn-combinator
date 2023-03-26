local constants = require "scripts.constants"
local startup = settings.startup

local slot_rows = tonumber(startup[constants.SETTINGS.SLOT_ROWS].value)
local network_slot_count = tonumber(startup[constants.SETTINGS.NETWORK_SLOT_COUNT].value)

if not slot_rows then
  error("slot rows setting is not a valid number")
end

if not network_slot_count then
  error("network slot count setting is not a valid number")
end

--- @class CybersynSignal
--- @field slot uint
--- @field default integer
--- @field min integer
--- @field max integer

local config = {
  --- @type uint
  cs_slot_count = 3,
  --- @type uint
  network_slot_count = network_slot_count --[[@as uint]],
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
      max = startup[constants.SETTINGS.SLOT_COUNT_WAGON].value
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
config.total_slot_count = config.slot_count + config.cs_slot_count + config.network_slot_count

--- @type uint
config.cs_slot_start = 1
config.cs_slot_end = config.cs_slot_start + config.cs_slot_count - 1
config.network_slot_start = config.cs_slot_count + 1
config.network_slot_end = config.network_slot_start + config.network_slot_count - 1
config.slot_start = config.network_slot_start + config.network_slot_count
config.slot_end = config.slot_start + config.slot_count - 1

return config
