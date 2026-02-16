require "kemal"
require "mosquito"

require "./init"
require "./src/web_routes"

Kemal.run(port: 8080)
