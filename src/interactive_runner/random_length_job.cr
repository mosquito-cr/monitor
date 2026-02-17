class RandomLengthJob < Mosquito::QueuedJob
  param length : Int32 = 10
  def perform
    log "running for #{length} seconds"
    sleep length.seconds
  end
end
