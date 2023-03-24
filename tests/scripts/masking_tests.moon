masking = require "scripts.masking"

describe "masking", ->
  describe "int_to_hex", ->
    it "should convert 255 to FF", ->
      assert.equals masking.int_to_hex(255), "000000FF"

  describe "hex_to_int", ->
    it "should convert FF to 255", ->
      assert.equals masking.hex_to_int("FF"), 255

    it "should parse lowercase hex digits", ->
      assert.equals masking.hex_to_int("ab"), 171
