#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'pp'

botlist = JSON.parse(open('botlist').read)
start_url = "http://www.neurobots.net/controller/LJaETkMFyHCGVBFHU3uDjelMoVra6qL7rIEgHZdecDjcRXNN2hAjHWHh7n3Y8T88qKxCsjx7dk1T3ccyNKQ/start/"

pp botlist

puts 'did you pkill -9 ruby* first?'

 botlist.each do |bot|

	open(start_url+bot[1]).read
# pp start_url+bot[1]

 end

