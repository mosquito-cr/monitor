class ShortLivedRunner < Mosquito::Runner
  @run_start : Time = Time::UNIX_EPOCH
  property run_duration = 3.seconds
  property run_forever = false
  property keep_running = true

  def start
    @run_start = Time.utc

    run

    loop do
      sleep 1.seconds

      break unless keep_running?
    end

    stop
  end

  def stop
    self.keep_running = false
    super.receive
  end

  def current_run_length
    Time.utc - @run_start
  end

  def keep_running?
    if run_forever
      self.keep_running
    else
      self.keep_running && current_run_length < @run_duration
    end
  end
end
