class LongJob < Mosquito::QueuedJob
  def perform
    log "It only takes me 3 second to do this"
    sleep 3.seconds
  end
end
