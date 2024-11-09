local constants = require "scripts.constants"
local config = require "scripts.config"
local log = require("scripts.logger").gui
local cc_util = require "scripts.cc_util"
local masking = require "scripts.masking"
local expression = require "scripts.expression"
local CybersynCombinator = require "scripts.combinator"
local util = require "__core__.lualib.util"
local flib_gui = require "__flib__.gui"

local ceil = math.ceil
local floor = math.floor
local gsub = string.gsub

--- @param num number
--- @return number
local function round(num) return floor(num + 0.5) end

--- @param count number
--- @return string
local function format_signal_count(count)
  local formatted = util.format_number(count, true)
  local trimmed = gsub(formatted, "(%d%d%d)[%.,]%d+", "%1")
  return trimmed
end

local WINDOW_ID = "cybersyn-constant-combinator-window"
local DIMMER_ID = "cybersyn-constant-combinator-dimmer"
local ENCODER_ID = "cybersyn-constant-combinator-encoder"
local DESC_EDIT_ID = "cybersyn-constant-combinator-description-edit"

local RED = "utility/status_not_working"
local GREEN = "utility/status_working"
local YELLOW = "utility/status_yellow"
local STATUS_SPRITES = {
  [defines.entity_status.working] = GREEN,
  [defines.entity_status.normal] = GREEN,
  [defines.entity_status.ghost] = YELLOW,
  [defines.entity_status.no_power] = RED,
  [defines.entity_status.low_power] = YELLOW,
  [defines.entity_status.disabled_by_control_behavior] = RED,
  [defines.entity_status.disabled_by_script] = RED,
  [defines.entity_status.marked_for_deconstruction] = RED
}
local DEFAULT_STATUS_SPRITE = RED
local GHOST_STATUS_SPRITE = YELLOW
local STATUS_NAMES = {
  [defines.entity_status.working] = { "entity-status.working" },
  [defines.entity_status.normal] = { "entity-status.normal" },
  [defines.entity_status.ghost] = { "entity-status.ghost" },
  [defines.entity_status.no_power] = { "entity-status.no-power" },
  [defines.entity_status.low_power] = { "entity-status.low-power" },
  [defines.entity_status.disabled_by_control_behavior] = { "entity-status.disabled" },
  [defines.entity_status.disabled_by_script] = { "entity-status.disabled-by-script" },
  [defines.entity_status.marked_for_deconstruction] = { "entity-status.marked-for-deconstruction" }
}
local DEFAULT_STATUS_NAME = { "entity-status.disabled" }
local GHOST_STATUS_NAME = { "entity-status.ghost" }

local BIT_BUTTON_STYLE = "cybersyn-combinator_encoder_bit-button"
local BIT_BUTTON_PRESSED_STYLE = "cybersyn-combinator_encoder_bit-button_pressed"

--- @param pressed boolean
local function bit_button_style(pressed)
  return pressed and BIT_BUTTON_PRESSED_STYLE or BIT_BUTTON_STYLE
end

local cc_gui = {
  WINDOW_ID = WINDOW_ID,
  ENCODER_ID = ENCODER_ID
}

--- @class SignalEntry
--- @field button LuaGuiElement

--- @class NetworkMaskState
--- @field list LuaGuiElement
--- @field signal_button LuaGuiElement
--- @field textfield LuaGuiElement
--- @field add_button LuaGuiElement
--- @field signal Signal?
--- @field mask integer?
--- @field slot integer?

--- @class EncoderState
--- @field dialog LuaGuiElement?
--- @field signal_button LuaGuiElement
--- @field textfield LuaGuiElement
--- @field bit_buttons LuaGuiElement
--- @field mask integer?
--- @field display_dec LuaGuiElement
--- @field display_hex LuaGuiElement
--- @field display_bin LuaGuiElement
--- @field display_oct LuaGuiElement
--- @field confirm_button LuaGuiElement

--- @class DescriptionEditState
--- @field dialog LuaGuiElement?
--- @field textfield LuaGuiElement

--- @class UiState
--- @field main_window LuaGuiElement
--- @field status_sprite LuaGuiElement
--- @field status_label LuaGuiElement
--- @field entity_preview LuaGuiElement
--- @field on_off LuaGuiElement
--- @field item_total_label LuaGuiElement
--- @field item_stacks_label LuaGuiElement
--- @field fluid_total_label LuaGuiElement
--- @field signal_value_stacks LuaGuiElement
--- @field signal_value_items LuaGuiElement
--- @field signal_value_confirm LuaGuiElement
--- @field signals SignalEntry[]
--- @field entity LuaEntity
--- @field combinator CybersynCombinator
--- @field selected_slot uint?
--- @field selected_slot_button LuaGuiElement?
--- @field stack_size integer?
--- @field network_mask NetworkMaskState
--- @field add_description_button LuaGuiElement.add_param.button
--- @field description_header LuaGuiElement.add_param.flow
--- @field description_scroll LuaGuiElement.add_param.scroll_pane
--- @field description_label LuaGuiElement
--- @field dimmer LuaGuiElement?
--- @field encoder EncoderState?
--- @field description_edit DescriptionEditState?

--- @param player_index PlayerIdentification?
--- @return UiState?
local function get_player_state(player_index)
  if not player_index then return nil end
  local data = cc_util.get_player_data(player_index)
  if not data then return nil end
  return data.state --[[@as UiState?]]
end

--- @param player_index uint
--- @param state UiState
local function set_player_state(player_index, state)
  local data = cc_util.get_player_data(player_index)
  if not data then
    log:error("failed to get player data table for player ", player_index, " for writing state")
    return -- TODO: Throw error?
  end
  data.state = state
end

--- @param player LuaPlayer
--- @param window_id string
--- @return boolean
local function destroy(player, window_id)
  local screen = player.gui.screen
  if window_id == DIMMER_ID then
    local state = get_player_state(player)
    if state then state.dimmer = nil end
  end
  if not screen[window_id] then
    log:debug("destroy called on ", window_id, " but it doesn't exist")
    return false
  end
  screen[window_id].destroy()
  log:debug("destroyed ", window_id)
  return true
end

--- @param element LuaGuiElement
--- @param player PlayerIdentification?
--- @param fallback number?
--- @return number?
local function resolve_textfield_number(element, player, fallback)
  if not element or not element.text then return nil end
  local min = tonumber(element.tags.min) or constants.INT32_MIN
  local max = tonumber(element.tags.max) or constants.INT32_MAX
  local enable_expressions = false
  if player then
    enable_expressions = settings.get_player_settings(player)[constants.SETTINGS.ENABLE_EXPRESSIONS].value == true
  end

  --- @type number?
  local value

  if enable_expressions then
    value = expression.parse(element.text, fallback)
  else
    value = tonumber(element.text) or fallback
  end

  if not value then return nil end

  if value < 0 and element.tags.allow_negative == false then
    value = 0
  end

  if element.tags.allow_decimal == false then
    value = round(value)
  end

  return util.clamp(value, min, max)
end

--- @param state UiState
local function update_signal_table(state)
  if not state then return end

  local item_request_total = 0
  local item_request_stacks = 0
  local fluid_request_total = 0

  for slot = 1, config.slot_count do
    local signal = state.combinator:get_item_slot(slot --[[@as uint]])
    if signal and signal.signal then
      local button = state.signals[slot].button
      button.elem_value = signal.signal
      button.label.caption = format_signal_count(signal.count)
      button.locked = true
      if signal.signal.type == "item" and signal.count < 0 then
        local stack_size = prototypes.item[signal.signal.name].stack_size
        local stacks = math.ceil(signal.count / stack_size)
        item_request_total = item_request_total + signal.count
        item_request_stacks = item_request_stacks + stacks
      elseif signal.signal.type == "fluid" and signal.count < 0 then
        fluid_request_total = fluid_request_total + signal.count
      end
    end
  end

  item_request_total = math.abs(item_request_total)
  item_request_stacks = math.abs(item_request_stacks)
  fluid_request_total = math.abs(fluid_request_total)
  state.item_total_label.caption = format_signal_count(item_request_total)
  state.item_total_label.tooltip = util.format_number(item_request_total, false)
  state.item_stacks_label.caption = format_signal_count(item_request_stacks)
  state.item_stacks_label.tooltip = util.format_number(item_request_stacks, false)
  state.fluid_total_label.caption = format_signal_count(fluid_request_total)
  state.fluid_total_label.tooltip = util.format_number(fluid_request_total, false)
end

--- @param state UiState
local function update_totals(state)
  if not state then return end

  local item_request_total = 0
  local item_request_stacks = 0
  local fluid_request_total = 0

  for slot = 1, config.slot_count do
    local signal = state.combinator:get_item_slot(slot --[[@as uint]])
    if signal and signal.signal then
      if signal.signal.type == "item" and signal.count < 0 then
        local stack_size = prototypes.item[signal.signal.name].stack_size
        local stacks = math.ceil(signal.count / stack_size)
        item_request_total = item_request_total + signal.count
        item_request_stacks = item_request_stacks + stacks
      elseif signal.signal.type == "fluid" and signal.count < 0 then
        fluid_request_total = fluid_request_total + signal.count
      end
    end
  end

  item_request_total = math.abs(item_request_total)
  item_request_stacks = math.abs(item_request_stacks)
  fluid_request_total = math.abs(fluid_request_total)
  state.item_total_label.caption = format_signal_count(item_request_total)
  state.item_total_label.tooltip = util.format_number(item_request_total, false)
  state.item_stacks_label.caption = format_signal_count(item_request_stacks)
  state.item_stacks_label.tooltip = util.format_number(item_request_stacks, false)
  state.fluid_total_label.caption = format_signal_count(fluid_request_total)
  state.fluid_total_label.tooltip = util.format_number(fluid_request_total, false)
end

--- @param state UiState
local function update_cs_signals(state)
  for name, data in pairs(config.cs_signals) do
    local value = state.combinator:get_cs_value(name)
    local default = settings.global[name].value or data.default
    local element = state[name]
    local reset = state[name .. "_reset"]
    if element then
      element.text = tostring(value)
    end
    if reset then
      reset.enabled = value ~= default
    end
  end
end

--- @param state UiState
--- @param event EventData.on_gui_click|EventData.on_gui_elem_changed
local function change_signal_count(state, event)
  local slot = state.selected_slot
  local signal = state.combinator:get_item_slot(slot)
  if not signal or not signal.signal then
    cc_gui:close(event.player_index)
    return
  end

  local signal_type = signal.signal.type
  local signal_name = signal.signal.name

  local value = signal.count
  log:debug("change_signal_count: signal type is ", signal_type, ", name is ", signal_name)

  local focus_stacks = false

  state.signal_value_items.enabled = true
  state.signal_value_items.text = tostring(value)
  state.signal_value_confirm.enabled = true

  if signal_type == "item" or signal_type == "fluid" then
    --- @type integer
    local stack_size
    if signal_type == "item" then
      stack_size = prototypes.item[signal_name].stack_size
      state.signal_value_stacks.enabled = true
      if settings.get_player_settings(event.player_index)[constants.SETTINGS.USE_STACKS].value then
        focus_stacks = true
      end
    elseif signal_type == "fluid" then
      stack_size = 1
      state.signal_value_stacks.enabled = false
    end
    local stacks = value / stack_size
    state.signal_value_stacks.text = tostring(stacks >= 0 and ceil(stacks) or floor(stacks))
    state.stack_size = stack_size
  else
    state.signal_value_stacks.enabled = false
    state.stack_size = 1
  end

  if focus_stacks then
    state.signal_value_stacks.focus()
    state.signal_value_stacks.select_all()
  else
    state.signal_value_items.focus()
    state.signal_value_items.select_all()
  end
end

--- @param player_index uint
--- @param state UiState
--- @param value integer
--- @param clear_selected boolean
local function set_new_signal_value(player_index, state, value, clear_selected)
  local new_value = util.clamp(value, constants.INT32_MIN, constants.INT32_MAX)
  local convert = settings.get_player_settings(player_index)[constants.SETTINGS.NEGATIVE_SIGNALS].value == true
  local current = state.combinator:get_item_slot(state.selected_slot)
  if convert and current.signal.type ~= "virtual" and new_value > 0 then
    new_value = -new_value
  end
  state.combinator:set_item_slot_value(state.selected_slot, new_value)
  state.signal_value_items.enabled = false
  state.signal_value_stacks.enabled = false
  state.signal_value_confirm.enabled = false
  state.signal_value_items.text = tostring(new_value)
  if state.stack_size then
    local stacks = value / state.stack_size
    state.signal_value_stacks.text = tostring(stacks >= 0 and ceil(stacks) or floor(stacks))
  end
  state.signals[state.selected_slot].button.label.caption = format_signal_count(new_value)
  if clear_selected then
    state.selected_slot = nil
  end
  state.stack_size = nil
  update_totals(state)
end

--- @param element LuaGuiElement
--- @param player PlayerIdentification?
--- @param update_element boolean
local function set_cs_signal_value(element, player, update_element)
  local state = get_player_state(player)
  if not state then return end
  local signal_name = element.tags.signal_name --[[@as string]]
  local current = state.combinator:get_cs_value(signal_name)
  local value = resolve_textfield_number(element, player, current)
  if value then
    log:debug("cs_signal_value_changed: ", signal_name, " changed to ", value)
  else
    log:debug("cs_signal_value_changed: invalid new value, resetting to current (", current, ")")
    value = current
  end
  if not value then return end
  local min = constants.INT32_MIN
  local max = constants.INT32_MAX
  if config.cs_signals[signal_name] then
    min = config.cs_signals[signal_name].min
    max = config.cs_signals[signal_name].max
  end
  value = util.clamp(value, min, max)
  state.combinator:set_cs_value(signal_name, value)
  local default = settings.global[signal_name].value or config.cs_signals[signal_name].default
  local is_default = value == default
  local reset = state[signal_name .. "_reset"]
  if reset then reset.enabled = not is_default end
  if update_element then element.text = tostring(value) end
end

local handle_network_list_item_click

--- @param player PlayerIdentification?
--- @param state UiState?
local function refresh_network_list(player, state)
  if not state then return end
  local list = state.network_mask.list
  list.clear()
  local signals = state.combinator:get_network_signals()
  for slot, signal in ipairs(signals) do
    local mask = signal.count
    local formatted_mask = masking.format(mask, player, true)
    local rich_type = signal.signal.type == "virtual" and "virtual-signal" or signal.signal.type
    local quality = signal.signal.quality or "normal"
    local rich = "[" .. rich_type .. "=" .. signal.signal.name .. ",quality=" .. quality .. "] " .. formatted_mask
    local dec = masking.format_explicit(mask, masking.Mode.DECIMAL, false, true)
    local hex = masking.format_explicit(mask, masking.Mode.HEX, false, true)
    local bin = masking.format_explicit(mask, masking.Mode.BINARY, false, true)
    local oct = masking.format_explicit(mask, masking.Mode.OCTAL, false, true)
    flib_gui.add(list, {
      type = "button",
      style = "cybersyn-combinator_network-list_item",
      caption = rich,
      tooltip = { "cybersyn-combinator-window.network-list-item-tooltip", dec, hex, bin, oct },
      handler = {
        [defines.events.on_gui_click] = handle_network_list_item_click
      },
      tags = {
        slot = slot,
        mask = mask,
        signal_type = signal.signal.type,
        signal_name = signal.signal.name
      }
    })
  end
end

--- @param state UiState?
local function focus_network_mask_input(state)
  if not state then return end
  state.network_mask.textfield.focus()
  state.network_mask.textfield.select_all()
end

--- @param player PlayerIdentification?
--- @param state UiState?
local function add_network_mask(player, state)
  if not state then return end
  local signal = state.network_mask.signal
  if not signal or signal.count == 0 then return end
  local rich_type = signal.signal.type == "virtual" and "virtual-signal" or signal.signal.type
  local mask = signal.count
  local formatted_mask = masking.format(mask, player)
  local rich = "[" .. rich_type .. "=" .. signal.signal.name .. "] " .. formatted_mask
  log:debug("result rich text: ", rich)

  state.combinator:add_or_update_network_signal(signal)
  refresh_network_list(player, state)

  state.network_mask.signal_button.elem_value = nil
  state.network_mask.signal = nil
  state.network_mask.add_button.enabled = false
end

--- @param event EventData.on_gui_click
local function handle_close(event)
  log:debug("close button clicked")
  cc_gui:close(event.player_index)
end

--- @param event EventData.on_gui_switch_state_changed
local function handle_on_off(event)
  local element = event.element
  if not element then return end
  local enabled = element.switch_state == "right"
  local state = get_player_state(event.player_index)
  if not state then return end
  log:debug("combinator switch changed to ", enabled)
  state.combinator:set_enabled(enabled)
  local status = state.entity.status
  local is_ghost = state.entity.name == "entity-ghost"
  state.status_sprite.sprite = is_ghost and GHOST_STATUS_SPRITE or STATUS_SPRITES[status] or DEFAULT_STATUS_SPRITE
  state.status_label.caption = is_ghost and GHOST_STATUS_NAME or STATUS_NAMES[status] or DEFAULT_STATUS_NAME
end

--- @param event EventData.on_gui_elem_changed
local function handle_signal_changed(event)
  local element = event.element
  local state = get_player_state(event.player_index)
  if not state then return end
  local slot = element.tags.slot --[[@as uint]]
  local signal = { signal = element.elem_value, count = 0 }
  if not signal.signal then return end
  if not cc_util.is_valid_output_signal(signal) then
    element.elem_value = nil
    element.style = "flib_slot_button_default"
    local player = game.get_player(event.player_index)
    if not player then return end
    player.play_sound { path = constants.CANNOT_BUILD_SOUND }
    player.print({ "cybersyn-combinator-window.invalid-signal" })
    return
  end
  local is_dupe, orig_slot = state.combinator:has_item_signal(signal.signal, slot)
  if is_dupe then
    element.elem_value = nil
    element.style = "flib_slot_button_default"
    local player = game.get_player(event.player_index)
    if not player then return end
    player.play_sound { path = constants.CANNOT_BUILD_SOUND }
    player.create_local_flying_text({ text = { "gui-logistic-section.conflict-error", orig_slot }, create_at_cursor = true })
    player.print({ "gui-logistic-section.conflict-error", orig_slot })
    return
  end
  log:debug("elem changed, slot ", slot, ": ", serpent.line(element.elem_value))
  if state.selected_slot_button then
    state.selected_slot_button.style = "flib_slot_button_default"
  end
  state.selected_slot = slot
  state.selected_slot_button = element
  state.combinator:set_item_slot(slot, signal)
  element.locked = true
  element.style = "flib_selected_slot_button_default"
  change_signal_count(state, {
    button = defines.mouse_button_type.left,
    element = { number = 0 },
    player_index = event.player_index
  })
end

--- @param event EventData.on_gui_click
local function handle_signal_click(event)
  local element = event.element
  local state = get_player_state(event.player_index)
  if not state then return end
  local slot = element.tags.slot --[[@as uint]]
  log:debug("signal click on slot ", slot, ": ", element.elem_value)

  if event.button == defines.mouse_button_type.right then
    state.combinator:remove_item_slot(slot)
    element.locked = false
    element.elem_value = nil
    element.label.caption = ""
    element.style = "flib_slot_button_default"
    if state.selected_slot == slot then
      state.signal_value_stacks.enabled = false
      state.signal_value_items.enabled = false
      state.signal_value_confirm.enabled = false
    end
  elseif event.button == defines.mouse_button_type.left and element.elem_value then
    if state.selected_slot_button then
      state.selected_slot_button.style = "flib_slot_button_default"
    end
    state.selected_slot = slot
    state.selected_slot_button = element
    element.style = "flib_selected_slot_button_default"
    change_signal_count(state, event)
  end
end

--- @param event EventData.on_gui_text_changed
local function handle_signal_value_changed(event)
  local element = event.element
  local state = get_player_state(event.player_index)
  if not state then return end
  local value = resolve_textfield_number(element, event.player_index)
  if not value then
    state.signal_value_confirm.enabled = false
    return
  end
  log:debug("value of ", element.name, " changed to : ", value)
  state.signal_value_confirm.enabled = true
  if element.name == "signal_value_items" then
    local stack_size = state.stack_size
    if state.stack_size == nil then
      -- Try to recover stack size
      if state.selected_slot == nil then
        log:error("Unexpected nil values in handle_signal_value_changed while handling change in ", element.name, " please tell a developer")
        return
      end
      log:warn("stack size for current selection unexpectedly nil")
      local combi_sig = state.combinator:get_item_slot(state.selected_slot)
      if combi_sig.signal.type == "item" then
        stack_size = prototypes.item[combi_sig.signal.name].stack_size
      else
        stack_size = 1
      end
    end
    local stack = value / stack_size
    state.signal_value_stacks.text = tostring(stack >= 0 and ceil(stack) or floor(stack))
  elseif element.name == "signal_value_stacks" then
    state.signal_value_items.text = tostring(value * state.stack_size)
  end
end

--- @param event EventData.on_gui_confirmed
local function handle_signal_value_confirmed(event)
  local state = get_player_state(event.player_index)
  if not state or not state.selected_slot then return end
  local slot_button = state.selected_slot_button
  if slot_button then slot_button.style = "flib_slot_button_default" end
  local current = state.combinator:get_item_slot(state.selected_slot)
  local value = resolve_textfield_number(state.signal_value_items, event.player_index, current.count or 0)
  if not value then
    if current and current.count then
      state.signal_value_items.text = tostring(current.count)
      if state.stack_size then
        local stacks = current.count / state.stack_size
        state.signal_value_stacks.text = tostring(stacks >= 0 and ceil(stacks) or floor(stacks))
      end
    end
    state.signal_value_confirm.enabled = false
    return
  end
  set_new_signal_value(event.player_index, state, value, true)
end

--- @param player_index integer
--- @param state UiState?
--- @param clear_selected boolean
local function confirm_signal_value(player_index, state, clear_selected)
  if not state or not state.selected_slot then return end
  local slot_button = state.selected_slot_button
  if slot_button then slot_button.style = "flib_slot_button_default" end
  local current = state.combinator:get_item_slot(state.selected_slot)
  local value = resolve_textfield_number(state.signal_value_items, player_index, current.count or 0)
  if not value then
    state.signal_value_confirm.enabled = false
    return
  end
  set_new_signal_value(player_index, state, value, clear_selected)
end

--- @param event EventData.on_gui_click
local function handle_signal_value_confirm(event)
  local state = get_player_state(event.player_index)
  confirm_signal_value(event.player_index, state, true)
  -- if not state or not state.selected_slot then return end
  -- local slot_button = state.selected_slot_button
  -- if slot_button then slot_button.style = "flib_slot_button_default" end
  -- local current = state.combinator:get_item_slot(state.selected_slot)
  -- local value = resolve_textfield_number(state.signal_value_items, event.player_index, current.count or 0)
  -- if not value then
  --   state.signal_value_confirm.enabled = false
  --   return
  -- end
  -- set_new_signal_value(event.player_index, state, value)
end

--- @param event EventData.on_gui_text_changed
local function handle_cs_signal_value_changed(event)
  local element = event.element
  if not element then return end
  set_cs_signal_value(element, event.player_index, false)
end

--- @param event EventData.on_gui_confirmed
local function handle_cs_signal_value_confirmed(event)
  local element = event.element
  if not element then return end
  set_cs_signal_value(element, event.player_index, true)
end

--- @param event EventData.on_gui_click
local function handle_cs_signal_reset(event)
  local element = event.element
  if not element then return end
  local state = get_player_state(event.player_index)
  if not state then return end
  local name = element.tags.signal_name --[[@as string?]]
  if not name then return end
  local cs_signal = config.cs_signals[name]
  if not cs_signal then return end
  local field = state[name]
  if not field then return end
  state.combinator:reset_cs_value(name)
  field.text = tostring(cs_signal.default)
  element.enabled = false
end

--- @param event EventData.on_gui_elem_changed
--- @param on_failure function
--- @return Signal|false
local function handle_mask_signal_changed(event, on_failure)
  local state = get_player_state(event.player_index)
  if not state then return false end
  local element = event.element
  if not element then return false end
  --- @type Signal
  local signal = { signal = element.elem_value --[[@as SignalID]], count = 0 }
  if not signal.signal then
    on_failure()
    return false
  end
  if not cc_util.is_valid_output_signal(signal) then
    event.element.elem_value = nil
    on_failure()
    local player = game.get_player(event.player_index)
    if not player then return false end
    player.print({ "cybersyn-combinator-window.invalid-signal" })
    return false
  end
  if signal.signal.type ~= "virtual" then
    event.element.elem_value = nil
    on_failure()
    log:info("attempt to use non-virtual signal as network mask")
    local player = game.get_player(event.player_index)
    if not player then return false end
    player.print { "cybersyn-combinator-window.non-virtual-network-mask", signal.signal.type, signal.signal.name }
    return false
  end
  return signal
end

--- @param event EventData.on_gui_elem_changed
local function handle_network_mask_signal_changed(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  -- local element = event.element
  -- if not element then return end
  -- --- @type Signal
  -- local signal = { signal = element.elem_value --[[@as SignalID]], count = 0 }
  -- if not signal.signal then
  --   state.network_mask.signal = nil
  --   state.network_mask.add_button.enabled = false
  --   return
  -- end
  -- if not cc_util.is_valid_output_signal(signal) then
  --   event.element.elem_value = nil
  --   state.network_mask.signal = nil
  --   state.network_mask.add_button.enabled = false
  --   local player = game.get_player(event.player_index)
  --   if not player then return end
  --   player.print({ "cybersyn-combinator-window.invalid-signal" })
  --   return
  -- end
  -- if signal.signal.type ~= "virtual" then
  --   event.element.elem_value = nil
  --   state.network_mask.signal = nil
  --   state.network_mask.add_button.enabled = false
  --   log:info("attempt to use non-virtual signal as network mask")
  --   local player = game.get_player(event.player_index)
  --   if not player then return end
  --   player.print { "cybersyn-combinator-window.non-virtual-network-mask", signal.signal.type, signal.signal.name }
  --   return
  -- end
  local signal = handle_mask_signal_changed(event, function()
    state.network_mask.signal = nil
    state.network_mask.add_button.enabled = false
  end)
  if not signal then return end
  state.network_mask.signal = signal
  log:debug("network signal changed to ", serpent.block(signal))
  --- @type integer?
  local new_count = nil
  local use_cs_default = settings.get_player_settings(event.player_index)[constants.SETTINGS.NETWORK_MASK_USE_CS_DEFAULT].value
  local cs_default = settings.global[constants.SETTINGS.CS_NETWORK_FLAG].value
  if use_cs_default and cs_default ~= nil then
    new_count = cs_default --[[@as integer]]
  elseif state.network_mask.mask then
    new_count = state.network_mask.mask
  end
  if new_count ~= nil then
    signal.count = new_count
    state.network_mask.textfield.text = masking.format_for_input(new_count, event.player_index)
    state.network_mask.add_button.enabled = true
  else
    state.network_mask.add_button.enabled = false
  end

  focus_network_mask_input(state)
end

--- @param event EventData.on_gui_click
local function handle_network_mask_signal_click(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  if event.button == defines.mouse_button_type.right then
    state.network_mask.signal = nil
    state.network_mask.add_button.enabled = false
  end
end

--- @param event EventData.on_gui_text_changed
local function handle_network_mask_changed(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local text = event.element.text
  local mask = masking.parse(text, event.player_index)
  if state.network_mask.signal then state.network_mask.signal.count = mask end
  if mask == 0 then
    state.network_mask.mask = nil
    state.network_mask.add_button.enabled = false
    return
  end
  state.network_mask.mask = mask
  state.network_mask.add_button.enabled = state.network_mask.signal ~= nil
end

--- @param event EventData.on_gui_confirmed
local function handle_network_mask_confirmed(event)
  local state = get_player_state(event.player_index)
  add_network_mask(event.player_index, state)
end

--- @param event EventData.on_gui_click
local function handle_network_mask_add_click(event)
  local state = get_player_state(event.player_index)
  add_network_mask(event.player_index, state)
end

--- @param event EventData.on_gui_click
local function handle_dialog_close(event)
  log:debug("dialog close button clicked")
  local player = game.get_player(event.player_index)
  local state = get_player_state(event.player_index)
  if not state then return end
  if state.main_window then
    player.opened = state.main_window
  end
end

--- @param player_index integer
---@param close boolean
local function confirm_encoder(player_index, close)
  local state = get_player_state(player_index)
  if not state then return end
  state.network_mask.signal.signal = state.encoder.signal_button.elem_value --[[@as SignalID]]
  state.network_mask.signal.count = masking.uint_to_int(state.encoder.mask)
  add_network_mask(player_index, state)
  if not close then return end
  local player = game.get_player(player_index)
  if player and state.main_window then
    player.opened = state.main_window
  end
end

--- @param player_index integer
--- @param close boolean
local function confirm_description(player_index, close)
  local state = get_player_state(player_index)
  if not state then return end
  local description = state.description_edit.textfield.text
  state.combinator:set_description(description)
  state.description_label.caption = description
  local has_description = description ~= ""
  state.add_description_button.visible = not has_description
  state.description_header.visible = has_description
  state.description_scroll.visible = has_description
  if not close then return end
  local player = game.get_player(player_index)
  if player and state.main_window then
    player.opened = state.main_window
  end
end

--- @param event EventData.on_gui_click
local function handle_encoder_confirm(event)
  log:debug("encoder confirm button clicked")
  confirm_encoder(event.player_index, true)
end

--- @param event EventData.on_gui_click
local function handle_description_edit_confirm(event)
  log:debug("description edit confirm button clicked")
  confirm_description(event.player_index, true)
end

--- @param player_index integer
--- @param state UiState
--- @param update_textfield boolean
local function refresh_encoder(player_index, state, update_textfield)
  state.encoder.confirm_button.enabled = state.encoder.signal_button.elem_value ~= nil
  if not state.encoder.bit_buttons then return end
  local mask = state.encoder.mask
  if not mask then return end
  if update_textfield then
    state.encoder.textfield.text = masking.format_for_input(mask, player_index)
  end
  state.encoder.display_dec.caption = masking.format_explicit(mask, masking.Mode.DECIMAL, false, true)
  state.encoder.display_hex.caption = masking.format_explicit(mask, masking.Mode.HEX, false, true)
  state.encoder.display_bin.caption = masking.format_explicit(mask, masking.Mode.BINARY, false, true)
  state.encoder.display_oct.caption = masking.format_explicit(mask, masking.Mode.OCTAL, false, true)
  for i, button in ipairs(state.encoder.bit_buttons.children) do
    local bit_index = i - 1
    local bit_value = bit32.extract(state.encoder.mask, bit_index)
    if bit_value == 1 then
      button.style = BIT_BUTTON_PRESSED_STYLE
    else
      button.style = BIT_BUTTON_STYLE
    end
  end
end

--- @param event EventData.on_gui_elem_changed
local function handle_encoder_signal_changed(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local signal = handle_mask_signal_changed(event, function()
    state.encoder.signal_button.elem_value = nil
  end)
  refresh_encoder(event.player_index, state, true)
  if not signal then return end
  state.encoder.textfield.focus()
  state.encoder.textfield.select_all()
end

--- @param event EventData.on_gui_click
local function handle_encoder_signal_click(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  refresh_encoder(event.player_index, state, true)
end

--- @param event EventData.on_gui_text_changed
local function handle_encoder_mask_changed(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local text = event.element.text
  local mask = masking.parse(text, event.player_index)
  state.encoder.mask = mask
  refresh_encoder(event.player_index, state, false)
end

-- --- @param event EventData.on_gui_confirmed
-- local function handle_encoder_mask_confirmed(event)
--   local state = get_player_state(event.player_index)
--   if not state then return end
-- end

--- @param event EventData.on_gui_click
local function handle_encoder_bit_button_click(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local index = event.element.tags.index
  local bit_index = event.element.tags.bit_index --[[@as integer]]
  state.encoder.mask = bit32.bxor(state.encoder.mask, bit32.lshift(1, bit_index))
  log:debug("Pressed bit button ", index, " (bit ", bit_index, ")")
  refresh_encoder(event.player_index, state, true)
end

--- @param event EventData.on_gui_click
local function handle_encoder_all(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  state.encoder.mask = 0xFFFFFFFF
  refresh_encoder(event.player_index, state, true)
end

--- @param event EventData.on_gui_click
local function handle_encoder_none(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  state.encoder.mask = 0
  refresh_encoder(event.player_index, state, true)
end

--- @param event EventData.on_gui_click
local function handle_dimmer_click(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  destroy(player, DIMMER_ID)
  if state.main_window then
    player.opened = state.main_window
  end
end

--- @param player_index integer
local function create_dimmer(player_index)
  local player = game.get_player(player_index)
  if not player then return end
  local screen = player.gui.screen
  if screen[DIMMER_ID] then
    log:debug("dimmer already exists")
    return
  end
  local _, dimmer = flib_gui.add(screen, {
    type = "frame",
    name = DIMMER_ID,
    style = "invisible_frame",
    style_mods = {
      natural_width = 1000000,
      natural_height = 1000000,
      padding = 0,
      use_header_filler = false
    },
    handler = {
      [defines.events.on_gui_click] = handle_dimmer_click
    }
  })
  dimmer.location = { 0, 0 }
  local state = get_player_state(player_index)
  if state then state.dimmer = dimmer end
end

--- @param player_index integer
--- @param state UiState
local function create_encoder(player_index, state)
  local player = game.players[player_index]
  local screen = player.gui.screen
  local signal = state.network_mask.signal
  if not signal then
    return
  end
  create_dimmer(player_index)
  local named, dialog = flib_gui.add(screen, {
    {
      type = "frame",
      direction = "vertical",
      name = ENCODER_ID,
      tags = {
        unit_number = state.entity.unit_number
      },
      style_mods = {
        -- minimal_width = 240
        width = 450
      },
      children = {
        {
          type = "flow",
          direction = "horizontal",
          drag_target = ENCODER_ID,
          tooltip = { "cybersyn-combinator-encoder.tooltip" },
          children = {
            {
              type = "label",
              style = "frame_title",
              caption = {
                "",
                { "cybersyn-combinator-encoder.title" },
                " [img=info]"
              },
              tooltip = { "cybersyn-combinator-encoder.tooltip" },
              elem_mods = { ignored_by_interaction = true }
            },
            {
              type = "empty-widget",
              style = "flib_titlebar_drag_handle",
              elem_mods = { ignored_by_interaction = true }
            }
          }
        },
        {
          type = "frame",
          direction = "vertical",
          style = "inside_shallow_frame_with_padding",
          style_mods = {
            horizontally_stretchable = true,
            vertically_stretchable = true,
            horizontal_align = "center",
            padding = 8
          },
          children = {
            { -- Signal and text field
              type = "flow",
              direction = "horizontal",
              style_mods = {
                vertical_align = "center",
                bottom_margin = 4
              },
              children = {
                {
                  type = "flow",
                  style_mods = { horizontally_stretchable = true }
                },
                {
                  type = "choose-elem-button",
                  name = "encoder_signal_button",
                  elem_type = "signal",
                  style_mods = { width = 48, height = 48 },
                  handler = {
                    [defines.events.on_gui_elem_changed] = handle_encoder_signal_changed,
                    [defines.events.on_gui_click] = handle_encoder_signal_click
                  }
                },
                {
                  type = "textfield",
                  name = "encoder_mask_textfield",
                  style = "cybersyn-combinator_network-mask-text-input",
                  style_mods = { left_margin = 8, width = 200 },
                  numeric = false,
                  clear_and_focus_on_right_click = true,
                  lose_focus_on_confirm = true,
                  handler = {
                    [defines.events.on_gui_text_changed] = handle_encoder_mask_changed
                    -- [defines.events.on_gui_confirmed] = handle_encoder_mask_confirmed
                  }
                },
                {
                  type = "flow",
                  style_mods = { horizontally_stretchable = true }
                },
              }
            },
            { -- Bit buttons
              type = "flow",
              direction = "vertical",
              style_mods = {
                horizontally_stretchable = true,
                horizontal_align = "center",
                top_margin = 4,
                bottom_margin = 4
              },
              children = {
                {
                  type = "table",
                  name = "bit_buttons",
                  column_count = 8
                }
              }
            },
            { -- All/None buttons
              type = "flow",
              direction = "horizontal",
              style_mods = {
                horizontally_stretchable = true,
                horizontal_align = "center",
                top_margin = 4,
                bottom_margin = 4
              },
              children = {
                {
                  type = "button",
                  caption = { "cybersyn-combinator-encoder.all" },
                  handler = handle_encoder_all
                },
                {
                  type = "button",
                  caption = { "cybersyn-combinator-encoder.none" },
                  handler = handle_encoder_none
                }
              }
            },
            {
              type = "table",
              name = "mask_display_table",
              column_count = 2,
              style_mods = {
                horizontally_stretchable = true
              },
              children = {
                {
                  type = "label",
                  caption = { "cybersyn-combinator-encoder.decimal" }
                },
                {
                  type = "flow",
                  direction = "vertical",
                  style_mods = {
                    horizontally_stretchable = true,
                    horizontal_align = "right"
                  },
                  children = {
                    {
                      type = "label",
                      name = "display_dec",
                      style_mods = {
                        horizontal_align = "right",
                        horizontally_stretchable = true
                      }
                    }
                  }
                },
                {
                  type = "label",
                  caption = { "cybersyn-combinator-encoder.hexadecimal" }
                },
                {
                  type = "flow",
                  direction = "vertical",
                  style_mods = {
                    horizontally_stretchable = true,
                    horizontal_align = "right"
                  },
                  children = {
                    {
                      type = "label",
                      name = "display_hex",
                      style_mods = {
                        horizontal_align = "right",
                        horizontally_stretchable = true
                      }
                    }
                  }
                },
                {
                  type = "label",
                  caption = { "cybersyn-combinator-encoder.binary" }
                },
                {
                  type = "flow",
                  direction = "vertical",
                  style_mods = {
                    horizontally_stretchable = true,
                    horizontal_align = "right"
                  },
                  children = {
                    {
                      type = "label",
                      name = "display_bin",
                      style_mods = {
                        horizontal_align = "right",
                        horizontally_stretchable = true
                      }
                    }
                  }
                },
                {
                  type = "label",
                  caption = { "cybersyn-combinator-encoder.octal" }
                },
                {
                  type = "flow",
                  direction = "vertical",
                  style_mods = {
                    horizontally_stretchable = true,
                    horizontal_align = "right"
                  },
                  children = {
                    {
                      type = "label",
                      name = "display_oct",
                      style_mods = {
                        horizontal_align = "right",
                        horizontally_stretchable = true
                      }
                    }
                  }
                }
              }
            }
          }
        },
        {
          type = "flow",
          direction = "horizontal",
          style_mods = {
            horizontal_spacing = 0
          },
          children = {
            {
              type = "button",
              style = "back_button",
              caption = { "gui.cancel" },
              name = ENCODER_ID .. "_close",
              handler = handle_dialog_close
            },
            {
              type = "empty-widget",
              style = "flib_dialog_footer_drag_handle",
              drag_target = ENCODER_ID
            },
            {
              type = "button",
              name = "confirm_button",
              style = "confirm_button",
              caption = { "gui.confirm" },
              tooltip = nil,
              handler = handle_encoder_confirm
            }
          }
        }
      }
    }
  })
  local bit_buttons = named.bit_buttons
  state.encoder = {
    mask = state.network_mask.mask,
    dialog = dialog,
    signal_button = named.encoder_signal_button,
    textfield = named.encoder_mask_textfield,
    bit_buttons = bit_buttons,
    display_dec = named.display_dec,
    display_hex = named.display_hex,
    display_bin = named.display_bin,
    display_oct = named.display_oct,
    confirm_button = named.confirm_button
  }
  state.encoder.signal_button.elem_value = signal.signal
  state.encoder.textfield.text = masking.format_for_input(signal.count, player_index)
  local settings = settings.get_player_settings(player_index)
  local zeroIndex = settings[constants.SETTINGS.ENCODER_ZERO_INDEX].value
  for i = 1, 32 do
    local bit_index = i - 1
    local is_active = bit32.extract(state.encoder.mask, bit_index) == 1
    local bb_style = bit_button_style(is_active)
    flib_gui.add(bit_buttons, {
      type = "sprite-button",
      caption = tostring(zeroIndex and bit_index or i),
      style = bb_style,
      mouse_button_filter = { "left" },
      tags = {
        index = i,
        bit_index = bit_index
      },
      handler = handle_encoder_bit_button_click
    })
  end
  refresh_encoder(player_index, state, true)
  dialog.force_auto_center()
  -- state.main_window.visible = false
  player.opened = dialog
end

---@param player_index integer
---@param state UiState
local function create_description_edit(player_index, state)
  local player = game.players[player_index]
  local screen = player.gui.screen
  create_dimmer(player_index)
  local named, dialog
  do
    named, dialog = flib_gui.add(screen, {
      name = DESC_EDIT_ID,
      type = "frame",
      style = "inset_frame_container_frame",
      direction = "vertical",
      style_mods = {
        width = 400,
        maximal_height = 1290
      },
      children = {
        { -- Titlebar
          type = "flow",
          direction = "horizontal",
          drag_target = DESC_EDIT_ID,
          style = "frame_header_flow",
          style_mods = {
            vertically_stretchable = false
          },
          children = {
            {
              type = "label",
              style = "frame_title",
              caption = { "gui-edit-label.edit-description" },
              drag_target = DESC_EDIT_ID,
              style_mods = {
                vertically_stretchable = true,
                horizontally_squashable = true,
                top_margin = -3,
                bottom_padding = 3
              }
            },
            {
              type = "empty-widget",
              style = "draggable_space_header",
              drag_target = DESC_EDIT_ID,
              style_mods = {
                height = 24,
                natural_height = 24,
                horizontally_stretchable = true,
                vertically_stretchable = true
              }
            },
            {
              type = "sprite-button",
              style = "cancel_close_button",
              name = DESC_EDIT_ID .. "_close",
              sprite = "utility/close",
              handler = {
                [defines.events.on_gui_click] = handle_dialog_close
              }
            }
          }
        },
        { -- Content
          type = "flow",
          direction = "vertical",
          style = "inset_frame_container_vertical_flow",
          style_mods = {
            horizontal_align = "right",
            top_margin = -12
          },
          children = {
            {
              type = "text-box",
              name = "description",
              style = "edit_blueprint_description_textbox",
              style_mods = {
                horizontally_stretchable = true
              },
              text = state.combinator:get_description(),
              icon_selector = true
            },
            {
              type = "flow",
              style = "horizontal_flow",
              direction = "horizontal",
              children = {
                {
                  type = "empty-widget",
                  style = "draggable_space",
                  style_mods = {
                    left_margin = 0,
                    horizontally_stretchable = true,
                    vertically_stretchable = true
                  },
                  drag_target = DESC_EDIT_ID
                },
                {
                  type = "button",
                  style = "confirm_button",
                  caption = { "gui-edit-label.save-description" },
                  handler = {
                    [defines.events.on_gui_click] = handle_description_edit_confirm
                  }
                }
              }
            }
          }
        }
      }
    })
  end

  ---@type DescriptionEditState
  state.description_edit = {
    dialog = dialog,
    textfield = named.description
  }

  dialog.force_auto_center()
  named.description.focus()
  player.opened = dialog
end

--- @param event EventData.on_gui_click
handle_network_list_item_click = function(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local element = event.element
  if not element then return end
  local slot = element.tags.slot --[[@as uint?]]
  if not slot then return end
  log:debug("clicked on network list button for slot ", slot, " with button ", event.button)
  if event.button == defines.mouse_button_type.right then
    state.combinator:remove_network_slot(slot)
    refresh_network_list(event.player_index, state)
    log:debug("removed network signal at slot ", slot)
    return
  end
  if event.button ~= defines.mouse_button_type.left then return end
  local signal = state.combinator:get_network_slot(slot)
  if not signal then return end
  state.network_mask.signal = signal
  state.network_mask.mask = signal.count
  state.network_mask.slot = slot
  if event.control then
    log:debug("Showing network encoder!")
    create_encoder(event.player_index, state)
  else
    state.network_mask.signal_button.elem_value = signal.signal
    state.network_mask.textfield.text = masking.format_for_input(signal.count, event.player_index)
    state.network_mask.add_button.enabled = true
    focus_network_mask_input(state)
  end
end

--- @param event EventData.on_gui_click
local function handle_description_edit_click(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  log:debug("Showing description editor")
  create_description_edit(event.player_index, state)
end

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @return UiState
local function create_window(player, entity)
  local screen = player.gui.screen

  local network_list_width = 200
  local description_width = 640

  if settings.get_player_settings(player)[constants.SETTINGS.NETWORK_MASK_DISPLAY_MODE].value == "BINARY" then
    network_list_width = 340
    description_width = 780
  end

  local enable_expressions = settings.get_player_settings(player)[constants.SETTINGS.ENABLE_EXPRESSIONS].value == true

  local named, main_window

  do
    local titlebar = {
      type = "flow",
      drag_target = WINDOW_ID,
      children = {
        {
          type = "label",
          style = "frame_title",
          caption = { "cybersyn-combinator-window.title" },
          elem_mods = { ignored_by_interaction = true },
          style_mods = {
            maximal_width = 600
          }
        },
        {
          type = "empty-widget",
          style = "flib_titlebar_drag_handle",
          elem_mods = { ignored_by_interaction = true }
        },
        {
          type = "sprite-button",
          style = "close_button",
          mouse_button_filter = { "left" },
          sprite = "utility/close",
          name = WINDOW_ID .. "_close",
          handler = handle_close
        }
      }
    }

    local network_list = { -- Network list
      type = "frame",
      style = "deep_frame_in_shallow_frame",
      style_mods = { width = network_list_width, vertically_stretchable = true },
      direction = "vertical",
      children = {
        {
          type = "frame",
          style = "subheader_frame",
          direction = "vertical",
          style_mods = { horizontally_stretchable = true, maximal_height = 90 },
          children = {
            {
              type = "flow",
              direction = "horizontal",
              style_mods = { left_padding = 8 },
              children = {
                {
                  type = "label",
                  style = "caption_label",
                  caption = {
                    "",
                    { "cybersyn-combinator-window.network-list-title" },
                    " [img=info]"
                  },
                  tooltip = { "cybersyn-combinator-window.network-list-tooltip" }
                },
                {
                  type = "empty-widget",
                  style = "flib_horizontal_pusher"
                }
              }
            },
            {
              type = "flow",
              direction = "horizontal",
              style_mods = { left_padding = 3, right_padding = 3 },
              children = {
                {
                  type = "choose-elem-button",
                  name = "network_mask_signal_button",
                  elem_type = "signal",
                  style_mods = { width = 32, height = 32 },
                  handler = {
                    [defines.events.on_gui_elem_changed] = handle_network_mask_signal_changed,
                    [defines.events.on_gui_click] = handle_network_mask_signal_click
                  }
                },
                {
                  type = "textfield",
                  name = "network_mask_textfield",
                  style = "cybersyn-combinator_network-mask-text-input",
                  style_mods = { horizontally_stretchable = true, minimal_width = 50, maximal_width = 300 },
                  text = "",
                  numeric = false,
                  clear_and_focus_on_right_click = true,
                  lose_focus_on_confirm = true,
                  handler = {
                    [defines.events.on_gui_text_changed] = handle_network_mask_changed,
                    [defines.events.on_gui_confirmed] = handle_network_mask_confirmed
                  }
                },
                {
                  type = "sprite-button",
                  name = "network_mask_add_button",
                  sprite = "utility/check_mark",
                  style = "flib_tool_button_light_green",
                  enabled = false,
                  mouse_button_filter = { "left" },
                  handler = {
                    [defines.events.on_gui_click] = handle_network_mask_add_click
                  }
                }
              }
            }
          }
        },
        {
          type = "scroll-pane",
          name = "network_list",
          style = "cybersyn-combinator_network-list_scroll-pane",
          vertical_scroll_policy = "auto"
        }
      }
    }

    local status_and_preview = {
      type = "flow",
      direction = "vertical",
      style_mods = { horizontal_align = "left" },
      children = {
        {                   -- Status
          type = "flow",
          direction = "horizontal",
          style_mods = { vertical_align = "center", horizontally_stretchable = true, bottom_padding = 4 },
          children = {
            {
              type = "sprite",
              name = "status_sprite",
              sprite = entity.name == "entity-ghost" and GHOST_STATUS_SPRITE or STATUS_SPRITES[entity.status] or
              DEFAULT_STATUS_SPRITE,
              style = "status_image",
              style_mods = { stretch_image_to_widget_size = true }
            },
            {
              type = "label",
              name = "status_label",
              caption = entity.name == "entity-ghost" and GHOST_STATUS_NAME or STATUS_NAMES[entity.status] or
              DEFAULT_STATUS_NAME
            }
          }
        },
        {                   -- Preview
          type = "frame",
          style = "deep_frame_in_shallow_frame",
          style_mods = { minimal_width = 0, horizontally_stretchable = true, padding = 0 },
          children = {
            {
              type = "entity-preview",
              name = "preview",
              style = "wide_entity_button",
              style_mods = {
                width = 128,
                height = 128,
                horizontally_stretchable = true
              }
            }
          }
        }
      }
    }

    local cs_signals_pane = { -- CS signal pane
      type = "flow",
      direction = "vertical",
      style_mods = { top_margin = 25, left_padding = 8, width = 300, horizontal_align = "center", vertically_stretchable = true },
      children = {
        {
          type = "table",
          name = "cs_signals_table",
          column_count = 4,
          style_mods = { cell_padding = 2, horizontally_stretchable = true, vertical_align = "center" }
        }
      }
    }

    local on_off = { -- On/off switch
      type = "flow",
      style_mods = {
        horizontal_align = "left",
        maximal_width = 110
      },
      direction = "vertical",
      children = {
        {
          type = "label",
          style = "semibold_label",
          caption = { "gui-constant.output" }
        },
        {
          type = "switch",
          name = "on_off",
          handler = {
            [defines.events.on_gui_switch_state_changed] = handle_on_off
          },
          left_label_caption = { "gui-constant.off" },
          right_label_caption = { "gui-constant.on" }
        }
      }
    }

    local request_totals = {                   -- Request totals
      type = "flow",
      style_mods = {
        horizontal_align = "right",
        horizontally_stretchable = true,
        left_margin = 10
      },
      direction = "horizontal",
      children = {
        {
          type = "flow",
          direction = "vertical",
          style_mods = { maximal_width = 105 },
          children = {
            {
              type = "label",
              style = "semibold_label",
              caption = {
                "",
                { "cybersyn-combinator-window.item-total" },
                " [img=info]"
              },
              tooltip = { "cybersyn-combinator-window.item-total-description" }
            },
            {
              type = "label",
              name = "item_total",
              style_mods = { minimal_width = 80 },
              caption = "0",
              tooltip = "0"
            }
          }
        },
        {
          type = "flow",
          direction = "vertical",
          style_mods = { maximal_width = 105 },
          children = {
            {
              type = "label",
              style = "semibold_label",
              caption = {
                "",
                { "cybersyn-combinator-window.item-stacks" },
                " [img=info]"
              },
              tooltip = { "cybersyn-combinator-window.item-stacks-description" }
            },
            {
              type = "label",
              name = "item_stacks",
              style_mods = { minimal_width = 80 },
              caption = "0",
              tooltip = "0"
            }
          }
        },
        {
          type = "flow",
          direction = "vertical",
          style_mods = { maximal_width = 105 },
          children = {
            {
              type = "label",
              style = "semibold_label",
              caption = {
                "",
                { "cybersyn-combinator-window.fluid-total" },
                " [img=info]"
              },
              tooltip = { "cybersyn-combinator-window.fluid-total-description" }
            },
            {
              type = "label",
              name = "fluid_total",
              style_mods = { minimal_width = 80 },
              caption = "0",
              tooltip = "0"
            }
          }
        }
      }
    }

    local signals_container = { -- Signals container
      type = "flow",
      direction = "vertical",
      style_mods = { top_margin = 4, horizontal_align = "center", horizontally_stretchable = true },
      children = {
        {
          type = "frame",
          direction = "vertical",
          style = "slot_button_deep_frame",
          style_mods = { horizontal_align = "center" },
          children = {
            {
              type = "table",
              style = "slot_table",
              name = "signal_table",
              -- style_mods = { minimal_height = 80 },
              column_count = config.slot_cols
            }
          }
        },
        {
          type = "flow",
          direction = "horizontal",
          style_mods = { horizontal_align = "right" },
          children = {
            {
              type = "label",
              style_mods = { top_margin = 5 },
              caption = { "cybersyn-combinator-window.stacks" }
            },
            {
              type = "textfield",
              name = "signal_value_stacks",
              enabled = false,
              style_mods = { horizontal_align = "right", horizontally_stretchable = false, width = 100 },
              lose_focus_on_confirm = true,
              clear_and_focus_on_right_click = true,
              text = "0",
              numeric = not enable_expressions,
              allow_decimal = false,
              allow_negative = true,
              handler = {
                [defines.events.on_gui_text_changed] = handle_signal_value_changed,
                [defines.events.on_gui_confirmed] = handle_signal_value_confirmed
              },
              tags = {
                allow_decimal = true,
                allow_negative = true,
                min = constants.INT32_MIN,
                max = constants.INT32_MAX
              }
            },
            {
              type = "label",
              style_mods = { top_margin = 5 },
              caption = { "cybersyn-combinator-window.items" }
            },
            {
              type = "textfield",
              name = "signal_value_items",
              enabled = false,
              style_mods = { horizontal_align = "right", horizontally_stretchable = false, width = 100 },
              lose_focus_on_confirm = true,
              clear_and_focus_on_right_click = true,
              text = "0",
              numeric = not enable_expressions,
              allow_decimal = false,
              allow_negative = true,
              handler = {
                [defines.events.on_gui_text_changed] = handle_signal_value_changed,
                [defines.events.on_gui_confirmed] = handle_signal_value_confirmed
              },
              tags = {
                allow_decimal = false,
                allow_negative = true,
                min = constants.INT32_MIN,
                max = constants.INT32_MAX
              }
            },
            {
              type = "sprite-button",
              name = "signal_value_confirm",
              style = "item_and_count_select_confirm",
              sprite = "utility/check_mark",
              enabled = false,
              mouse_button_filter = { "left" },
              handler = {
                [defines.events.on_gui_click] = handle_signal_value_confirm
              }
            }
          }
        }
      }
    }

    local main_view = { -- Main view
      type = "flow",
      direction = "vertical",
      style_mods = { left_margin = 8 },
      children = {
        {           -- status, preview, CS signals
          type = "flow",
          direction = "horizontal",
          children = {
            status_and_preview,           -- Combinator status and preview
            cs_signals_pane
          }
        },
        {
          type = "flow",
          direction = "horizontal",
          style_mods = { top_margin = 8 },
          children = {
            on_off,
            request_totals
          }
        },
        -- Separator
        {
          type = "line",
          style_mods = { top_margin = 5 }
        },
        {
          type = "label",
          style = "semibold_label",
          style_mods = { top_margin = 0 },
          caption = { "gui-constant.output-signals" }
        },
        signals_container
      }
    }

    ---@type string
    local description

    if entity.name == "entity-ghost" then
      if not entity.tags then
        entity.tags = { description = "" }
      end
      description = entity.tags.description or "" --[[@as string]]
    else
      description = entity.combinator_description
    end

    local has_description = description ~= ""

    local description_container = {
      type = "flow",
      direction = "vertical",
      style = "vertical_flow",
      style_mods = {
        -- horizontally_stretchable = true
      },
      children = {
        {
          type = "button",
          name = "add_description_button",
          caption = { "gui-edit-label.add-description" },
          visible = not has_description,
          handler = {
            [defines.events.on_gui_click] = handle_description_edit_click
          }
        },
        {
          type = "flow",
          name = "description_header",
          direction = "horizontal",
          style = "horizontal_flow",
          visible = has_description,
          children = {
            {
              type = "label",
              style = "semibold_label",
              caption = { "description.player-description" }
            },
            {
              type = "sprite-button",
              style = "mini_button_aligned_to_text_vertically",
              sprite = "utility/rename_icon",
              handler = {
                [defines.events.on_gui_click] = handle_description_edit_click
              }
            }
          }
        },
        {
          type = "scroll-pane",
          name = "description_scroll",
          direction = "vertical",
          visible = has_description,
          style = "shallow_scroll_pane",
          style_mods = {
            -- horizontally_stretchable = true
            width = description_width,
            maximal_height = 200
          },
          children = {
            {
              type = "label",
              name = "description_label",
              caption = description,
              style_mods = {
                horizontally_squashable = false,
                -- horizontally_stretchable = true,
                single_line = false
              }
            }
          }
        }
      }
    }

    named, main_window = flib_gui.add(screen, {
      {
        type = "frame",
        direction = "vertical",
        name = WINDOW_ID,
        tags = {
          unit_number = entity.unit_number
        },
        style_mods = {
          maximal_height = 1290
        },
        children = {
          titlebar,
          { -- Content
            type = "frame",
            direction = "vertical",
            style = "entity_frame",
            children = {
              {
                type = "flow",
                direction = "horizontal",
                children = {
                  network_list,
                  main_view
                }
              },
              { type = "line" },
              description_container
            }
          }
        }
      }
    })

  end

  local signal_table = named.signal_table
  if not signal_table then
    error("signal_table is nil")
  end
  local signals = {}
  for i = 1, config.slot_count do
    local _, button = flib_gui.add(signal_table, {
      type = "choose-elem-button",
      name = "cybersyn-combinator_signal-button__" .. i,
      style = "slot_button",
      elem_type = "signal",
      handler = {
        [defines.events.on_gui_elem_changed] = handle_signal_changed,
        [defines.events.on_gui_click] = handle_signal_click
      },
      tags = {
        slot = i
      },
      children = {
        {
          type = "label",
          name = "label",
          style = "cybersyn-combinator_signal-count",
          ignored_by_interaction = true,
          caption = ""
        }
      }
    })

    signals[i] = { button = button }
  end

  local cs_signals_table = named.cs_signals_table
  if not cs_signals_table then
    error("cs_signals_table is nil")
  end
  ---@type UiState
  ---@diagnostic disable-next-line: missing-fields
  local state = {}
  for signal_name, data in pairs(config.cs_signals) do
    local default = settings.global[signal_name].value or data.default
    flib_gui.add(cs_signals_table, {
      type = "sprite",
      style = "cybersyn-combinator_cs-signal-sprite",
      sprite = "virtual-signal/" .. signal_name
    })
    flib_gui.add(cs_signals_table, {
      type = "label",
      style = "cybersyn-combinator_cs-signal-label",
      caption = { "virtual-signal-name." .. signal_name }
    })
    local _, field = flib_gui.add(cs_signals_table, {
      type = "textfield",
      name = "cybersyn-combinator_cs-signal__" .. signal_name,
      style = "cybersyn-combinator_cs-signal-text",
      text = tostring(default),
      numeric = false,
      clear_and_focus_on_right_click = true,
      lose_focus_on_confirm = true,
      handler = {
        [defines.events.on_gui_text_changed] = handle_cs_signal_value_changed,
        [defines.events.on_gui_confirmed] = handle_cs_signal_value_confirmed
      },
      tags = {
        signal_name = signal_name,
        allow_decimal = false,
        allow_negative = data.min < 0,
        min = data.min,
        max = data.max
      }
    })
    local _, reset = flib_gui.add(cs_signals_table, {
      type = "sprite-button",
      style = "cybersyn-combinator_cs-signal-reset",
      sprite = "utility/reset",
      tooltip = { "cybersyn-combinator-window.cs-signal-reset" },
      mouse_button_filter = { "left" },
      handler = {
        [defines.events.on_gui_click] = handle_cs_signal_reset
      },
      tags = {
        signal_name = signal_name
      }
    })
    state[signal_name] = field
    state[signal_name .. "_reset"] = reset
  end

  local preview = named.preview
  preview.entity = entity
  main_window.force_auto_center()

  state.main_window = main_window
  state.status_sprite = named.status_sprite
  state.status_label = named.status_label
  state.entity_preview = preview
  state.on_off = named.on_off
  state.item_total_label = named.item_total
  state.item_stacks_label = named.item_stacks
  state.fluid_total_label = named.fluid_total
  state.signal_value_stacks = named.signal_value_stacks
  state.signal_value_items = named.signal_value_items
  state.signal_value_confirm = named.signal_value_confirm
  state.signals = signals
  state.entity = entity
  state.network_mask = {
    list = named.network_list,
    signal_button = named.network_mask_signal_button,
    textfield = named.network_mask_textfield,
    add_button = named.network_mask_add_button
  }

  state.add_description_button = named.add_description_button
  state.description_header = named.description_header
  state.description_scroll = named.description_scroll
  state.description_label = named.description_label

  return state
end

--- @param player_index uint?
--- @param entity LuaEntity
--- @return boolean
function cc_gui:open(player_index, entity)
  if not player_index then return false end
  local player = game.get_player(player_index)
  if not player then return false end
  if not entity or not entity.valid then return false end
  local screen = player.gui.screen
  if screen[WINDOW_ID] then
    if screen[WINDOW_ID].tags.unit_number == entity.unit_number then
      player.opened = screen[WINDOW_ID]
      return true
    end
    self:close(player_index)
  end
  log:debug("GUI open for entity ", entity.unit_number, ", player index ", player_index)
  local state = create_window(player, entity)

  local combinator = CybersynCombinator:new(entity)
  state.combinator = combinator

  if not combinator then
    log:error("Failed to create combinator object")
  end

  state.on_off.switch_state = combinator:is_enabled() and "right" or "left"

  update_cs_signals(state)
  update_signal_table(state)
  refresh_network_list(player_index, state)

  set_player_state(player_index, state)

  player.opened = state.main_window
  return true
end

--- @param player_index string|uint?
function cc_gui:close(player_index, silent)
  if not player_index then return end
  local player = game.get_player(player_index)
  if not player then return end
  log:debug("GUI close, player index ", player_index)
  local destroyed = destroy(player, WINDOW_ID)
  local player_data = cc_util.get_player_data(player_index)
  if player_data and player_data.state and player_data.state.combinator then
    player_data.state.combinator:validate()
    player_data.state = nil
  end
  if not destroyed then return end
  if not silent then
    player.play_sound { path = constants.ENTITY_CLOSE_SOUND }
  end
end

--- @param event EventData.on_gui_opened
function cc_gui:on_gui_opened(event)
  local entity = event.entity
  if not entity or not entity.valid then return end
  local player_index = event.player_index
  local name = entity.name == "entity-ghost" and entity.ghost_name or entity.name
  if name ~= constants.ENTITY_NAME then
    return
  end
  log:debug("on_gui_opened: opening")
  self:open(player_index, entity)
end

--- @param event EventData.on_gui_closed
function cc_gui:on_gui_closed(event)
  local element = event.element
  if not element then return end
  local player_index = event.player_index
  local player = game.get_player(player_index)
  if not player then return end
  local state = get_player_state(player_index)
  if element.name == ENCODER_ID or element.name == DESC_EDIT_ID then
    destroy(player, element.name)
    destroy(player, DIMMER_ID)
    if state then
      state.encoder = nil
      state.description_edit = nil
      if state.main_window then
        state.main_window.visible = true
        player.opened = state.main_window
      end
    end
    return
  end
  if element.name ~= WINDOW_ID then return end
  if state then
    if state.encoder or state.description_edit then return end
    if state.selected_slot then
      player.opened = state.main_window
      state.selected_slot = nil
      return
    end
  end
  self:close(player_index)
end

--- @param event EventData.CustomInputEvent
function cc_gui:on_input_close(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local screen = player.gui.screen
  if screen[ENCODER_ID] or screen[DESC_EDIT_ID] then return end
  if screen[WINDOW_ID] then self:close(event.player_index, false) end
end

--- @param event EventData.CustomInputEvent
function cc_gui:on_input_confirm(event)
  local state = get_player_state(event.player_index)
  if not state then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local screen = player.gui.screen
  local encoder = screen[ENCODER_ID]
  if encoder and state.encoder then
    confirm_encoder(event.player_index, false)
    return
  end
  local desc_edit = screen[DESC_EDIT_ID]
  if desc_edit and state.description_edit then
    confirm_description(event.player_index, false)
    return
  end
  ---@type LuaGuiElement?
  local window = screen[WINDOW_ID]
  if window and state.selected_slot then
    log:debug("input_confirm from ", event.player_index)
    confirm_signal_value(event.player_index, state, false)
  end
end

--- @param unit_number uint?
function cc_gui:on_entity_destroyed(unit_number)
  if not unit_number then return end
  for _, player in pairs(game.players) do
    if not player then goto continue end
    local screen = player.gui.screen
    local window = screen[WINDOW_ID]
    if not window then goto continue end
    log:debug("current window unit number: ", window.tags.unit_number)
    if window.tags.unit_number == unit_number then
      log:debug("closing window")
      self:close(player.index)
    end

    ::continue::
  end
end

function cc_gui:register()
  flib_gui.add_handlers {
    [WINDOW_ID .. "_close"] = handle_close,
    [WINDOW_ID .. "_on_off"] = handle_on_off,
    [WINDOW_ID .. "_signal_changed"] = handle_signal_changed,
    [WINDOW_ID .. "_signal_click"] = handle_signal_click,
    [WINDOW_ID .. "_signal_value_changed"] = handle_signal_value_changed,
    [WINDOW_ID .. "_signal_value_confirmed"] = handle_signal_value_confirmed,
    [WINDOW_ID .. "_signal_value_confirm"] = handle_signal_value_confirm,
    [WINDOW_ID .. "_cs_signal_value_changed"] = handle_cs_signal_value_changed,
    [WINDOW_ID .. "_cs_signal_value_confirmed"] = handle_cs_signal_value_confirmed,
    [WINDOW_ID .. "_cs_signal_reset"] = handle_cs_signal_reset,
    [WINDOW_ID .. "_network_mask_signal_click"] = handle_network_mask_signal_click,
    [WINDOW_ID .. "_network_mask_signal_changed"] = handle_network_mask_signal_changed,
    [WINDOW_ID .. "_network_mask_changed"] = handle_network_mask_changed,
    [WINDOW_ID .. "_network_mask_confirmed"] = handle_network_mask_confirmed,
    [WINDOW_ID .. "_network_mask_add_click"] = handle_network_mask_add_click,
    [WINDOW_ID .. "_network_list_item_click"] = handle_network_list_item_click,
    [WINDOW_ID .. "_description_edit_click"] = handle_description_edit_click,
    [ENCODER_ID .. "_close"] = handle_dialog_close,
    [ENCODER_ID .. "_confirm"] = handle_encoder_confirm,
    [ENCODER_ID .. "_signal_changed"] = handle_encoder_signal_changed,
    [ENCODER_ID .. "_signal_click"] = handle_encoder_signal_click,
    [ENCODER_ID .. "_mask_changed"] = handle_encoder_mask_changed,
    [ENCODER_ID .. "_bit_button_click"] = handle_encoder_bit_button_click,
    [ENCODER_ID .. "_all"] = handle_encoder_all,
    [ENCODER_ID .. "_none"] = handle_encoder_none,
    [DESC_EDIT_ID .. "_close"] = handle_dialog_close,
    [DESC_EDIT_ID .. "_confirm"] = handle_description_edit_confirm,
    [DIMMER_ID .. "_click"] = handle_dimmer_click
  }
  flib_gui.handle_events()
  script.on_event(defines.events.on_gui_opened, function(event) self:on_gui_opened(event) end)
  script.on_event(defines.events.on_gui_closed, function(event) self:on_gui_closed(event) end)
  script.on_event(constants.MOD_NAME .. "-toggle-menu", function(event) self:on_input_close(event --[[@as EventData.CustomInputEvent]]) end)
  script.on_event(constants.MOD_NAME .. "-confirm-gui", function(event) self:on_input_confirm(event --[[@as EventData.CustomInputEvent]]) end)
end

return cc_gui
