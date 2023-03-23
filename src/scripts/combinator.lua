local constants = require "constants"

--- @class CybersynCombinator
--- @field entity LuaEntity
local CC = {}

--- @param entity LuaEntity
--- @return CybersynCombinator
function CC:new(entity)
  if not entity or not entity.valid or entity.name ~= constants.ENTITY_NAME then
    error("CybersynCombinator:new: entity has to be a valid instance of " .. constants.ENTITY_NAME)
  end

  local instance = setmetatable({ entity = entity }, { __index = self })

  return instance
end

function CC:_parse_entity()
end

return CC
