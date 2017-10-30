# This Source Code Form is subject to the terms of the Mozilla Public
# # License, v. 2.0. If a copy of the MPL was not distributed with this
# # file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'thor'
require 'colorize'
require 'octokit'
require 'slack-notifier'
require 'atlas'
require_relative 'lib/versioner'

# CLI to release versions
class MyCLI < Thor
  desc 'notes NUMBER', 'Prints release notes for a specific version'
  def notes(number)
    @github = github_client
    puts release_notes(@github, number)
  end

  desc 'checkci FILE', 'Check all repos ci for develop branch'
  def checkci(file)
    check_ci_builds File.readlines(file)
  end

  desc 'version NUMBER FILE', 'Will bump a version for the given repos'
  def version(number, file)
    @github = github_client

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
    return if check_ci_builds(File.readlines(file), @slack, @slack_url) == false

    # Integrity verification
    msg = "Verifying if develop and master branch haven't diverged"
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
    msg = 'Creating release on ernest-cli'
    puts msg.blue
    @slack.ping msg unless @slack_url.empty?
    release_cli(@github, number, release_title)
    msg = '... done'
    puts msg.green
    @slack.ping msg unless @slack_url.empty?

    # Release docker components
    msg = 'Docker release started, this may take a while'
    puts msg.blue
    @slack.ping msg unless @slack_url.empty?

    @docker_username = ENV['DOCKER_USERNAME']
    @docker_username = ask 'Provide your docker hub username : ' if @docker_username.nil?

    @docker_password = ENV['DOCKER_PASSWORD']
    @docker_password = ask 'Provide your docker hub password : ' if @docker_password.nil?

    docker_release(@github, number, release_title, @docker_username, @docker_password)
    msg = '... done'
    puts msg.green
    @slack.ping msg unless @slack_url.empty?

    msg = "Well done! While you were in the pub, I've released version number #{number}"
    puts msg.green
    @slack.ping "#{msg} :tada:!!" unless @slack_url.empty?
  end

  no_commands do
  end
end

MyCLI.start(ARGV)
