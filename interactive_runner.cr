require "mosquito"
require "./init"

struct InteractiveLogStreamFormatter < Log::StaticFormatter
  def run
    severity
    string " "
    source
    string " "
    message
    string " "
    data
  end
end

formatted_backend = Log::IOBackend.new(formatter: InteractiveLogStreamFormatter)

Log.setup do |logger|
  logger.bind "*",:info, formatted_backend
  # logger.bind "redis.connection.*", :info, formatted_backend
  logger.bind "mosquito.redis_backend", :debug, formatted_backend
end

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
    super
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

class LongJob < Mosquito::QueuedJob
  def perform
    log "It only takes me 3 second to do this"
    sleep 3.seconds
  end
end

class EveryThreeSecondsJob < Mosquito::PeriodicJob
  run_every 3.seconds

  def perform
    log "I'm running every 3 seconds, taking 1 second"
    sleep 1.seconds
  end
end

class RandomLengthJob < Mosquito::QueuedJob
  param length : Int32 = 10
  def perform
    log "running for #{length} seconds"
    sleep length.seconds
  end
end

class FastJob < Mosquito::QueuedJob
  def perform
    log "I'm running fast"
  end
end

cli_arg = ARGV[0]?

loop do
  count = 1000
  duration = 3.seconds

  print <<-MENU
  1. Enqueue 100 random length jobs (1-10s ea)
  2. 100_000 fast jobs (~instantaneous)
  3. Enqueue #{count} long jobs
  4. Run worker indefinitely

  Choose: 
  MENU

  choice = cli_arg || gets
  cli_arg = nil

  next if choice.nil?

  case choice.chomp
  when "1"
    puts "Enqueuing 100 random length jobs."
    100.times { RandomLengthJob.new(length: Random.rand(10)).enqueue }

  when "2"
    puts "Enqueuing 100_000 fast jobs."
    100_000.times { FastJob.new.enqueue }

  when "3"
    puts "Enqueuing #{count} jobs."
    count.times { LongJob.new.enqueue }

  when "4"
    puts "Running worker indefinitely."

    runner = ShortLivedRunner.new
    runner.run_forever = true

    Signal::INT.trap do
      runner.stop
      Signal::INT.reset
    end

    runner.start
    break

  else
    puts "Invalid choice"
  end
end
