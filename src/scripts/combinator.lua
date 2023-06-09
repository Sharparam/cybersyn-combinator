local constants = require "scripts.constants"
local config = require "scripts.config"
local log = require("scripts.logger").combinator.class

--- @type Signal
--- @diagnostic disable-next-line assign-type-mismatch
local EMPTY_SIGNAL = { signal = nil, count = 0 }

--- @class CybersynCombinator
--- @field entity LuaEntity
local CC = {}

--- @param name string?
--- @return boolean
local function should_emit_default(name)
  local is_r = name == constants.SETTINGS.CS_REQUEST_THRESHOLD
  local is_p = name == constants.SETTINGS.CS_PRIORITY
  local is_l = name == constants.SETTINGS.CS_LOCKED_SLOTS
  local e_r = settings.global[constants.SETTINGS.EMIT_DEFAULT_REQUEST_THRESHOLD].value
  local e_p = settings.global[constants.SETTINGS.EMIT_DEFAULT_PRIORITY].value
  local e_l = settings.global[constants.SETTINGS.EMIT_DEFAULT_LOCKED_SLOTS].value

  return (is_r and e_r == true) or (is_p and e_p == true) or (is_l and e_l == true)
end

--- @param entity LuaEntity
--- @param sort_all boolean? `true` if all signals should be sorted, otherwise `false` or `nil`.
--- @return CybersynCombinator
function CC:new(entity, sort_all)
  if not entity or not entity.valid or entity.name ~= constants.ENTITY_NAME then
    log:error("new: entity must be valid instance of ", constants.ENTITY_NAME, ", but ", entity.name, " was passed")
    error("CybersynCombinator:new: entity has to be a valid instance of " .. constants.ENTITY_NAME)
  end

  local instance = setmetatable({ entity = entity }, { __index = self })

  instance:validate(sort_all)

  return instance
end

--- @param sort_all boolean?
function CC:validate(sort_all)
  if not self:is_valid_entity() then return end

  if sort_all and self:needs_sorting() then
    self:sort_signals()
  end

  self:sort_network_signals()
  self:validate_cs_signals()
end

--- @return boolean
function CC:is_enabled()
  if not self:is_valid_entity() then return false end
  local control = self:get_control_behavior()
  if not control then return false end
  return control.enabled
end

--- @param enabled boolean
function CC:set_enabled(enabled)
  if not self:is_valid_entity() then return end
  local control = self:get_control_behavior()
  if not control then return end
  control.enabled = enabled
end

function CC:enable() self:set_enabled(true) end
function CC:disable() self:set_enabled(false) end

--- @param name string
--- @return integer?
function CC:get_cs_value(name)
  if not self:is_valid_entity() then return 0 end
  if not config.cs_signals[name] then
    log:warn("get_cs_value: ", name, " is not a valid cybersyn signal")
    return nil
  end

  local control = self:get_control_behavior()
  if not control then return nil end
  local signal = control.get_signal(config.cs_signals[name].slot)
  if not signal or not signal.signal then
    return config.cs_signals[name].default
  end
  return signal.count
end

--- @param name string
--- @param value integer?
function CC:set_cs_value(name, value)
  if not self:is_valid_entity() then return end
  if not config.cs_signals[name] then
    log:warn("set_cs_value: ", name, " is not a valid cybersyn signal")
    return
  end

  local slot = config.cs_signals[name].slot

  --- @type Signal?
  local signal = nil

  if value ~= nil then
    signal = {
      signal = { type = "virtual", name = name },
      count = value
    }
  end

  local control = self:get_control_behavior()
  if not control then return end

  --- @diagnostic disable-next-line param-type-mismatch
  control.set_signal(slot, signal)

  self:validate_cs_signals()
end

--- @param name string
function CC:reset_cs_value(name)
  if not config.cs_signals[name] then
    log:warn("reset_cs_value: ", name, " is not a valid cybersyn signal")
    return
  end

  self:set_cs_value(name, config.cs_signals[name].default)
end

--- @param name string
function CC:remove_cs_value(name)
  self:set_cs_value(name, nil)
end

--- @param slot uint?
--- @return Signal
function CC:get_item_slot(slot)
  return self:get_slot(self:parse_item_slot(slot))
end

--- @param slot uint?
--- @param signal Signal
function CC:set_item_slot(slot, signal)
  self:set_slot(self:parse_item_slot(slot), signal)
end

--- @param slot uint?
--- @param value integer
function CC:set_item_slot_value(slot, value)
  self:set_slot_value(self:parse_item_slot(slot), value)
end

--- @param slot uint?
function CC:remove_item_slot(slot)
  self:remove_slot(self:parse_item_slot(slot))
end

--- @param slot uint?
--- @return Signal
function CC:get_network_slot(slot)
  return self:get_slot(self:parse_network_slot(slot))
end

--- @param slot uint?
--- @param signal Signal
function CC:set_network_slot(slot, signal)
  self:set_slot(self:parse_network_slot(slot), signal)
  self:sort_network_signals()
end

--- @param slot uint?
--- @param value integer
function CC:set_network_slot_value(slot, value)
  self:set_slot_value(self:parse_network_slot(slot), value)
end

--- @param slot uint?
function CC:remove_network_slot(slot)
  self:remove_slot(self:parse_network_slot(slot))
  self:sort_network_signals()
end

--- @return table<uint, Signal>
function CC:get_network_signals()
  local signals = {}
  for slot = 1, config.network_slot_count do
    local signal = self:get_network_slot(slot --[[@as uint]])
    if not signal or not signal.signal then break end
    signals[#signals + 1] = signal
  end
  return signals
end

--- @param signal Signal
--- @return boolean
function CC:add_or_update_network_signal(signal)
  self:sort_network_signals()
  local signals = self:get_network_signals()
  for slot, existing in ipairs(signals) do
    if existing.signal.type == signal.signal.type and existing.signal.name == signal.signal.name then
      self:set_network_slot_value(slot --[[@as uint]], signal.count)
      return true
    end
  end
  local slot = #signals --[[@as uint]] + 1
  if slot > config.network_slot_count then return false end
  self:set_network_slot(slot, signal)
  return true
end

--- @private
--- @param slot uint?
--- @return Signal
function CC:get_slot(slot)
  if not self:is_valid_entity() then return EMPTY_SIGNAL end
  if not slot then return EMPTY_SIGNAL end
  local control = self:get_control_behavior()
  if not control then return EMPTY_SIGNAL end
  return control.get_signal(slot)
end

--- @param slot uint?
--- @param signal Signal
function CC:set_slot(slot, signal)
  if not self:is_valid_entity() then return end
  if not slot then return end
  local control = self:get_control_behavior()
  if not control then return end
  control.set_signal(slot, signal)
end

--- @param slot uint?
--- @param value integer
function CC:set_slot_value(slot, value)
  if not self:is_valid_entity() then return end
  if not slot then return end
  local control = self:get_control_behavior()
  if not control then return end
  local signal = control.get_signal(slot)
  if not signal or not signal.signal then return end
  control.set_signal(slot, { signal = signal.signal, count = value })
end

--- @param slot uint?
function CC:remove_slot(slot)
  if not self:is_valid_entity() then return end
  if not slot then return end

  local control = self:get_control_behavior()
  if not control then
    log:warn("remove_slot: control behaviour is not valid")
    return
  end

  --- @diagnostic disable-next-line param-type-mismatch
  control.set_signal(slot, nil)
end

--- @private
function CC:is_valid_entity()
  return self.entity and self.entity.valid
end

--- @private
--- @return LuaConstantCombinatorControlBehavior?
function CC:get_control_behavior()
  if not self:is_valid_entity() then
    log:warn("get_control_behavior: entity is not valid")
    return nil
  end
  local control = self.entity.get_or_create_control_behavior()
  if not control then
    log:warn("get_control_behavior: control behavior is nil")
    return nil
  end
  if control.type ~= defines.control_behavior.type.constant_combinator then
    log:warn("get_control_behavior: unexpected type. expected constant combinator but was ", control.type)
    return nil
  end

  return control --[[@as LuaConstantCombinatorControlBehavior]]
end

--- @private
--- @param slot integer?
--- @return uint?
function CC:parse_item_slot(slot)
  if not slot then return nil end
  slot = config.slot_start + slot - 1
  if slot < config.slot_start or slot > config.slot_end then
    log:warn("Invalid slot number #", slot)
    return nil
  end

  return slot
end

--- @private
--- @param slot integer?
--- @return uint?
function CC:parse_network_slot(slot)
  if not slot then return nil end
  slot = config.network_slot_start + slot - 1
  if slot < config.network_slot_start or slot > config.network_slot_end then
    log:warn("Invalid network slot number #", slot)
    return nil
  end

  return slot
end

function CC:validate_cs_signals()
  if not self:is_valid_entity() then return end
  local control = self:get_control_behavior()
  if not control then return end
  for slot = config.cs_slot_start, config.cs_slot_end do
    local signal = control.get_signal(slot --[[@as uint]])
    if not signal or not signal.signal then goto continue end
    local type = signal.signal.type
    local name = signal.signal.name
    local cs_signal = config.cs_signals[name]

    if type ~= "virtual" or not cs_signal then goto continue end

    local emit_default = should_emit_default(name)

    if signal.count == 0 or (signal.count == cs_signal.default and not emit_default) then
      --- @diagnostic disable-next-line param-type-mismatch
      control.set_signal(slot --[[@as uint]], nil)
    end

    ::continue::
  end
end

--- @private
function CC:sort_network_signals()
  if not self:is_valid_entity() then return end
  local control = self:get_control_behavior()
  if not control then return end
  local previous = {}
  for slot = config.network_slot_start, config.network_slot_end do
    local signal = control.get_signal(slot --[[@as uint]])
    if signal and signal.signal then
      previous[#previous + 1] = signal
    end
    --- @diagnostic disable-next-line param-type-mismatch
    control.set_signal(slot --[[@as uint]], nil)
  end

  for i, signal in ipairs(previous) do
    local slot = config.network_slot_start + i - 1
    if slot > config.network_slot_end then break end
    control.set_signal(slot, signal)
  end
end

--- @private
function CC:sort_signals()
  if not self:is_valid_entity() then return end
  local control = self:get_control_behavior()
  if not control then return end

  local previous = {}
  for slot = 1, config.total_slot_count do
    local signal = control.get_signal(slot --[[@as uint]])
    if signal and signal.signal then
      previous[#previous + 1] = signal
    end

    --- @diagnostic disable-next-line param-type-mismatch
    control.set_signal(slot --[[@as uint]], nil)
  end

  local net_slot = config.network_slot_start
  local misc_slot = config.slot_start
  for _, signal in pairs(previous) do
    local type = signal.signal.type
    local name = signal.signal.name

    if type == "virtual" and config.cs_signals[name] ~= nil then
      control.set_signal(config.cs_signals[name].slot, signal)
    elseif type == "virtual" and net_slot <= config.network_slot_end then
      control.set_signal(net_slot, signal)
      net_slot = net_slot + 1
    elseif misc_slot <= config.slot_end then
      control.set_signal(misc_slot, signal)
      misc_slot = misc_slot + 1
    end
  end
end

--- @private
--- @return boolean
function CC:needs_sorting()
  if not self:is_valid_entity() then return false end
  local control = self:get_control_behavior()
  if not control then return false end
  local result = false
  for slot = 1, config.total_slot_count do
    local signal = control.get_signal(slot --[[@as uint]])
    if signal and signal.signal ~= nil then
      local type = signal.signal.type
      local name = signal.signal.name
      local cs_signal = config.cs_signals[name]

      if type == "virtual" and cs_signal ~= nil then
        result = result or cs_signal.slot ~= slot
      end

      if slot < config.slot_start and type ~= "virtual" then
        result = true
      elseif slot <= config.cs_slot_count and config.cs_signals[name] == nil then
        result = true
      end
    end
  end

  return result
end

return CC
