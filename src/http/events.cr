event_stream = Mosquito::Api.event_receiver
event_stream_clients = EventStream.new
queue_depth_broadcast = QueueDepthMonitor.new(1.seconds)

def message_formatter(broadcast : Mosquito::Backend::BroadcastMessage) : String
  {
    type: "broadcast",
    channel: broadcast.channel,
    message: JSON.parse(broadcast.message)
  }.to_json
end

def queue_size_message : String
  {
    type: "broadcast",
    channel: "queue-summary",
    queues: Mosquito::Api::Queue.all.map do |queue|
      {
        name: queue.name,
        size: queue.size,
        details: queue.size_details
      }
    end
  }.to_json
end

class QueueDepthMonitor
  def initialize(interval : Time::Span)
    @interval = interval
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


spawn do
  loop do
    select
    when message = event_stream.receive
      event_stream_clients.broadcast message_formatter(message)
    when timeout(0.5.seconds)
    end

    queue_depth_broadcast.broadcast_queue_size? do
      event_stream_clients.broadcast queue_size_message
    end
  end
end

ws "/events" do |socket|
  event_stream_clients.register socket
end

