module ErnestBot
  module Commands
    # Version : responds to ci
    class Version < SlackRubyBot::Commands::Base
      command 'version' do |client, data, _match|
        say = proc do |text|
          client.say(channel: data.channel, text: text)
        end

        check_ci_builds(File.readlines('ernest-repositories-list.txt'), nil, '', say)
      end
    end
  end
end
