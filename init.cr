#
# These settings are used for:
#
# - Web interface
# - TUI interface
# - Interactive Runner
#

Mosquito.configure do |settings|
  settings.idle_wait = 10.seconds
  settings.redis_url = "redis://localhost:6379/2"
  settings.publish_metrics = true
end

Log.setup do |s|
  backend = Log::IOBackend.new
  # s.bind "redis.*", :trace, backend
  s.bind "mosquito.*", :debug, backend
end

