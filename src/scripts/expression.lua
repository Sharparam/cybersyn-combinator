local log = require("scripts.logger").expression
local gsub = string.gsub

local NONMATH_PATTERN = "[^0-9%.+%-*/%%^()]"

local expr = {}

--- @param input string?
--- @return number
function expr.parse(input)
  log:debug("parsing expression: ", input)
  if not input then return 0 end
  local e = gsub(input, NONMATH_PATTERN, "")
  local f, err = load("return " .. e, nil, "t", {})
  if not f then
    log:warn("The given input '", input, "' could not be parsed as a math expression: ", err)
    return 0
  end
  local success, result = pcall(f)
  if not success then
    log:warn("The given input '", input, "' could not be evaluated as a math expression: ", result)
    return 0
  end
  log:debug("expression '", input, "' parsed as: ", result)
  return tonumber(result) or 0
end

return expr
