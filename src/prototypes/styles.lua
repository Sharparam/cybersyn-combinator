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

-- Credit to FactoryPlanner for list-box/scroll-pane styles
styles["cybersyn-combinator_network-list_scroll-pane"] = {
  type = "scroll_pane_style",
  parent = "scroll_pane_with_dark_background_under_subheader",
  background_graphical_set = { -- rubber grid
      position = { 282, 17 },
      corner_size = 8,
      overall_tiling_vertical_size = 22,
      overall_tiling_vertical_spacing = 6,
      overall_tiling_vertical_padding = 4,
      overall_tiling_horizontal_padding = 4
  },
  vertically_stretchable = "on",
  horizontally_stretchable = "on",
  padding = 0,
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0
  }
}

styles["cybersyn-combinator_network-list_item"] = {
  type = "button_style",
  parent = "list_box_item",
  horizontally_stretchable = "on",
  horizontally_squashable = "on"
}

styles["cybersyn-combinator_network-list_item-active"] = {
  type = "button_style",
  parent = "cybersyn-combinator_network-list_item",
  default_graphical_set = styles.button.selected_graphical_set,
  hovered_graphical_set = styles.button.selected_hovered_graphical_set,
  clicked_graphical_set = styles.button.selected_clicked_graphical_set,
  default_font_color = styles.button.selected_font_color,
  default_vertical_offset = styles.button.selected_vertical_offset
}
