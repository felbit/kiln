# frozen_string_literal: true

module Kiln
  class Error < StandardError; end
end

require_relative "kiln/version"
require_relative "kiln/router"
require_relative "kiln/database"
require_relative "kiln/runtime"
require_relative "kiln/view"
require_relative "kiln/session_store"
require_relative "kiln/session"
require_relative "kiln/flash"
require_relative "kiln/controller"
require_relative "kiln/params"
require_relative "kiln/cross_origin_protection"
require_relative "kiln/dispatcher"
require_relative "kiln/application"
