require "kemal"
require "mosquito"

require "./init"
require "./src/inspector"

# Mount the inspector dashboard at the root.
#
# To embed in another Kemal app at a prefix:
#
#   mount "/admin/mosquito", Mosquito::Inspector.router("/admin/mosquito")
#
mount Mosquito::Inspector.router

# Development hot-reload (not part of the embeddable router)
require "./src/http/hot_reload"

Kemal.run(port: 8080)
