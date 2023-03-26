local constants = require "constants"
local startup = settings.startup

local slot_rows = tonumber(startup[constants.SETTINGS.SLOT_ROWS].value)

if not slot_rows then
  error("slot rows setting is not a valid number")
end

local config = {
  cs_slot_count = 3,
  network_slot_count = 50,
  slot_rows = slot_rows,
  slot_cols = 14,
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
config.total_slot_count = config.slot_count + config.cs_slot_count

return config
