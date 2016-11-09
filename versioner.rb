# This Source Code Form is subject to the terms of the Mozilla Public
# # License, v. 2.0. If a copy of the MPL was not distributed with this
# # file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'thor'
require 'colorize'
require 'octokit'
require 'slack-notifier'
require 'atlas'

# CLI to release versions
class MyCLI < Thor
  desc 'version NUMBER FILE', 'Will bump a version for the given repos'
  def version(number, file)
    @github_token = ENV['GITHUB_TOKEN']
    if @github_token.nil?
      puts 'Please define a GITHUB_TOKEN environment variable on your system before running this command'
      @github_token = ask 'A Github token is needed to perform the release please introduce yours : '
      if @github_token == ''
        puts 'Github token is required you can provide it with this inline tool or by using GITHUB_TOKEN environment variable'
        return
      end
    end
    @github = Octokit::Client.new(access_token: @github_token)

    @slack_url = ENV['SLACK_WEBHOOK_URL']
    if @slack_url.nil?
      puts 'In case you want versioner to push updates to your slack channel please provide your webhook url'
      @slack_url = ask 'Slack webhook URL : '
    end
    @slack = Slack::Notifier.new(@slack_url) unless @slack_url.empty?

    @atlas_token = ENV['ATLAS_TOKEN']
    @atlas_token = ask 'Provide your atlas token : ' if @atlas_token.nil?
    Atlas.configure do |config|
      config.access_token = @atlas_token
    end

    puts 'In order to fully automate your release process we need you to provide some extra info'
    release_title = ask('Release title : ')

    @slack.ping "Starting release #{number}" unless @slack_url.empty?

    # Integrity verification
    msg = "Verifying develop and master branch haven't diverged"
    puts msg.blue
    @slack.ping msg unless @slack_url.empty?
    unless verified? file
      msg = 'Some errors were detected trying to verify specified repos, fix problems and try again'
      puts msg.red
      @slack.ping msg unless @slack_url.empty?
      return
    end
    msg = '... done'
    puts msg.green
    @slack.ping msg unless @slack_url.empty?

    # Versioning repos
    msg = 'Versioning specified repos'
    puts msg.blue
    @slack.ping msg unless @slack_url.empty?
    File.readlines(file).map do |line|
      msg = "- [ ] Versioning #{line.strip}"
      puts msg
      @slack.ping msg unless @slack_url.empty?
      bump_version(line.strip, number)
    end
    msg = '... done'
    puts msg.green
    @slack.ping msg unless @slack_url.empty?

    # Releasing ernest-cli
    msg 'Creating release on ernest-cli'
    puts msg.blue
    @slack.ping msg unless @slack_url.empty?
    release_cli(@github, number, release_title)
    msg = '... done'
    puts msg.green
    @slack.ping msg unless @slack_url.empty?

    # Release docker components
    msg 'Docker release started, this may take a while'
    puts msg.blue
    @slack.ping msg unless @slack_url.empty?
    docker_release(number, release_title)
    msg = '... done'
    puts msg.green
    @slack.ping msg unless @slack_url.empty?

    # Upload vagrant artifacts
    msg 'Generating vagrant artifacts, this may take a while'
    puts msg.blue
    @slack.ping msg unless @slack_url.empty?
    vagrant_artifacts(number, release_title)
    msg = '... done'
    puts msg.green
    @slack.ping msg unless @slack_url.empty?

    msg = "Well done! While you were in the pub, I've released version number #{number}"
    puts msg.green
    @slack.ping "#{msg} :tada:!!" unless @slack_url.empty?
  end

  def verified?(file)
    e! 'rm /tmp/verify'
    e! 'mkdir /tmp/verify'
    e! "verify #{file}"
    $CHILD_STATUS.success?
  end

  # Executes a command and checks the output
  def e!(command)
    `#{command}`
    abort "Command '#{command}' finished with an errored satus" unless $CHILD_STATUS.success?
  end

  def bump_version(_repo, number)
    e! 'mkdir -p tmp'
    e! 'rm -rf tmp && git clone #{repo} tmp'
    e! 'cd tmp && git checkout develop'
    e! "cd tmp && echo #{number} > VERSION && git add . && git commit -m 'Bump version #{number}' && git push origin develop"
    e! 'cd tmp && git fetch && git checkout master'
    e! 'cd tmp && git merge --no-edit develop'
    e! "cd tmp && git tag -a #{number} -m 'Bump version #{number}'"
    e! 'cd tmp && git push origin master --tags'
  end

  def release_notes(github, number)
    @notes = ''
    @issue_types = { 'bug' => 'Bugs', 'new feature' => 'New features', 'improvement' => 'Improvements' }

    @issue_types.each_with_index do |t, title|
      @notes += "\n\n #{title}"
      @notes += "\n--------------------"
      @notes += "\n" + issue_type_summary(github, number, t)
    end
    @notes
  end

  def issue_type_summary(github, number, type)
    @list = ''
    issues = github.issues 'ernestio/ernest', per_page: 100, labels: "#{number},#{type}", state: 'closed'
    issues.each do |i|
      @list += "\n#{i.title} [#{i.id}](#{i.url})"
    end
    @list
  end

  # Creates an ernest-cli release
  def release_cli(github, number, title)
    github.create_release('ernest/ernest-client', number, name: title, body: "Bump version #{number}")
    e! 'cd /tmp/'
    e! 'cd /tmp && git clone git@github.com:ernestio/ernest-cli'
    e! 'go get github.com/aktau/github-release'
    e! 'cd /tmp/ernest-cli/ && git checkout master && make dist'
    ["ernest-#{number}-darwin-386.zip",
     "ernest-#{number}-darwin-amd64.zip",
     "ernest-#{number}-linux-386.zip",
     "ernest-#{number}-linux-amd64.zip",
     "ernest-#{number}-windows-386.zip",
     "ernest-#{number}-windows-amd64.zip"].each do |_file_name|
       e! "cd /tmp/ernest-cli/ && github-release upload --user ernestio --repo ernest-cli --tag #{number} --name " # {file_name}" --file #{file_name}"
     end
  end

  # Docker compose release
  def docker_release(github, number, title)
    e! 'cd /tmp && git clone git@github.com:ernestio/ernest.git'
    e! "cd /tmp/ernest/ && composable release -version #{number} -org ernestio definition.yml template.yml"
    e! "cd /tmp/ernest/ && git add docker-compose.yml && git commit -m 'Bump version #{number}' && git push origin master"

    @notes = release_notes github, number
    github.create_release('ernest/ernest', number, name: title, body: @notes)
  end

  # Release vagrant box on Atlas
  def vagrant_artifacts(number, title)
    e! 'cd /tmp && git clone git@github.com:ernestio/ernest-vagrant.git'
    e! 'cd /tmp/ernest-vagrant && git checkout develop'
    e! 'cd /tmp/ernest-vagrant && berks vendor cookbooks'
    e! 'cd /tmp/ernest-vagrant && vagrant up'
    e! 'cd /tmp/ernest-vagrant && vagrant package'
    e! 'cd /tmp/ernest-vagrant && vagrant destroy'

    box = Atlas::Box.find('R3Labs/ernest')
    version = box.create_version(version: number, description: title)
    provider = version.create_provider(name: 'virtualbox')
    provider.upload(File.open('/tmp/ernest-vagrant/package.box'))
    version.release
  end
end

MyCLI.start(ARGV)
