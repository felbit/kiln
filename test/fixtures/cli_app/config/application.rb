require "kiln"

Kiln::Env.load(File.expand_path("../.env", __dir__))

module CliApp
  App = Kiln::Application.new(root: File.expand_path("..", __dir__)) do
    database url: ENV.fetch("CLI_APP_DATABASE_URL")
  end
end
