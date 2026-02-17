require "mosquito"
require "./init"
require "./src/interactive_runner/*"

formatted_backend = Log::IOBackend.new(formatter: InteractiveLogStreamFormatter)

Log.setup do |logger|
  logger.bind "*",:info, formatted_backend
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
      runner.keep_running = false
      Signal::INT.reset
    end

    runner.start
    break

  else
    puts "Invalid choice"
  end
end
