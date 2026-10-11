ENV["KILN_ENV"] ||= "test"
require "minitest/autorun"
Warning[:experimental] = false
require_relative "../config/application"
