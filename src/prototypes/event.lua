local constants = require "scripts.constants"

data:extend {
  {
    type = "custom-input",
    name = constants.MOD_NAME .. "-toggle-menu",
    key_sequence = "",
    linked_game_control = "toggle-menu"
  },
  {
    type = "custom-input",
    name = constants.MOD_NAME .. "-confirm-gui",
    key_sequence = "",
    linked_game_control = "confirm-gui"
  }
}
