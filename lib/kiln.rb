# frozen_string_literal: true

module Kiln
  class Error < StandardError; end
end

require_relative "kiln/version"
require_relative "kiln/router"
require_relative "kiln/controller"
require_relative "kiln/dispatcher"
require_relative "kiln/application"
