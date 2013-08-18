#!/usr/bin/env ruby

require 'rubygems'
require 'base32'
require 'sinatra'
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

# My one fucking global
$botlist = Hash.new

# Classes

class App 
	attr_accessor :pid, :type, :id, :mc, :port, :botlist

	def initialize(pid, type, id, mc)
		self.pid = pid
		self.type = type
		self.id = id
		self.mc = mc
	end
end

# Functions

# Prove the key is good
def valid_key(id,magickey)
  db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
  db.query("select id from users where magic_key='#{magickey}' AND bot_userid='#{id}'").each do |row|
		return true
	end
		return false
end

def get_port(id)
  key = ""
  db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
  db.query("select id from users where bot_userid='#{id}'").each do |row|
    key = row[0].to_i + 31000
  end
  return key
end

# Pull the key for the backdoor
def get_key(id)
	key = ""
	db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
	db.query("select magic_key from users where bot_userid='#{id}'").each do |row|
		key = row[0]
	end
	return key
end

# Start bot
def start_bot(id,magickey)
	# make sure the bot isn't running and then start it if it's not
	found = false
	# This should make sure the bot is not running anywhere in the system
	#list = JSON.decode(open("http://collector.neurobots.net/").read)
	db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
 	db.query("select userid from synergy_running_bots where userid='#{id}'").each do |row|
  	found = true
	end
	#@@botlist.keys.each { |bot| found = true if bot == id }
	if(!found)
#		`export BOTPORT='#{get_port(id)}'; export MAGICKEY='#{magickey}'; export BOTUSERID='#{id}'; cd ~/neuroserver/bot/current; nohup ./websocketProxy.rb #{id} > /dev/null &`
		newbot = Thread.new do
			bot = Neurobot.new(id,magickey)
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
		return "1"
	end
		return "0"
end

#reset what our db thinks of us
def reset_db
	db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
	db.query("delete from synergy_running_bots where controller='#{CONTROLLER}' and thread='#{THREAD}'")
end

# Stop bot
def stop_bot(id,magickey)
	found = false
	get_ps.each do |ps| 
		found = true if ps.id == id
		Process.kill('SIGKILL', ps.pid) if ps.id == id
	end
	return "1" if found
	return "0" 
end

# Status
def c_status(id,magickey)
	puts "c_status started #{id} #{magickey}"
  found = false
  get_ps.each do |ps|
  	found = true if ps.id == id
	end
  return "1" if found
  return "0"
end

# Get usable process list
def get_ps
  ps_list = []
	ProcTable.ps do |process| 
		#output += PP.pp(process,"") if process.comm.(/ruby/) 
		if process.comm.match(/ruby/)
			type  = ''
			type  = "ws" if process.cmdline.match(/websocketProxy.rb/)
			type  = "bc" if process.cmdline.match(/main.rb/)
			# "#{pid} #{type} #{botid} #{magic}\n" if type != ""
			ps_list.push(App.new(process.pid, type, process.environ['BOTUSERID'], process.environ['MAGICKEY'] )) if type != ''			
		end
	end 
return ps_list
end

# Lookups

class MyApp < Sinatra::Base

	attr_accessor :botlist

	reset_db

get "#{PREFIX}/" do
	"Controller #{THREAD} Online"
end

# Backdoor Start
get "#{PREFIX}/#{PHK}/start/:id" do |id|
	"Backdoor start called with id #{id} magic key: #{get_key(id)}"
	return start_bot(id,get_key(id))
end

# Backdoor Stop
get "#{PREFIX}/#{PHK}/stop/:id" do |id|
	"Backdoor stop called with id #{id}"
	return stop_bot(id,get_key(id))
end

# Backdoor Status
get "#{PREFIX}/#{PHK}/status/:id" do |id|
	"Backdoor status called with id #{id}"
	return c_status(id,get_key(id))
end

# Backdoor Console
get "#{PREFIX}/#{PHK}/console" do |id|
#  "Backdoor status called with id #{id}"
#  return c_status(id,get_key(id))
output = ""
get_ps.each do |bot|
	if bot.type = "bc"
	output += "#{bot.id} Stop<br />"
	end
end
return output
end

# Global stats
get "#{PREFIX}/status" do
	output  = "Controller stats\n"
	build_for_json = []
#	get_ps.each do |process|
#		build_for_json.push([THREAD, process.pid, process.id, get_port(process.id)]) if process.type == "bc"
#	end
#build_for_json.push([ CONTROLLER, THREAD, "test" ])
	#@@botlist.keys.each do |botuserid|
	#	build_for_json.push([ CONTROLLER, THREAD, botuserid ])
	#end
	db = Mysql::new("localhost", ENV['DBUSER'], ENV['DBPASS'], "neurobots")
  db.query("select * from synergy_running_bots").each do |row|
		build_for_json.push([ row[0], row[1], row[2] ])
	end
	return JSON.dump(build_for_json)
end

# Start
get "#{PREFIX}/start/:hash" do |hash|
	id, key = JSON.parse(Base32.decode(hash))
	"Start called with id #{id} and hash of #{key}"
	return start_bot(id,key) if valid_key(id,key)
  return 0
end

# Stop
get "#{PREFIX}/stop/:hash" do |hash|
  id, key = JSON.parse(Base32.decode(hash))
  "Stop called with id #{id} and hash of #{key}"
	return stop_bot(id,key) if valid_key(id,key)
	return 0
end

# Status
get "#{PREFIX}/status/:hash" do |hash|
  id, key = JSON.parse(Base32.decode(hash))
  "Status called with id #{id} and hash of #{key}"
  return c_status(id,key)
end

end






