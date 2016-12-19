$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'dotenv'
Dotenv.load

require 'ernest_bot'
require 'web'

Thread.abort_on_exception = true

Thread.new do
  begin
    ErnestBot::Bot.run
  rescue StandardError => e
    STDERR.puts "ERROR: #{e}"
    STDERR.puts e.backtrace
    raise e
  end
end

run ErnestBot::Web
