constants = require "scripts.constants"
masking = require "scripts.masking"

mock_mask_setting = (mode, prefix) ->
  prefix = prefix or false
  _G.settings = {
    get_player_settings: (player) -> {
      [constants.SETTINGS.NETWORK_MASK_DISPLAY_MODE]:
        value: mode
      [constants.SETTINGS.NETWORK_MASK_DISPLAY_PREFIX]:
        value: prefix
    }
  }

describe "masking", ->
  describe "format", ->
    describe "when called without player", ->
      describe "by leaving out second argument", ->
        it "should format as padded decimal", ->
          assert.equals "          1", masking.format(1)
        it "should format negatives as padded decimal", ->
          assert.equals "         -1", masking.format(-1)

      describe "by using a nil second argument", ->
        it "should format as padded decimal", ->
          assert.equals "          1", masking.format(1, nil)
        it "should format negatives as padded decimal", ->
          assert.equals "         -1", masking.format(-1, nil)
    describe "when called with a player", ->
      insulate "that has decimal configured", ->
        mock_mask_setting "DECIMAL"

        it "should format as padded decimal", ->
          assert.equals "          1", masking.format(1, 1)
        it "should format negatives as padded decimal", ->
          assert.equals "         -1", masking.format(-1, 1)
      insulate "that has hex configured", ->
        mock_mask_setting "HEX"

        it "should format as padded hexadecimal", ->
          assert.equals "00000080", masking.format(128, 1)
        it "should handle negative number", ->
          assert.equals "FFFFFFFF", masking.format(-1, 1)
      insulate "that has binary configured", ->
        mock_mask_setting "BINARY"

        it "should format as padded binary", ->
          assert.equals "00000000000000000000000010000000", masking.format(128, 1)
        it "should handle negative number", ->
          assert.equals "11111111111111111111111111111111", masking.format(-1, 1)
      insulate "that has octal configured", ->
        mock_mask_setting "OCTAL"

        it "should format as padded octal", ->
          assert.equals "00000000200", masking.format(128, 1)
        it "should handle negative number", ->
          assert.equals "37777777777", masking.format(-1, 1)

  describe "parse", ->
    it "returns 0 when called with nil input", ->
      assert.equals 0, masking.parse(nil)
    it "returns 0 when called with empty string as input", ->
      assert.equals 0, masking.parse("")
    it "returns 0 when called with whitespace string as input", ->
      assert.equals 0, masking.parse("       ")
    it "returns number if used with non-number characters", ->
      assert.equals 123, masking.parse("    1,  2?.... 3''''!")
    describe "with decimal", ->
      it "parses regular number", ->
        assert.equals 123, masking.parse("123")
      it "parses number with negative sign", ->
        assert.equals -123, masking.parse("-123")
    describe "with decimal prefix", ->
      it "parses regular number", ->
        assert.equals 123, masking.parse("0d123")
      it "parses with negative sign", ->
        assert.equals -123, masking.parse("-0d123")
      it "parses with negative sign after prefix", ->
        assert.equals -123, masking.parse("0d-123")
    describe "with hexadecimal", ->
      it "returns 0 when hexadecimal without prefix", ->
        assert.equals 0, masking.parse("DEADBEEF123")
    describe "with hexadecimal prefix", ->
      it "parses regular number", ->
        assert.equals 128, masking.parse("0x80")
      it "ignores negative sign on hexadecimal numbers", ->
        assert.equals 128, masking.parse("-0x80")
      it "ignores negative sign after prefix on hexadecimal numbers", ->
        assert.equals 128, masking.parse("0x-80")
      it "returns -1 on 0xFFFFFFFF", ->
        assert.equals -1, masking.parse("0xFFFFFFFF")
