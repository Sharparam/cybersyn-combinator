local log = require("scripts.logger").expression
local gsub = string.gsub

local NONMATH_PATTERN = "[^0-9%.+%-*/%%^()]"
local ssub = string.sub

local expr = {}

--- @param input string?
--- @param fallback number?
--- @return number
function expr.parse(input, fallback)
  fallback = fallback or 0
  log:debug("parsing expression: ", input)
  if not input then return fallback end

  if ssub(input, 1, 1) == "-" then
    input = "0" .. input
  end

  local success, result = pcall(game.evaluate_expression, input)

  if not success then
    log:warn("The given input '", input, "' could not be evaluated as a math expression: ", result)
    return fallback
  end

  return result
end

return expr
