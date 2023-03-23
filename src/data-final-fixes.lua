local constants = require "scripts.constants"

if mods["cybersyn"] and data.raw.technology["cybersyn-train-network"] then
  table.insert(data.raw.technology["cybersyn-train-network"].effects,
  { type = "unlock-recipe", recipe = constants.ENTITY_NAME })
else
  table.insert(data.raw.technology["circuit-network"].effects, { type = "unlock-recipe", recipe = constants.ENTITY_NAME })
end
