# :nocov:
# borrowed from architect4r
require 'os'
require 'httparty'
require 'zip'
require 'httparty'
require File.expand_path('../config_server', __FILE__)

namespace :neo4j do
  def file_name
    OS::Underlying.windows? ? 'neo4j.zip' : 'neo4j-unix.tar.gz'
  end

  def download_url(edition)
    "http://dist.neo4j.org/neo4j-#{edition}-#{OS::Underlying.windows? ? 'windows.zip' : 'unix.tar.gz'}"
  end

  def download_neo4j_unless_exists(edition)
    download_neo4j(edition) unless File.exist?(file_name)
  end

  def download_neo4j(edition)
    success = false

    File.open(file_name, 'wb') do |file|
      file << request_url(download_url(edition))
      success = true
    end

    file_name
  ensure
    File.delete(file_name) unless success
  end

  def request_url(url)
    status = HTTParty.head(url).code
    fail "#{edition} is not available to download, try a different version" if status < 200 || status >= 300

    HTTParty.get(url)
  end

  def get_environment(args)
    args[:environment] || 'development'
  end

  def install_location(args)
    FileUtils.mkdir_p('db/neo4j')
    "db/neo4j/#{get_environment(args)}"
  end

  def config_location(args)
    "#{install_location(args)}/conf/neo4j-server.properties"
  end

  def start_server(command, args)
    puts "Starting Neo4j #{get_environment(args)}..."
    if OS::Underlying.windows?
      start_windows_server(command, args)
    else
      start_starnix_server(command, args)
    end
  end

  def start_windows_server(command, args)
    if `reg query "HKU\\S-1-5-19"`.size > 0
      `#{install_location(args)}/bin/Neo4j.bat #{command}`  # start service
    else
      puts 'Starting Neo4j directly, not as a service.'
      `#{install_location(args)}/bin/Neo4j.bat`
    end
  end

  def start_starnix_server(command, args)
    `#{install_location(args)}/bin/neo4j #{command}`
  end

  desc 'Install Neo4j with auth disabled in v2.2+, example neo4j:install[community-2.1.3,development]'
  task :install, :edition, :environment do |_, args|
    edition = args[:edition]
    environment = get_environment(args)
    puts "Installing Neo4j-#{edition} environment: #{environment}"

    downloaded_file = download_neo4j_unless_exists edition

    if OS::Underlying.windows?
      # Extract and move to neo4j directory
      unless File.exist?(install_location(args))
        Zip::ZipFile.open(downloaded_file) do |zip_file|
          zip_file.each do |f|
            f_path = File.join('.', f.name)
            FileUtils.mkdir_p(File.dirname(f_path))
            begin
              zip_file.extract(f, f_path) unless File.exist?(f_path)
            rescue
              puts "#{f.name} failed to extract."
            end
          end
        end
        FileUtils.mv "neo4j-#{edition}", install_location(args)
        FileUtils.rm downloaded_file
      end

      # Install if running with Admin Privileges
      if `reg query "HKU\\S-1-5-19"`.size > 0
        `"#{install_location(args)}/bin/neo4j install"`
        puts 'Neo4j Installed as a service.'
      end

    else
      `tar -xvf #{downloaded_file}`
      `mv neo4j-#{edition} #{install_location(args)}`
      `rm #{downloaded_file}`
      puts 'Neo4j Installed in to neo4j directory.'
    end
    rake_auth_toggle(args, :disable) unless /-2\.0|1\.[0-9]/.match(args[:edition])
    puts "Type 'rake neo4j:start' or 'rake neo4j:start[ENVIRONMENT]' to start it\nType 'neo4j:config[ENVIRONMENT,PORT]' for changing server port, (default 7474)"
  end

  desc 'Start the Neo4j Server'
  task :start, :environment do |_, args|
    start_server('start', args)
  end

  desc 'Start the Neo4j Server asynchronously'
  task :start_no_wait, :environment do |_, args|
    start_server('start-no-wait', args)
  end

  desc 'Configure Server, e.g. rake neo4j:config[development,8888]'
  task :config, :environment, :port do |_, args|
    port = args[:port]
    fail 'no port given' unless port
    puts "Config Neo4j #{get_environment(args)} for port #{port}"
    location = config_location(args)
    text = File.read(location)
    replace = Neo4j::Tasks::ConfigServer.config(text, port)
    File.open(location, 'w') { |file| file.puts replace }
  end

  desc 'Stop the Neo4j Server'
  task :stop, :environment do |_, args|
    puts "Stopping Neo4j #{get_environment(args)}..."
    if OS::Underlying.windows?
      if `reg query "HKU\\S-1-5-19"`.size > 0
        `#{install_location(args)}/bin/Neo4j.bat stop`  # stop service
      else
        puts 'You do not have administrative rights to stop the Neo4j Service'
      end
    else
      `#{install_location(args)}/bin/neo4j stop`
    end
  end

  desc 'Get info the Neo4j Server'
  task :info, :environment do |_, args|
    puts "Info from Neo4j #{get_environment(args)}..."
    if OS::Underlying.windows?
      if `reg query "HKU\\S-1-5-19"`.size > 0
        `#{install_location(args)}/bin/Neo4j.bat info`  # stop service
      else
        puts 'You do not have administrative rights to get info from the Neo4j Service'
      end
    else
      puts `#{install_location(args)}/bin/neo4j info`
    end
  end

  desc 'Restart the Neo4j Server'
  task :restart, :environment do |_, args|
    puts "Restarting Neo4j #{get_environment(args)}..."
    if OS::Underlying.windows?
      if `reg query "HKU\\S-1-5-19"`.size > 0
        `#{install_location(args)}/bin/Neo4j.bat restart`
      else
        puts 'You do not have administrative rights to restart the Neo4j Service'
      end
    else
      `#{install_location(args)}/bin/neo4j restart`
    end
  end

  desc 'Reset the Neo4j Server'
  task :reset_yes_i_am_sure, :environment do |_, args|
    # Stop the server
    if OS::Underlying.windows?
      if `reg query "HKU\\S-1-5-19"`.size > 0
        `#{install_location(args)}/bin/Neo4j.bat stop`

        # Reset the database
        FileUtils.rm_rf("#{install_location(args)}/data/graph.db")
        FileUtils.mkdir("#{install_location(args)}/data/graph.db")

        # Remove log files
        FileUtils.rm_rf("#{install_location(args)}/data/log")
        FileUtils.mkdir("#{install_location(args)}/data/log")

        `#{install_location(args)}/bin/Neo4j.bat start`
      else
        puts 'You do not have administrative rights to reset the Neo4j Service'
      end
    else
      `#{install_location(args)}/bin/neo4j stop`

      # Reset the database
      FileUtils.rm_rf("#{install_location(args)}/data/graph.db")
      FileUtils.mkdir("#{install_location(args)}/data/graph.db")

      # Remove log files
      FileUtils.rm_rf("#{install_location(args)}/data/log")
      FileUtils.mkdir("#{install_location(args)}/data/log")

      # Start the server
      `#{install_location(args)}/bin/neo4j start`
    end
  end

  desc 'Neo4j 2.2: Change connection password'
  task :change_password do
    puts 'This will change the password for a Neo4j server'
    puts 'Enter target IP address or host name without protocal and port, press enter for http://localhost:7474'
    address = STDIN.gets.chomp
    target_address = address.empty? ? 'http://localhost:7474' : address

    puts 'Input current password. Leave blank if this is a fresh installation of Neo4j.'
    password = STDIN.gets.chomp
    old_password = password.empty? ? 'neo4j' : password

    puts 'Input new password.'
    new_password = STDIN.gets.chomp
    fail 'A new password is required' if new_password.empty?

    body = Neo4j::Tasks::ConfigServer.change_password(target_address, old_password, new_password)
    if body['errors']
      puts "An error was returned: #{body['errors'][0]['message']}"
    else
      puts 'Password changed successfully! Please update your app to use:'
      puts 'username: neo4j'
      puts "password: #{new_password}"
    end
  end

  def rake_auth_toggle(args, status)
    location = config_location(args)
    text = File.read(location)
    replace = Neo4j::Tasks::ConfigServer.toggle_auth(status, text)
    File.open(location, 'w') { |file| file.puts replace }
  end

  def auth_toggle_complete(status)
    puts "Neo4j basic authentication #{status}. Restart server to apply."
  end

  desc 'Neo4j 2.2: Enable Auth'
  task :enable_auth, :environment do |_, args|
    rake_auth_toggle(args, :enable)
    auth_toggle_complete('enabled')
  end

  desc 'Neo4j 2.2: Disable Auth'
  task :disable_auth, :environment do |_, args|
    rake_auth_toggle(args, :disable)
    auth_toggle_complete('disabled')
  end
end
