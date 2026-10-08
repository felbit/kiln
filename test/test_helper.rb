# frozen_string_literal: true

Warning[:experimental] = false

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "kiln"

require "minitest/autorun"
