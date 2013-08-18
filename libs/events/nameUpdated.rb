module Nameupdated

	def nameUpdatedInit
	puts "nameUpdateInit called".yellow
		self.client.on :user_name_updated do |user|
			puts ":user_name_updated called".red
			self.db.query("update bot_ustats_#{self.magickey} set name='#{self.db.escape_string(user.name)}' where userid='#{user.id}'")
		end

 	end

end
