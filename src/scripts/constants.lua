local constants = {
  INT32_MAX = 2147483647,
  INT32_MIN = -2147483648,
  MOD_NAME = "cybersyn-combinator",
  MOD_TITLE = "Cybersyn Combinator",
  SETTINGS = {
    LOG_LEVEL = "cybersyn-combinator-loglevel",
    CHAT_LOG_LEVEL = "cybersyn-combinator-loglevel-chat",
    SLOT_COUNT = "cybersyn-combinator-slotcount",
    SLOT_ROWS = "cybersyn-combinator-slotrows",
    SLOT_COUNT_WAGON = "cybersyn-combinator-slotcount-wagon",
    EMIT_DEFAULT_REQUEST_THRESHOLD = "cybersyn-combinator-emit-default-request-threshold",
    EMIT_DEFAULT_PRIORITY = "cybersyn-combinator-emit-default-priority",
    EMIT_DEFAULT_LOCKED_SLOTS = "cybersyn-combinator-emit-default-locked-slots",
    USE_STACKS = "cybersyn-combinator-use-stacks",
    DISABLE_BUILT = "cybersyn-combinator-disable-built",
    CS_REQUEST_THRESHOLD = "cybersyn-request-threshold",
    CS_PRIORITY = "cybersyn-priority",
    CS_LOCKED_SLOTS = "cybersyn-locked-slots"
  },
  ENTITY_NAME = "cybersyn-constant-combinator"
}

--- @type string
constants.ENTITY_CLOSE_SOUND = "entity-close/" .. constants.ENTITY_NAME

return constants
