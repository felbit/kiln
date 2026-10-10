class AdminController < ApplicationController
  def index
    @greeting = Greeting.text
  end
end
