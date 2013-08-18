require './libs/syncUserList.rb'
require './libs/backgroundLoop.rb'
require './libs/eventsTraps.rb'
require './libs/processAntiIdle.rb'
require './libs/digest.rb'
require './libs/processTriggers.rb'
require './libs/processPkgB.rb'
require './libs/processAutoBop.rb'

class Neurobot

	include Syncuserlist, Digest, Backgroundloop, Eventstraps, Processantiidle, Processtriggers, Processpkgb, Processautobop

	attr_accessor	:client, :db, :userid, :authid, :roomid, :magickey, :thread

	def initialize(userid, magickey, thread)
		self.userid = userid
		self.magickey = magickey
		self.thread = thread
		punt
	end

	def punt

		# Create db handle
		
		@db = Mysql::new(DBHOST, DBUSER, DBPASS, DBTABLE)
		
		# Create our instance variables

		@botData  = Hash.new
		@queue 	  = Array.new
		@tabledjs = Array.new
		@snagged  = 0		
		
		# Load the first pass of bot variables		

		jOutput = JSON.parse((URI.parse("http://www.neurobots.net/websockets/pull.php?bot_userid=#{self.userid}&magic_key=#{self.magickey}")).read)
		
		#debugger
	
		@botData['authid'] = jOutput['bot_authid']
		@botData['roomid'] = jOutput['bot_roomid']
		@botData['ownerid'] = jOutput['owner_userid']
    @botData['running_timers'] =  []
		self.authid = @botData['authid']
		self.roomid = @botData['roomid']
		
		
	end
	
	def rehash(user)
		
		jOutput = JSON.parse((URI.parse("http://www.neurobots.net/websockets/pull.php?bot_userid=#{self.userid}&magic_key=#{self.magickey}")).read)
		
		@errorcounts = {}
		@antiIdle = []
		@sayings = []
		@autobop_count = 0
		@votes = []
		@anti_idle_running = false

		@botData['authid'] = jOutput['bot_authid']
		@botData['roomid'] = jOutput['bot_roomid']
		@botData['ownerid'] = jOutput['owner_userid']
		@botData['ads'] = jOutput['adverts']
		@botData['triggers'] = jOutput['triggers']
		@botData['command_trigger'] = jOutput['command_trigger']
		@botData['events'] = jOutput['events']
		@botData['events'].pop
		@botData['triggers'].pop
		@botData['ads'].pop
		@botData['level1acl'] = []
		@botData['level2acl'] = []
		@botData['level3acl'] = []
		@botData['queue'] = false
		@botData['slide'] = false
		@botData['autodj'] = false
		@botData['stats'] = false
		@botData['autoReQueue'] = false
		@botData['alonedj'] = false
		@botData['autobop'] = false
		@botData['flags'] = jOutput['flags'].to_s
		@botData['queue'] = true if jOutput['start_queue'].to_i == 1
		@botData['slide'] = true if jOutput['start_slide'].to_i == 1
		@botData['autodj'] = true if jOutput['start_autodj'].to_i == 1
		@botData['stats'] = true if jOutput['start_stats'].to_i == 1
		@botData['autoReQueue'] = true if jOutput['switch_autorequeue'].to_i == 1
		@botData['alonedj'] = true if jOutput['switch_alonedj'].to_i == 1
    @botData['autobop'] = true if jOutput['autobop'].to_i == 1
		# @botData['autobop'] = true
		jOutput['blacklist'].pop
		@botData['blacklist'] = jOutput['blacklist'].map {|h| h['userid']}
		
		@aclCount = jOutput['acl'].count
		jOutput['acl'].pop
		jOutput['acl'].each { |acl|
        @botData['level1acl'].push(acl['userid']) if acl['access_level'] == "1"
        @botData['level2acl'].push(acl['userid']) if acl['access_level'] == "2"
        @botData['level3acl'].push(acl['userid']) if acl['access_level'] == "3"
		}
		
		('B'..'B').each do |pkg|
        @botData['pkg_'+pkg.downcase+'_data'] = jOutput['pkg_'+pkg.downcase+'_data'][0] if /#{pkg}/ =~ @botData['flags']
		end

		@tabledjs = @client.room.djs.to_a if @botData['queue']


		if jOutput['mods_to_lvl1'].to_i == 1
    	self.client.room.moderators.each do |mod|
      	@botData['level1acl'].push(mod.id)
      end
		end

		self.db.query("select * from bot_sayings_#{self.magickey}").each do |row|
    	@sayings.push(row[0]);
    end
			
			flags = 'A'
			flags += 'B' if /B/ =~ @botData['flags']

		if user == nil
			self.client.room.say("#{CODENAME} #{VERSION}")
			#self.client.room.say("[Triggers: #{@botData['triggers'].count}][Ads: #{@botData['ads'].count}][Events: #{@botData['events'].count}][Acls: #{jOutput['acl'].count}][Sayings: #{@sayings.count}][Packages: #{flags}]") 
			self.client.room.say("[#{@botData['triggers'].count} triggers][#{@botData['ads'].count} ads][#{@botData['events'].count} events]")
			self.client.room.say("[#{jOutput['acl'].count} acls][#{@sayings.count} sayings]")
			self.client.room.say("[ #{flags} ]") 
		else
			user.say("#{CODENAME} #{VERSION}")
			user.say("[Triggers: #{@botData['triggers'].count}][Ads: #{@botData['ads'].count}][Events: #{@botData['events'].count}][Acls: #{jOutput['acl'].count}][Sayings: #{@sayings.count}][Packages: #{flags}]")
		end

		# Ad Spooler
    
		@botData['running_timers'].each { |timer| timer.cancel }
    @botData['running_timers'] =  []
    @botData['ads'].each do |ad|
    	timer = EventMachine::PeriodicTimer.new(ad['delay']) do
      	Turntabler.run { client.room.say ad['message'] }
      end
      @botData['running_timers'].push(timer)
    end
    rescue JSON::ParserError, SocketError
	end

end

