local constants = require "scripts.constants"
local config = require "scripts.config"
local log = require("scripts.logger").combinator.class

--- @type Signal
--- @diagnostic disable-next-line assign-type-mismatch
local EMPTY_SIGNAL = { signal = nil, count = 0 }

local SIGNALS_SECTION_ID = 1
local CYBERSYN_SECTION_ID = 2
local NETWORK_SECTION_ID = 3

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
  if not entity or not entity.valid then
    log:error("new: entity must be valid")
    error("CybersynCombinator:new: entity must be valid")
  end
  local name = entity.name == "entity-ghost" and entity.ghost_name or entity.name
  if name ~= constants.ENTITY_NAME then
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

--- @param id integer
--- @return LuaLogisticSection? section
function CC:get_or_create_section(id)
  if not self:is_valid_entity() then return nil end
  local control = self:get_control_behavior()
  if not control then return nil end
  if not storage.combinator_sections then
    storage.combinator_sections = {}
  end
  local unit_number = self.entity.unit_number
  if not unit_number then return nil end
  if not storage.combinator_sections[unit_number] then
    storage.combinator_sections[unit_number] = {}
  end
  local section = storage.combinator_sections[unit_number][id]
  if section and section.valid then return section end
  section = control.add_section()
  storage.combinator_sections[unit_number][id] = section

  if not section then
    log:error("get_or_create_section: failed to create section")
  end

  return section
end

--- @param name string
--- @return integer?
function CC:get_cs_value(name)
  if not self:is_valid_entity() then return 0 end
  if not config.cs_signals[name] then
    log:warn("get_cs_value: ", name, " is not a valid cybersyn signal")
    return nil
  end

  local section = self:get_or_create_section(CYBERSYN_SECTION_ID)
  if not section then return nil end
  local filter = section.get_slot(config.cs_signals[name].slot)
  if not filter or not filter.value or not filter.min then
    return config.cs_signals[name].default
  end

  return filter.min
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

  local section = self:get_or_create_section(CYBERSYN_SECTION_ID)
  if not section then return end

  if value then
    local filter = {
      value = {
        type = "virtual",
        name = name,
        quality = "normal"
      },
      min = value
    }
    -- log:debug("setting CS signal ", name, " in slot ", slot, " to ", serpent.block(filter))
    section.set_slot(slot, filter)
  else
    section.clear_slot(slot)
  end

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
  return self:get_slot(slot, SIGNALS_SECTION_ID)
end

--- @param slot uint?
--- @param signal Signal
function CC:set_item_slot(slot, signal)
  self:set_slot(slot, signal, SIGNALS_SECTION_ID)
end

--- @param slot uint?
--- @param value integer
function CC:set_item_slot_value(slot, value)
  self:set_slot_value(slot, value, SIGNALS_SECTION_ID)
end

--- @param slot uint?
function CC:remove_item_slot(slot)
  self:remove_slot(slot, SIGNALS_SECTION_ID)
end

--- @param slot uint?
--- @return Signal
function CC:get_network_slot(slot)
  return self:get_slot(slot, NETWORK_SECTION_ID)
end

--- @param slot uint?
--- @param signal Signal
function CC:set_network_slot(slot, signal)
  self:set_slot(slot, signal, NETWORK_SECTION_ID)
  self:sort_network_signals()
end

--- @param slot uint?
--- @param value integer
function CC:set_network_slot_value(slot, value)
  self:set_slot_value(slot, value, NETWORK_SECTION_ID)
end

--- @param slot uint?
function CC:remove_network_slot(slot)
  self:remove_slot(slot, NETWORK_SECTION_ID)
  self:sort_network_signals()
end

--- @return Signal[]
function CC:get_network_signals()
  local signals = {}
  local section = self:get_or_create_section(NETWORK_SECTION_ID)
  if not section then return signals end
  for _, filter in pairs(section.filters) do
    local value = filter.value
    if value and value.name then
      signals[#signals + 1] = {
        signal = value,
        count = filter.min
      }
    end
  end
  return signals
end

--- @param signal Signal
function CC:add_or_update_network_signal(signal)
  self:sort_network_signals()
  local quality = signal.signal.quality or "normal"
  local signals = self:get_network_signals()
  for slot, existing in ipairs(signals) do
    local e_quality = existing.signal.quality or "normal"
    if existing.signal.type == signal.signal.type and existing.signal.name == signal.signal.name and e_quality == quality then
      self:set_network_slot_value(slot --[[@as uint]], signal.count)
      return
    end
  end
  local slot = #signals --[[@as uint]] + 1
  self:set_network_slot(slot, signal)
end

--- @private
--- @param slot uint?
--- @param section_id integer
--- @return Signal
function CC:get_slot(slot, section_id)
  if not self:is_valid_entity() then return EMPTY_SIGNAL end
  if not slot then return EMPTY_SIGNAL end
  local section = self:get_or_create_section(section_id)
  if not section then return EMPTY_SIGNAL end
  local filter = section.get_slot(slot)
  if not filter or not filter.value or not filter.min then return EMPTY_SIGNAL end
  return { signal = filter.value, count = filter.min }
end

--- @param slot uint?
--- @param signal Signal
--- @param section_id integer
function CC:set_slot(slot, signal, section_id)
  if not self:is_valid_entity() then return end
  if not slot then return end
  local section = self:get_or_create_section(section_id)
  if not section then return end
  local filter = {
    value = {
      type = signal.signal.type,
      name = signal.signal.name,
      quality = signal.signal.quality or "normal"
    },
    min = signal.count
  }
  section.set_slot(slot, filter)
end

--- @param slot uint?
--- @param value integer
--- @param section_id integer
function CC:set_slot_value(slot, value, section_id)
  if not self:is_valid_entity() then return end
  if not slot then return end
  local section = self:get_or_create_section(section_id)
  if not section then return end
  local filter = section.get_slot(slot)
  if not filter or not filter.value then return end
  filter.min = value
  section.set_slot(slot, filter)
end

--- @param slot uint?
--- @param section_id integer
function CC:remove_slot(slot, section_id)
  if not self:is_valid_entity() then return end
  if not slot then return end
  local section = self:get_or_create_section(section_id)
  if not section then return end
  section.clear_slot(slot)
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

function CC:validate_cs_signals()
  if not self:is_valid_entity() then return end

  local section = self:get_or_create_section(CYBERSYN_SECTION_ID)
  if not section then return end
  for i, filter in pairs(section.filters) do
    local value = filter.value
    if not value or not value.name then goto continue end
    local type = value.type
    local name = value.name
    local cs_signal = config.cs_signals[name]

    if type ~= "virtual" or not cs_signal then goto continue end

    local emit_default = should_emit_default(name)

    if not filter.min or filter.min == 0 or (filter.min == cs_signal.default and not emit_default) then
      section.clear_slot(i)
    end

    ::continue::
  end
end

--- @private
function CC:sort_network_signals()
  if not self:is_valid_entity() then return end
  local section = self:get_or_create_section(NETWORK_SECTION_ID)
  if not section then return end

  local previous = {}

  for i, filter in pairs(section.filters) do
    local value = filter.value
    if value and value.name then
      previous[#previous + 1] = { value = value, min = filter.min }
    end
    section.clear_slot(i)
  end

  for i, filter in ipairs(previous) do
    section.set_slot(i, filter)
  end
end

--- @param section LuaLogisticSection
--- @return integer?
local function find_empty_slot(section)
  if not section then return nil end
  for i = 1, section.filters_count do
    local filter = section.get_slot(i)
    if not filter then return i end
  end

  return section.filters_count + 1
end

function CC:sort_signals()
  log:debug("performing sort")
  if not self:is_valid_entity() then return end
  local control = self:get_control_behavior()
  if not control then return end

  local cs_filters = {}
  local sig_filters = {}
  local net_filters = {}

  for _, section in pairs(control.sections) do
    if not section then goto continue end
    for _, filter in pairs(section.filters) do
      local value = filter.value
      if not value or not value.name then goto filter_continue end
      local type = value.type
      local name = value.name
      local cs_signal = config.cs_signals[name]

      if type == "virtual" and cs_signal ~= nil then
        cs_filters[#cs_filters + 1] = filter
      elseif type == "virtual" then
        net_filters[#net_filters + 1] = filter
      elseif type == "item" or type == "fluid" then
        sig_filters[#sig_filters + 1] = filter
      end
      ::filter_continue::
    end
    ::continue::
  end

  for _ = 1, control.sections_count do
    control.remove_section(1)
  end

  local cs_sec = self:get_or_create_section(CYBERSYN_SECTION_ID)
  local sig_sec = self:get_or_create_section(SIGNALS_SECTION_ID)
  local net_sec = self:get_or_create_section(NETWORK_SECTION_ID)

  if not cs_sec or not sig_sec or not net_sec then
    log:error("sort_signals: failed to get sections")
    return
  end

  for _, filter in pairs(cs_filters) do
    self:set_cs_value(filter.value.name, filter.min)
  end

  for _, filter in pairs(sig_filters) do
    local slot = find_empty_slot(sig_sec)
    if slot and slot <= config.slot_count then
      sig_sec.set_slot(slot, filter)
    end
  end

  for _, filter in pairs(net_filters) do
    net_sec.set_slot(net_sec.filters_count + 1, filter)
  end
end

--- @private
--- @return boolean
function CC:needs_sorting()
  if not self:is_valid_entity() then return false end
  local control = self:get_control_behavior()
  if not control then return false end
  self:get_or_create_section(CYBERSYN_SECTION_ID)
  self:get_or_create_section(SIGNALS_SECTION_ID)
  self:get_or_create_section(NETWORK_SECTION_ID)

  return control.sections_count > 3
end

return CC
