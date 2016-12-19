module ErnestBot
  module Commands
    # Notes : responds to notes with a list of release notes
    class Notes < SlackRubyBot::Commands::Base
      command 'notes' do |client, data, _match|
        words = data.text.split(' ')
        if words.length < 3
          client.say(channel: data.channel, text: 'You should specify the version number')
          return
        end
        @github = github_client
        notes = release_notes(@github, words[2])
        client.say(channel: data.channel, text: "Release notes for version #{words[2]}")
        client.say(channel: data.channel, text: notes)
      end
    end
  end
end
