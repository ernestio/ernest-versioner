module ErnestBot
  module Commands
    # Ci : responds to ci
    class Ci < SlackRubyBot::Commands::Base
      command 'ci' do |client, data, _match|
        say = proc do |text|
          client.say(channel: data.channel, text: text)
        end

        check_ci_builds(File.readlines('ernest-repositories-list.txt'), nil, '', say)
      end
    end
  end
end
