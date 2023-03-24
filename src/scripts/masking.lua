local format = string.format

local HEX_FORMAT = "%08X"

local masking = {}

--- @param int integer
--- @return string
function masking.int_to_hex(int)
  return format(HEX_FORMAT, int)
end

--- @param hex string
--- @return integer
function masking.hex_to_int(hex)
  return tonumber(hex, 16)
end

return masking
