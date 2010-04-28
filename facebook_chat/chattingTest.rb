require "chat"
require "test/unit"
 
class ChattingTest < Test::Unit::TestCase

	def setup
		@chat = Chatting.new
	end
	
	def test_good_getJID
		xml = '<iq id="bind_1" type="result"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><jid>shuaibzahda@chat.facebook.com/d9a2852b_484D38B3AA5A7</jid></bind></iq>'
		jid = @chat.getJID(xml)
		assert_equal(jid, "shuaibzahda@chat.facebook.com/d9a2852b_484D38B3AA5A7")
		
	end
	
	def test_is_number
		#bad input
		assert(!@chat.is_number(0))
		assert(!@chat.is_number("a"))
		#good input
		assert(@chat.is_number(4))
		assert(@chat.is_number(20))
   end
end
