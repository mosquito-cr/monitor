class FastJob < Mosquito::QueuedJob
  def perform
    log "I'm running fast"
  end
end
