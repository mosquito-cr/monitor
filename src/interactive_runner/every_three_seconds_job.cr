class EveryThreeSecondsJob < Mosquito::PeriodicJob
  run_every 3.seconds

  def perform
    log "I'm running every 3 seconds, taking 1 second"
    sleep 1.seconds
  end
end
