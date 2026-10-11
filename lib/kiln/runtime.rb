# frozen_string_literal: true

module Kiln
  Runtime = Data.define(:environment, :database, :views, :cross_origin_protection, :sessions, :static, :errors)
end
