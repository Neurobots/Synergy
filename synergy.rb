#!/usr/bin/env ruby

require 'rubygems'
require 'base32'
require 'sinatra/base'
require 'thin'
require 'mysql'
require 'json'
require 'ap'
require 'sys/proctable'
require 'turntabler'
require 'monitor'
require 'eventmachine'
require 'json'
require 'open-uri'
require 'pp'
require 'digest/md5'
require 'nokogiri'
require 'debugger'
require 'colorize'

require './neurobot.rb'

CODENAME = "Synergy"
VERSION  = "0.1 Alpha"

DBHOST   = 'localhost'
DBTABLE  = 'neurobots'


include Sys
# Yea this means nothing
PHK = 'LJaETkMFyHCGVBFHU3uDjelMoVra6qL7rIEgHZdecDjcRXNN2hAjHWHh7n3Y8T88qKxCsjx7dk1T3ccyNKQ'

# our friend haproxy
PREFIX = '/controller'

# Become self aware
CONTROLLER = 1
THREAD = `ps -aef | grep #{Process.pid}| awk '{print $11;}'`.scan(/\d/).first.to_i

# Check for db username

abort "No dbuser in envrioment variable" if !ENV.include? 'DBUSER'

# Set constatnt for db username

DBUSER = ENV['DBUSER'] if ENV.include? 'DBUSER'

# Check for db pass

abort "No db pass in envrioment variable" if !ENV.include? 'DBPASS'

# Set constatnt for DBPASS

DBPASS = ENV['DBPASS'] if ENV.include? 'DBPASS'

$botlist = Hash.new


# Pull the key for the backdoor
def get_key(id)
  key = ""
  db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
  db.query("select magic_key from users where bot_userid='#{id}'").each do |row|
    key = row[0]
  end
  return key
end

# Start a bot with the botuserid / magickey provided
def start_bot( id, magickey )

	found = false
	db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
  db.query("select userid from synergy_running_bots where userid='#{id}'").each do |row|
    found = true
  end
  if(!found)
    newbot = Thread.new do
			me = newbot
      bot = Neurobot.new(id,magickey,me)
			Turntabler.interactive
      Turntabler.run do
        bot.client = Turntabler::Client.new('', '', :room => bot.roomid, :user_id => bot.userid, :auth => bot.authid, :reconnect => true, :reconnect_wait => 15)
        # Pull in all the information and spit out the startup
        bot.rehash(nil)
        # Sync the user database with the current room settings
        bot.syncUserList
#       Start Auto dj watcher, alone dj watcher, and blacklist watcher
        bot.backgroundLoopInit
        bot.trapEvents
      end
    end
    $botlist[id] = newbot
  	db.query("insert into synergy_running_bots values ('#{CONTROLLER}', '#{THREAD}', '#{id}') ")
    return "1"
  end
    return "0"
end

def stop_bot( id )
	
  db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
  db.query("delete from synergy_running_bots where userid='#{id}'")
	
	$botlist[id].kill	

	$botlist.delete(id)

end





# This example shows you how to embed Sinatra into your EventMachine
# application. This is very useful if you're application needs some
# sort of API interface and you don't want to use EM's provided
# web-server.

def run(opts)

  # Start he reactor
  EM.run do

    # define some defaults for our app
    server  = opts[:server] || 'thin'
    host    = opts[:host]   || '0.0.0.0'
    port    = opts[:port]   || '4001'
    web_app = opts[:app]

    # create a base-mapping that our application will set at. If I
    # have the following routes:
    #
    #   get '/hello' do
    #     'hello!'
    #   end
    #
    #   get '/goodbye' do
    #     'see ya later!'
    #   end
    #
    # Then I will get the following:
    #
    #   mapping: '/'
    #   routes:
    #     /hello
    #     /goodbye
    #
    #   mapping: '/api'
    #   routes:
    #     /api/hello
    #     /api/goodbye
    dispatch = Rack::Builder.app do
      map '/' do
        run web_app
      end
    end

    # NOTE that we have to use an EM-compatible web-server. There
    # might be more, but these are some that are currently available.
    unless ['thin', 'hatetepe', 'goliath'].include? server
      raise "Need an EM webserver, but #{server} isn't"
    end

    # Start the web server. Note that you are free to run other tasks
    # within your EM instance.
    Rack::Server.start({
      app:    dispatch,
      server: server,
      Host:   host,
      Port:   port
    })
  end
end

# Our simple hello-world app
class HelloApp < Sinatra::Base
  # threaded - False: Will take requests on the reactor thread
  #            True:  Will queue request for background thread
  configure do
    set :threaded, true
	end

  # Request runs on the reactor thread (with threaded set to false)
	get "#{PREFIX}/#{PHK}/start/:id" do |id|
		#"#{id} #{get_key(id)}"
		start_bot(id, get_key(id))
  end

	get "#{PREFIX}/#{PHK}/stop/:id" do |id|
		#"#{id} #{get_key(id)}"
		stop_bot(id)
		return "1"
  end

 #	get "#{PREFIX}/#{PHK}/start/:id" do |id|
 #		#"#{id} #{get_key(id)}"
 #		start_bot(id, get_key(id))
 # end

  # Request runs on the reactor thread (with threaded set to false)
  # and returns immediately. The deferred task does not delay the
  # response from the web-service.
  get '/delayed-hello' do
    EM.defer do
      sleep 5
    end
    'I\'m doing work in the background, but I am still free to take requests'
  end
end

# start the application
run app: HelloApp.new
