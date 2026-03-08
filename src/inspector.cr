require "kemal"
require "mosquito"

require "./current"
require "./event_stream"
require "./socket_broadcaster"

Current.global(tab : Symbol = :none)
Current.global(base_path : String = "")

module Mosquito
  class Inspector
    getter router : Kemal::Router
    getter base_path : String

    def initialize(@base_path : String = "")
      @router = Kemal::Router.new
      setup_before_hooks
      setup_html_routes
      setup_api_routes
      setup_websocket_routes
    end

    # Build and return a Kemal::Router ready to be mounted.
    #
    # Usage:
    #
    #   # Standalone
    #   mount Mosquito::Inspector.router
    #   Kemal.run
    #
    #   # Embedded at a prefix
    #   inspector = Mosquito::Inspector.new("/admin/mosquito")
    #   mount "/admin/mosquito", inspector.router
    #   Kemal.run
    #
    def self.router(base_path : String = "") : Kemal::Router
      new(base_path).router
    end

    private def setup_before_hooks
      bp = @base_path
      router.before_all do
        Current.reset
        Current.base_path = bp
      end
    end

    private def setup_html_routes
      router.get "/" do |env|
        env.redirect "#{Current.base_path}/overseers"
      end

      router.get "/overseers" do |env|
        Current.tab = :overseers
        InspectWeb.render "overseers.html.ecr"
      end

      router.get "/queues" do |env|
        queues = Mosquito::Api::Queue.all
        InspectWeb.render "queues.html.ecr"
      end

      router.get "/job_run/:id" do |env|
        job_id = env.params.url["id"]
        job = Mosquito::Api::JobRun.new job_id

        unless job.found?
          env.response.status = HTTP::Status::UNAUTHORIZED
        end

        InspectWeb.render "job.html.ecr"
      end
    end

    private def setup_api_routes
      router.get "/api/overseers" do |env|
        env.response.content_type = "application/json"

        overseers = Mosquito::Api::Overseer.all
        {
          overseers: overseers.map(&.instance_id),
        }.to_json
      end

      router.get "/api/overseers/:id" do |env|
        env.response.content_type = "application/json"

        id = env.params.url["id"]
        overseer = Mosquito::Api::Overseer.new(id)
        {
          id:             id,
          last_active_at: overseer.last_heartbeat.to_s,
        }.to_json
      end

      router.get "/api/overseers/:id/executors" do |env|
        env.response.content_type = "application/json"

        id = env.params.url["id"]
        format_executor = ->(executor : Mosquito::Api::Executor) do
          {
            id:                executor.instance_id,
            current_job:       executor.current_job,
            current_job_queue: executor.current_job_queue,
          }
        end

        overseer = Mosquito::Api::Overseer.new(id)
        {
          id:        id,
          executors: overseer.executors.map(&format_executor),
        }.to_json
      end

      router.get "/api/executors/:id" do |env|
        env.response.content_type = "application/json"

        id = env.params.url["id"]
        executor = Mosquito::Api::Executor.new(id)
        {
          executor: {
            id:          id,
            current_job: executor.current_job,
          },
        }.to_json
      end
    end

    private def setup_websocket_routes
      event_stream = Mosquito::Api.event_receiver
      event_stream_clients = EventStream.new
      queue_depth_broadcast = QueueDepthMonitor.new(1.seconds)

      spawn do
        loop do
          select
          when message = event_stream.receive
            event_stream_clients.broadcast format_broadcast(message)
          when timeout(0.5.seconds)
          end

          queue_depth_broadcast.broadcast_queue_size? do
            event_stream_clients.broadcast queue_size_message
          end
        end
      end

      router.ws "/events" do |socket|
        event_stream_clients.register socket
      end
    end

    private def format_broadcast(broadcast : Mosquito::Backend::BroadcastMessage) : String
      {
        type:    "broadcast",
        channel: broadcast.channel,
        message: JSON.parse(broadcast.message),
      }.to_json
    end

    private def queue_size_message : String
      {
        type:    "broadcast",
        channel: "queue-summary",
        queues:  Mosquito::Api::Queue.all.map do |queue|
          {
            name:    queue.name,
            size:    queue.size,
            details: queue.size_details,
          }
        end,
      }.to_json
    end
  end
end

# QueueDepthMonitor throttles queue size broadcasts to a fixed interval.
class QueueDepthMonitor
  def initialize(@interval : Time::Span)
    @last_broadcast_time = Time.utc
  end

  def should_broadcast?
    Time.utc - @last_broadcast_time >= @interval
  end

  def mark_broadcasted!
    @last_broadcast_time = Time.utc
  end

  def broadcast_queue_size?
    if should_broadcast?
      yield
      mark_broadcasted!
    end
  end
end

module Mosquito::InspectWeb
  macro render(file)
    ::render({{ __DIR__ }} + "/views/" + {{ file }}, {{ __DIR__ }} + "/views/layout.html.ecr")
  end
end
