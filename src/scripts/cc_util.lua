local util = {}

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
