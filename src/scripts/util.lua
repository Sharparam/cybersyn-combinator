local util = {}

--- Register for one or multiple events, passing the same filters to all of them.
--- The base API does not support registering for multiple events at once, even
--- if all of them support the same filters.
--- @param event string|defines.events|defines.events[]
--- @param handler fun(event: EventData)|nil
--- @param filters EventFilter?
function util.on_multi_event(event, handler, filters)
  if type(event) ~= "table" then event = { event } end
  for _, e in pairs(event) do
    if filters then
      script.on_event(e, handler, filters)
    else
      script.on_event(e, handler)
    end
  end
end

--- @param player_index uint
--- @return table?
function util.get_player_data(player_index)
  if not global.player_data then global.player_data = {} end
  local player = game.get_player(player_index)
  if not player or not player.valid then
    return nil
  end
  if not global.player_data[player_index] then
    global.player_data[player_index] = {}
  end
  return global.player_data[player_index]
end

return util
