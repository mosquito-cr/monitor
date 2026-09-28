module Mosquito::InspectWeb::OverseerStatus
  def self.threshold : Time::Span
    Mosquito.configuration.dead_overseer_threshold
  end

  # The time this overseer last registered itself in the core overseer
  # registry (the `mosquito:overseers` zset). Overseers re-register on every
  # heartbeat tick even when `publish_metrics` is off, which skips the
  # metadata heartbeat, so this is the fallback liveness signal.
  def self.registered_at(id : String) : Time?
    backend = Mosquito.backend
    return unless backend.is_a?(Mosquito::RedisBackend)

    key = backend.build_key Mosquito::RedisBackend::LIST_OF_OVERSEERS_KEY
    if score = backend.redis.zscore(key, id)
      Time.unix(score.to_s.to_f.to_i64)
    end
  end

  def self.to_json(id : String) : String
    heartbeat = Mosquito::Api::Overseer.new(id).last_heartbeat
    registered = registered_at(id)
    last_seen = [heartbeat, registered].compact.max?
    alive = !last_seen.nil? && last_seen > Time.utc - threshold

    {
      id:                     id,
      alive:                  alive,
      last_active_at:         last_seen.try(&.to_rfc3339),
      last_heartbeat_at:      heartbeat.try(&.to_rfc3339),
      registered_at:          registered.try(&.to_rfc3339),
      dead_threshold_seconds: threshold.total_seconds.to_i,
      server_time:            Time.utc.to_rfc3339,
    }.to_json
  end
end

# Lists overseers seen within `dead_overseer_threshold`. Pass `?all=1` to
# include every overseer in the core registry (up to a day old).
get "/api/overseers" do |env|
  env.response.content_type = "application/json"

  ids = if env.params.query["all"]? == "1"
          Mosquito.backend.list_overseers
        else
          since = Time.utc - Mosquito::InspectWeb::OverseerStatus.threshold
          Mosquito.backend.list_active_overseers(since: since)
        end

  {
    overseers:              ids,
    dead_threshold_seconds: Mosquito::InspectWeb::OverseerStatus.threshold.total_seconds.to_i,
  }.to_json
end

get "/api/overseers/:id" do |env|
  env.response.content_type = "application/json"

  Mosquito::InspectWeb::OverseerStatus.to_json env.params.url["id"]
end
