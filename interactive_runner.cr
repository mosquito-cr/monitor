require "mosquito"
require "./init"
require "./src/interactive_runner/*"

formatted_backend = Log::IOBackend.new(formatter: InteractiveLogStreamFormatter)

Log.setup do |logger|
  logger.bind "*",:info, formatted_backend
  logger.bind "redis.connection.*", :info, formatted_backend
  logger.bind "mosquito.redis_backend", :info, formatted_backend
  logger.bind "mosquito.overseer", :trace, formatted_backend
end

runner = ShortLivedRunner.new

Process.on_terminate do |reason|
  exit unless runner.state.started?

  case reason
  when .interrupted? # INT
    unless runner.keep_running?
      puts "\nSIGINT received again, exiting immediately."
      runner.stop
    end

    runner.keep_running = false
  when .aborted? # QUIT / ABORT / KILL (send ctrl+\)
    runner.stop
  end
end

cli_arg = ARGV[0]?

if cli_arg.to_s.chomp == "--help"
  puts <<-HELP
  Usage: crystal run interactive_runner.cr [option]

  Options:
    --enqueue-random   Enqueue 100 random length jobs (1-10s ea).
    --enqueue-fast     Enqueue 100_000 fast jobs (~instantaneous).
    --enqueue-long     Enqueue 1000 long jobs.
    --worker           Run worker indefinitely.
    --help             Show this message.
  HELP

  exit(0)
end

choice = cli_arg.to_s

loop do
  count = 1000
  duration = 3.seconds

  case choice.chomp
  when "1", "--enqueue-random"
    puts "Enqueuing 100 random length jobs."
    100.times { RandomLengthJob.new(length: Random.rand(10)).enqueue }

  when "2", "--enqueue-fast"
    puts "Enqueuing 100_000 fast jobs."
    100_000.times { FastJob.new.enqueue }

  when "3", "--enqueue-long"
    puts "Enqueuing #{count} jobs."
    count.times { LongJob.new.enqueue }

  when "4", "--worker"
    puts "Running worker indefinitely."

    runner.run_forever = true

    runner.start
    break

  when ""
  else
    puts "Invalid choice"
  end

  if choice.starts_with?("--")
    exit
  end

  print <<-MENU
  1. Enqueue 100 random length jobs (1-10s ea)
  2. 100_000 fast jobs (~instantaneous)
  3. Enqueue #{count} long jobs
  4. Run worker indefinitely

  Choose: 
  MENU

  choice = gets.to_s
end
