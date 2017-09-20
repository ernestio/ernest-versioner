require 'colorize'
require 'json'
require 'octokit'

def check_ci_builds(lines, slack = nil, slack_url = '', say = nil)
  msg = 'Checking ernestio CIs'
  puts msg.blue
  slack.ping msg unless slack_url.empty?
  say.call(msg) unless say.nil?
  failed_builds = []
  lines.map do |line|
    repo_name = line.slice((line.index(':') + 1)..(line.index('.git') - 1))
    url = "https://circleci.com/api/v1.1/project/github/#{repo_name}/tree/develop"
    resp = Net::HTTP.get_response(URI.parse(url))
    result = JSON.parse(resp.body)
    unless result[0]['failed'].nil?
      msg = "Aborting due to a broken build for #{repo_name} : #{result[0]['build_url']}"
      puts ''
      puts msg.red
      failed_builds << msg
      slack.ping msg unless slack_url.empty?
      say.call("#{msg} :boom:") unless say.nil?
    end
    putc '.'
  end
  return false unless failed_builds.empty?
  msg = 'All green!'
  puts msg.green
  slack.ping msg unless slack_url.empty?
  say.call("#{msg} :tada:") unless say.nil?
  true
end

def github_client
  @github_token = ENV['GITHUB_TOKEN']
  if @github_token.nil?
    puts 'Please define a GITHUB_TOKEN environment variable on your system before running this command'
    @github_token = ask 'A Github token is needed to perform the release please introduce yours : '
    if @github_token == ''
      puts 'Github token is required you can provide it with this inline tool or by using GITHUB_TOKEN environment variable'
      return
    end
  end
  Octokit::Client.new(access_token: @github_token)
end

def verified?(file)
  e! 'rm -rf /tmp/verify 2 > /dev/null'
  e! 'mkdir -p /tmp/verify'
  e! "verify #{file}"
  $?.success?
end

# Executes a command and checks the output
def e!(command)
  `#{command}`
  abort "Command '#{command}' finished with an errored satus" unless $?.success?
end

def bump_version(repo, number)
  e! 'mkdir -p tmp'
  e! "rm -rf tmp && git clone #{repo} tmp"
  e! 'cd tmp && git checkout develop'
  e! "cd tmp && echo #{number} > VERSION && git add . && git commit -m 'Bump version #{number}' && git push origin develop"
  e! 'cd tmp && git fetch && git checkout master'
  e! 'cd tmp && git merge --no-edit develop'
  e! "cd tmp && git tag -a #{number} -m 'Bump version #{number}'"
  e! 'cd tmp && git push origin master --tags'
end

def release_notes(github, number)
  @notes = ''
  @issue_types = { 'new feature' => 'New features', 'bug' => 'Bugs', 'improvement' => 'Improvements' }

  @issue_types.each do |t, title|
    @notes += issue_type_summary(github, number, t, title)
  end
  @notes
end

def issue_type_summary(github, number, type, title)
  @list = ''
  issues = github.issues 'ernestio/ernest', per_page: 100, labels: "#{number},#{type}", state: 'closed'
  return '' if (issues.length == 0)
  issues.each do |i|
    @list += "\n#{i.title} [#{i.id}](#{i.url})"
  end
  @notes += "\n\n #{title}"
  @notes += "\n--------------------"
  @notes += "\n" + @list
end

# Creates an ernest-cli release
def release_cli(github, number, title)
  github.create_release('ernestio/ernest-cli', number, name: title, body: "Bump version #{number}")
  path = "#{ENV['GOPATH']}/src/github.com/ernestio/"
  e! "rm -rf #{path}ernest-cli && cd #{path}"
  e! "cd #{path}  && git clone git@github.com:ernestio/ernest-cli"
  e! 'go get github.com/aktau/github-release'
  e! "cd #{path}ernest-cli/ && git checkout master && make dist"
  ["ernest-#{number}-darwin-386.zip",
   "ernest-#{number}-darwin-amd64.zip",
   "ernest-#{number}-linux-386.zip",
   "ernest-#{number}-linux-amd64.zip",
   "ernest-#{number}-windows-386.zip",
   "ernest-#{number}-windows-amd64.zip"].each do |file_name|
    e! "cd #{path}ernest-cli/ && github-release upload --user ernestio --repo ernest-cli --tag #{number} --name #{file_name} --file #{file_name}"
  end
end

# Docker compose release
def docker_release(github, number, title, user, pass)
  e! 'rm -rf /tmp/composable && mkdir -p /tmp/composable'
  e! 'rm -rf /tmp/ernest'
  e! 'cd /tmp && git clone git@github.com:ernestio/ernest.git'
  e! 'cd /tmp/ernest/ && git checkout develop'
  e! "cd /tmp/ernest/ && composable release -E ERNEST_CRYPTO_KEY=CRYPTO_KEY_TEMPLATE -u #{user} -p #{pass} -version #{number} -org ernestio definition.yml template.yml"
  e! "cd /tmp/ernest/ && git add docker-compose.yml && git commit -m 'Bump version #{number}' && git push origin develop"
  e! "cd /tmp/ernest/ && git checkout master && git rebase develop && git push origin master"

  @notes = release_notes github, number
  github.create_release('ernestio/ernest', number, name: title, body: @notes)
end

# Release vagrant box on Atlas
def vagrant_artifacts(number, title)
  e! 'cd /tmp && git clone git@github.com:ernestio/ernest-vagrant.git'
  e! 'cd /tmp/ernest-vagrant && git checkout develop'
  e! 'cd /tmp/ernest-vagrant && berks vendor cookbooks'
  e! 'cd /tmp/ernest-vagrant && vagrant up'
  e! 'cd /tmp/ernest-vagrant && vagrant package'
  e! 'cd /tmp/ernest-vagrant && vagrant destroy -f'

  box = Atlas::Box.find('R3Labs/ernest')
  version = box.create_version(version: number, description: title)
  provider = version.create_provider(name: 'virtualbox')
  provider.upload(File.open('/tmp/ernest-vagrant/package.box'))
  version.release
end
