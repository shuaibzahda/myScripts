require "chat"
class Facebook
	def initialize
		chatting = Chatting.new
		chatting.connection
	end
end

x = Facebook.new
