local constants = require "constants"
local config = require "config"
local log = require("logger").gui
local cc_util = require "util"
local CybersynCombinator = require "combinator"
local util = require "__core__.lualib.util"
local flib_gui = require "__flib__.gui-lite"

local WINDOW_ID = "cybersyn-constant-combinator-window"

local RED = "utility/status_not_working"
local GREEN = "utility/status_working"
local YELLOW = "utility/status_yellow"
local STATUS_SPRITES = {
  [defines.entity_status.working] = GREEN,
  [defines.entity_status.normal] = GREEN,
  [defines.entity_status.no_power] = RED,
  [defines.entity_status.low_power] = YELLOW,
  [defines.entity_status.disabled_by_control_behavior] = RED,
  [defines.entity_status.disabled_by_script] = RED,
  [defines.entity_status.marked_for_deconstruction] = RED
}
local DEFAULT_STATUS_SPRITE = RED
local STATUS_NAMES = {
  [defines.entity_status.working] = { "entity-status.working" },
  [defines.entity_status.normal] = { "entity-status.normal" },
  [defines.entity_status.no_power] = { "entity-status.no-power" },
  [defines.entity_status.low_power] = { "entity-status.low-power" },
  [defines.entity_status.disabled_by_control_behavior] = { "entity-status.disabled" },
  [defines.entity_status.disabled_by_script] = { "entity-status.disabled-by-script" },
  [defines.entity_status.marked_for_deconstruction] = { "entity-status.marked-for-deconstruction" }
}
local DEFAULT_STATUS_NAME = { "entity-status.disabled" }

local cc_gui = {}

--- @class SignalEntry
--- @field button LuaGuiElement

--- @class CombinatorState
--- @field main_window LuaGuiElement
--- @field status_sprite LuaGuiElement
--- @field status_label LuaGuiElement
--- @field entity_preview LuaGuiElement
--- @field on_off LuaGuiElement
--- @field signal_value_stacks LuaGuiElement
--- @field signal_value_items LuaGuiElement
--- @field signal_value_confirm LuaGuiElement
--- @field signals SignalEntry[]
--- @field entity LuaEntity
--- @field combinator CybersynCombinator
--- @field selected_slot uint?
--- @field stack_size integer?

--- @param player_index uint?
--- @return CombinatorState?
local function get_player_state(player_index)
  if not player_index then return nil end
  local data = cc_util.get_player_data(player_index)
  if not data then return nil end
  return data.state --[[@as CombinatorState?]]
end

--- @param player_index uint
--- @param state CombinatorState
local function set_player_state(player_index, state)
  local data = cc_util.get_player_data(player_index)
  if not data then
    log:error("failed to get player data table for player ", player_index, " for writing state")
    return -- TODO: Throw error?
  end
  data.state = state
end

--- @param slot uint?
--- @param signal Signal?
local function update_signal_table(state, slot, signal)
  if not state then return end
  if state and not slot and not signal then
    for s = 1, config.slot_count do
      local sig = state.combinator:get_slot(s --[[@as uint]])
      update_signal_table(state, s --[[@as uint]], sig)
    end
    return
  end
  if not signal or not signal.signal then return end
  local button = state.signals[slot].button
  button.elem_value = signal.signal
  button.label.caption = util.format_number(signal.count, true)
  button.locked = true
end

--- @param state CombinatorState
local function update_cs_signals(state)
  for name, data in pairs(config.cs_signals) do
    local value = state.combinator:get_cs_value(name)
    local element = state[name]
    if element then
      element.text = tostring(value)
    end
  end
end

--- @param state CombinatorState
--- @param event EventData.on_gui_click|EventData.on_gui_elem_changed
local function change_signal_count(state, event)
  local slot = state.selected_slot
  local signal = state.combinator:get_slot(slot)
  if not signal or not signal.signal then
    cc_gui:close(event.player_index)
    return
  end

  local signal_type = signal.signal.type
  local signal_name = signal.signal.name

  local value = signal.count
  log:debug("change_signal_count: signal type is ", signal_type, ", name is ", signal_name)

  state.signal_value_items.enabled = true
  state.signal_value_items.text = tostring(value)
  state.signal_value_items.focus()
  state.signal_value_items.select_all()
  state.signal_value_confirm.enabled = false

  if signal_type == "item" or signal_type == "fluid" then
    --- @type integer
    local stack_size
    if signal_type == "item" then
      stack_size = game.item_prototypes[signal_name].stack_size
      state.signal_value_stacks.enabled = true
      if settings.get_player_settings(event.player_index)[constants.SETTINGS.USE_STACKS].value then
        state.signal_value_stacks.focus()
        log:debug("selecting all text in stack textbox")
        state.signal_value_stacks.select_all()
      end
    elseif signal_type == "fluid" then
      stack_size = 1
      state.signal_value_stacks.enabled = false
    end
    state.signal_value_stacks.text = tostring(value / stack_size)
    state.stack_size = stack_size
  else
    state.signal_value_stacks.enabled = false
    state.stack_size = 1
  end
end

--- @param state CombinatorState
--- @param value integer
local function set_new_signal_value(state, value)
  local new_value = util.clamp(value, constants.INT32_MIN, constants.INT32_MAX)
  state.combinator:set_slot_value(state.selected_slot, new_value)
  state.signal_value_items.enabled = false
  state.signal_value_stacks.enabled = false
  state.signal_value_confirm.enabled = false
  state.signals[state.selected_slot].button.label.caption = util.format_number(new_value, true)
  state.selected_slot = nil
  state.stack_size = nil
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
  state.status_sprite.sprite = STATUS_SPRITES[status] or DEFAULT_STATUS_SPRITE
  state.status_label.caption = STATUS_NAMES[status] or DEFAULT_STATUS_NAME
end

--- @param event EventData.on_gui_elem_changed
local function handle_signal_changed(event)
  local element = event.element
  local state = get_player_state(event.player_index)
  if not state then return end
  local slot = element.tags.slot --[[@as uint]]
  local signal = { signal = element.elem_value, count = 0 }
  if not signal.signal then return end
  log:debug("elem changed, slot ", slot, ": ", element.elem_value)
  state.selected_slot = slot
  state.combinator:set_slot(slot, signal)
  element.locked = true
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
    state.combinator:remove_slot(slot)
    element.locked = false
    element.elem_value = nil
    element.label.caption = ""
    if state.selected_slot == slot then
      state.signal_value_stacks.enabled = false
      state.signal_value_items.enabled = false
      state.signal_value_confirm.enabled = false
    end
  elseif event.button == defines.mouse_button_type.left and element.elem_value then
    state.selected_slot = slot
    change_signal_count(state, event)
  end
end

--- @param event EventData.on_gui_text_changed
local function handle_signal_value_changed(event)
  local element = event.element
  local value = tonumber(element.text)
  if not value then return end
  log:debug("value of ", element.name, " changed to : ", value)
  local state = get_player_state(event.player_index)
  if not state then return end
  state.signal_value_confirm.enabled = true
  if element.name == "signal_value_items" then
    local stack = value / state.stack_size
    state.signal_value_stacks.text = tostring(stack >= 0 and math.ceil(stack) or math.floor(stack))
  elseif element.name == "signal_value_stacks" then
    state.signal_value_items.text = tostring(value * state.stack_size)
  end
end

--- @param event EventData.on_gui_confirmed
local function handle_signal_value_confirmed(event)
  local state = get_player_state(event.player_index)
  if not state or not state.selected_slot then return end
  local value = tonumber(state.signal_value_items.text)
  if not value then return end
  set_new_signal_value(state, value)
end

--- @param event EventData.on_gui_click
local function handle_signal_value_confirm(event)
  local state = get_player_state(event.player_index)
  if not state or not state.selected_slot then return end
  local value = tonumber(state.signal_value_items.text)
  if not value then return end
  set_new_signal_value(state, value)
end

--- @param event EventData.on_gui_text_changed
local function handle_cs_signal_value_changed(event)
  local element = event.element
  local value = tonumber(element.text)
  if not value then return end
  local state = get_player_state(event.player_index)
  if not state then return end
  local signal_name = element.tags.signal_name --[[@as string]]
  log:debug("cs_signal_value_changed: ", signal_name, " changed to ", value)
  local min = constants.INT32_MIN
  local max = constants.INT32_MAX
  if config.cs_signals[signal_name] then
    min = config.cs_signals[signal_name].min
    max = config.cs_signals[signal_name].max
  end
  state.combinator:set_cs_value(signal_name, util.clamp(value, min, max))
end

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @return CombinatorState
local function create_window(player, entity)
  local screen = player.gui.screen

  local named, main_window = flib_gui.add(screen, {
    {
      type = "frame",
      direction = "vertical",
      name = WINDOW_ID,
      tags = {
        unit_number = entity.unit_number
      },
      children = {
        { -- Titlebar
          type = "flow",
          drag_target = WINDOW_ID,
          children = {
            {
              type = "label",
              style = "frame_title",
              caption = { "cybersyn-combinator-window.title" },
              elem_mods = { ignored_by_interaction = true }
            },
            {
              type = "empty-widget",
              style = "flib_titlebar_drag_handle",
              elem_mods = { ignored_by_interaction = true }
            },
            {
              type = "sprite-button",
              style = "frame_action_button",
              mouse_button_filter = { "left" },
              sprite = "utility/close_white",
              hovered_sprite = "utility/close_black",
              clicked_sprite = "utility/close_black",
              name = WINDOW_ID .. "_close",
              handler = handle_close
            }
          }
        },
        { -- Content
          type = "frame",
          direction = "horizontal",
          style = "inside_shallow_frame_with_padding",
          style_mods = { padding = 8 },
          children = {
            {
              type = "flow",
              direction = "vertical",
              children = {
                { -- status, preview, CS signals
                  type = "flow",
                  direction = "horizontal",
                  children = {
                    -- Combinator status and preview
                    {
                      type = "flow",
                      direction = "vertical",
                      style_mods = { horizontal_align = "left" },
                      children = {
                        { -- Status
                          type = "flow",
                          style = "status_flow",
                          direction = "horizontal",
                          style_mods = { vertical_align = "center", horizontally_stretchable = true, bottom_padding = 4 },
                          children = {
                            {
                              type = "sprite",
                              name = "status_sprite",
                              sprite = STATUS_SPRITES[entity.status] or DEFAULT_STATUS_SPRITE,
                              style = "status_image",
                              style_mods = { stretch_image_to_widget_size = true }
                            },
                            {
                              type = "label",
                              name = "status_label",
                              caption = STATUS_NAMES[entity.status] or DEFAULT_STATUS_NAME
                            }
                          },
                        },
                        { -- Preview
                          type = "frame",
                          style = "deep_frame_in_shallow_frame",
                          style_mods = { minimal_width = 0, horizontally_stretchable = true, padding = 0 },
                          children = {
                            {
                              type = "entity-preview",
                              name = "preview",
                              style = "wide_entity_button",
                              style_mods = {
                                width = 280,
                                height = 128,
                                horizontally_stretchable = true
                              }
                            }
                          }
                        }
                      }
                    },
                    { -- CS signal pane
                      type = "flow",
                      direction = "vertical",
                      style_mods = { top_margin = 25, left_padding = 8, width = 300, horizontal_align = "center", vertically_stretchable = true },
                      children = {
                        {
                          type = "table",
                          name = "cs_signals_table",
                          column_count = 3,
                          style_mods = { cell_padding = 2, horizontally_stretchable = true, vertical_align = "center" }
                        }
                      }
                    }
                  }
                },
                { -- On/off switch
                  type = "flow",
                  style_mods = { horizontal_align = "left" },
                  direction = "vertical",
                  children = {
                    {
                      type = "label",
                      style = "heading_3_label",
                      style_mods = { top_margin = 8 },
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
                },
                -- Separator
                {
                  type = "line",
                  style_mods = { top_margin = 5 },
                },
                {
                  type = "label",
                  style = "heading_3_label",
                  style_mods = { top_margin = 0 },
                  caption = { "gui-constant.output-signals" }
                },
                { -- Signals container
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
                          style = "short_number_textfield",
                          style_mods = { horizontal_align = "right", horizontally_stretchable = false },
                          lose_focus_on_confirm = true,
                          clear_and_focus_on_right_click = true,
                          elem_mods = { numeric = true, text = "0", allow_negative = true },
                          handler = {
                            [defines.events.on_gui_text_changed] = handle_signal_value_changed,
                            [defines.events.on_gui_confirmed] = handle_signal_value_confirmed
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
                          style = "short_number_textfield",
                          style_mods = { horizontal_align = "right", horizontally_stretchable = false },
                          lose_focus_on_confirm = true,
                          clear_and_focus_on_right_click = true,
                          elem_mods = { numeric = true, text = "0", allow_negative = true },
                          handler = {
                            [defines.events.on_gui_text_changed] = handle_signal_value_changed,
                            [defines.events.on_gui_confirmed] = handle_signal_value_confirmed
                          }
                        },
                        {
                          type = "sprite-button",
                          name = "signal_value_confirm",
                          style = "item_and_count_select_confirm",
                          style_mods = { left_padding = 5 },
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
              }
            }
          }
        }
      }
    }
  })

  local signal_table = named.signal_table
  if not signal_table then
    error("signal_table is nil")
  end
  local signals = {}
  for i = 1, config.slot_count do
    local _, button = flib_gui.add(signal_table, {
      type = "choose-elem-button",
      name = "cybersyn-combinator_signal-button__" .. i,
      style = "flib_slot_button_default",
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
          style = "signal_count",
          ignored_by_interaction = true,
          caption = ""
        }
      }
    })

    signals[i] = { button = button}
  end

  local cs_signals_table = named.cs_signals_table
  if not cs_signals_table then
    error("cs_signals_table is nil")
  end
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
      numeric = true,
      allow_decimal = false,
      allow_negative = data.min < 0,
      clear_and_focus_on_right_click = true,
      lose_focus_on_confirm = true,
      handler = {
        [defines.events.on_gui_text_changed] = handle_cs_signal_value_changed
      },
      tags = {
        signal_name = signal_name
      }
    })
    state[signal_name] = field
  end

  local preview = named.preview
  preview.entity = entity
  main_window.force_auto_center()

  state.main_window = main_window
  state.status_sprite = named.status_sprite
  state.status_label = named.status_label
  state.entity_preview = preview
  state.on_off = named.on_off
  state.signal_value_stacks = named.signal_value_stacks
  state.signal_value_items = named.signal_value_items
  state.signal_value_confirm = named.signal_value_confirm
  state.signals = signals
  state.entity = entity

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

  set_player_state(player_index, state)

  player.opened = state.main_window
  return true
end

--- @param player LuaPlayer
--- @param window_id string
--- @return boolean
local function destroy(player, window_id)
  local screen = player.gui.screen
  if not screen[window_id] then
    log:debug("destroy called on ", window_id, " but it doesn't exist")
    return false
  end
  screen[window_id].destroy()
  log:debug("destroyed ", window_id)
  return true
end

--- @param player_index uint?
function cc_gui:close(player_index)
  if not player_index then return end
  local player = game.get_player(player_index)
  if not player then return end
  log:debug("GUI close, player index ", player_index)
  local destroyed = destroy(player, WINDOW_ID)
  local player_data = cc_util.get_player_data(player_index)
  if player_data.state and player_data.state.combinator then
    player_data.state.combinator:validate()
    player_data.state = nil
  end
  if not destroyed then return end
  player.play_sound { path = constants.ENTITY_CLOSE_SOUND }
end

--- @param event EventData.on_gui_opened
function cc_gui:on_gui_opened(event)
  local entity = event.entity
  local player_index = event.player_index
  if not entity or not entity.valid or entity.name ~= constants.ENTITY_NAME then
    return
  end
  log:debug("on_gui_opened: opening")
  self:open(player_index, entity)
end

--- @param event EventData.on_gui_closed
function cc_gui:on_gui_closed(event)
  local element = event.element
  if not element or element.name ~= WINDOW_ID then return end
  log:debug("on_gui_closed: ", element.name)
  local player_index = event.player_index
  self:close(player_index)
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
    [WINDOW_ID .. "_cs_signal_value_changed"] = handle_cs_signal_value_changed
  }
  flib_gui.handle_events()
  script.on_event(defines.events.on_gui_opened, function(event) self:on_gui_opened(event) end)
  script.on_event(defines.events.on_gui_closed, function(event) self:on_gui_closed(event) end)
end

return cc_gui
