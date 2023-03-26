data:extend {
  {
    type = "string-setting",
    name = "cybersyn-combinator-loglevel",
    setting_type = "startup",
    default_value = "WARN",
    allowed_values = {
      "DEBUG",
      "INFO",
      "WARN",
      "ERROR",
      "DISABLED"
    },
    order = "c[cybersyn]-c[combinator]-l[loglevel]"
  },
  {
    type = "string-setting",
    name = "cybersyn-combinator-loglevel-chat",
    setting_type = "startup",
    default_value = "ERROR",
    allowed_values = {
      "DEBUG",
      "INFO",
      "WARN",
      "ERROR",
      "DISABLED"
    },
    order = "c[cybersyn]-c[combinator]-l[loglevel]-c[chat]"
  },
  {
    type = "int-setting",
    name = "cybersyn-combinator-slotrows",
    setting_type = "startup",
    default_value = 4,
    minimum_value = 1,
    maximum_value = 64,
    order = "c[cybersyn]-c[combinator]-s[slotrows]"
  },
  {
    type = "int-setting",
    name = "cybersyn-combinator-slotcount-wagon",
    setting_type = "startup",
    default_value = 1000,
    minimum_value = 1,
    order = "c[cybersyn]-c[combinator]-s[slotcount]-w[wagon]"
  },
  {
    type = "bool-setting",
    name = "cybersyn-combinator-upgradeable",
    setting_type = "startup",
    default_value = false,
    order = "c[cybersyn]-c[combinator]-u[upgradeable]"
  },
  {
    type = "bool-setting",
    name = "cybersyn-combinator-emit-default-request-threshold",
    setting_type = "runtime-global",
    default_value = false,
    order = "c[cybersyn]-c[combinator]-e[emit]-d[default]-r[request]-t[threshold]"
  },
  {
    type = "bool-setting",
    name = "cybersyn-combinator-emit-default-priority",
    setting_type = "runtime-global",
    default_value = false,
    order = "c[cybersyn]-c[combinator]-e[emit]-d[default]-p[priority]"
  },
  {
    type = "bool-setting",
    name = "cybersyn-combinator-emit-default-locked-slots",
    setting_type = "runtime-global",
    default_value = false,
    order = "c[cybersyn]-c[combinator]-e[emit]-d[default]-l[locked]-s[slots]"
  },
  {
    type = "bool-setting",
    name = "cybersyn-combinator-use-stacks",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "c[cybersyn]-c[combinator]-u[use]-s[stacks]"
  },
  {
    type = "bool-setting",
    name = "cybersyn-combinator-disable-built",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "c[cybersyn]-c[combinator]-d[disable]-b[built]"
  }
}
