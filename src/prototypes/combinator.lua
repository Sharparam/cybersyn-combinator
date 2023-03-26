local constants = require "scripts.constants"
local config = require "scripts.config"
local flib_data_util = require "__flib__.data-util"

local name = constants.ENTITY_NAME
local combi = flib_data_util.copy_prototype(data.raw["constant-combinator"]["constant-combinator"], name)
combi.icon = "__cybersyn-combinator__/graphics/entity/combinator/cybersyn-combinator.png"
combi.icon_size = 32
combi.icon_mipmaps = nil
combi.next_upgrade = nil
combi.fast_replaceable_group = "constant-combinator"
combi.item_slot_count = config.total_slot_count
combi.sprites = make_4way_animation_from_spritesheet {
  layers = {
    {
      filename = "__cybersyn-combinator__/graphics/entity/combinator/cybersyn-combinator.png",
      width = 58,
      height = 52,
      frame_count = 1,
      shift = util.by_pixel(0, 5),
      hr_version = {
        scale = 0.5,
        filename = "__cybersyn-combinator__/graphics/entity/combinator/hr-cybersyn-combinator.png",
        width = 114,
        height = 102,
        frame_count = 1,
        shift = util.by_pixel(0, 5)
      }
    },
    {
      filename = "__base__/graphics/entity/combinator/constant-combinator-shadow.png",
      width = 50,
      height = 30,
      frame_count = 1,
      shift = util.by_pixel(9, 6),
      draw_as_shadow = true,
      hr_version = {
        scale = 0.5,
        filename = "__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png",
        width = 98,
        height = 66,
        frame_count = 1,
        shift = util.by_pixel(8.5, 5.5),
        draw_as_shadow = true
      }
    }
  }
}

local combi_item = flib_data_util.copy_prototype(data.raw.item["constant-combinator"], name)
combi_item.icon = "__cybersyn-combinator__/graphics/icons/cybersyn-combinator.png"
combi_item.icon_size = 64
combi_item.icon_mipmaps = 4
combi_item.subgroup = data.raw.item["train-stop"].subgroup
combi_item.place_result = name

local combi_recipe = flib_data_util.copy_prototype(data.raw.recipe["constant-combinator"], name)
combi_recipe.ingredients = {
  { "constant-combinator", 1 },
  { "electronic-circuit", 1 }
}
combi_recipe.enabled = false
combi_recipe.subgroup = data.raw.recipe["train-stop"].subgroup

data:extend {
  combi,
  combi_item,
  combi_recipe
}
