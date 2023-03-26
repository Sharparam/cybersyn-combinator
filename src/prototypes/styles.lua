local styles = data.raw["gui-style"].default

styles["cybersyn-combinator_cs-signal-sprite"] = {
  type = "image_style",
  parent = "image",
  size = 32,
  left_padding = 2,
  stretch_image_to_widget_size = true
}

styles["cybersyn-combinator_cs-signal-label"] = {
  type = "label_style",
  parent = "caption_label",
  horizontally_stretchable = "on"
}

styles["cybersyn-combinator_cs-signal-text"] = {
  type = "textbox_style",
  parent = "short_number_textfield",
  horizontal_align = "right",
  horizontally_stretchable = "off"
}
