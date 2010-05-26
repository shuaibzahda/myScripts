require "chat"
require "test/unit"
 
class ChattingTest < Test::Unit::TestCase

	def setup
		@chat = Chatting.new
	end

	def teardown
		@chat = nil
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

  def test_get_challange
    xml = "<challenge xmlns=\"urn:ietf:params:xml:ns:xmpp-sasl\">cmVhbG09ImNoYXQuZmFjZWJvb2suY29tIixub25jZT0iMzBEOUI1Rjc2QjVDODM1NTdBNzg2M0QyMkVBODkxQkMiLHFvcD0iYXV0aCIsY2hhcnNldD11dGYtOCxhbGdvcml0aG09bWQ1LXNlc3M=</challenge>"
    assert_equal(@chat.get_challange(xml),"realm=\"chat.facebook.com\",nonce=\"30D9B5F76B5C83557A7863D22EA891BC\",qop=\"auth\",charset=utf-8,algorithm=md5-sess") 
  end
  
  def test_getValuesFromDecoded
    decoded = "realm=chat.facebook.com,nonce=721AD450190AA49E435271944E4B6129,qop=auth,charset=utf-8,algorithm=md5-sess"
    md5Values = @chat.getValuesFromDecoded(decoded, ",")
    assert_equal(md5Values["algorithm"],"md5-sess")
    assert_equal(md5Values["charset"],"utf-8")
    assert_equal(md5Values["qop"],"auth")
    assert_equal(md5Values["nonce"],"721AD450190AA49E435271944E4B6129")
    assert_equal(md5Values["realm"],"chat.facebook.com")
   
 end
 
	 def test_construct_response
		md5Values = {}
		md5Values["algorithm"] = "md5-sess"
		md5Values["charset"] ="utf-8"
		md5Values["qop"] = "auth"
		md5Values["nonce"] = "721AD450190AA49E435271944E4B6129"
		md5Values["realm"] = "chat.facebook.com"
		username = "username"
		password = "password"
		response_value = @chat.construct_response(md5Values, username, password)
		assert_equal(response_value, "<response xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>dXNlcm5hbWU9InVzZXJuYW1lIixyZWFsbT1jaGF0LmZhY2Vib29rLmNvbSxu
					b25jZT03MjFBRDQ1MDE5MEFBNDlFNDM1MjcxOTQ0RTRCNjEyOSxjbm9uY2U9
					IjgyM2U2N2FhMmI0MGM5Mzg0OGIwNzMwNThmYzQ2YWMwIixuYz0wMDAwMDAw
					MSxxb3A9YXV0aCxkaWdlc3QtdXJpPSJ4bXBwL2NoYXQuZmFjZWJvb2suY29t
					IixyZXNwb25zZT02NTUyNzJmYTg0ZGViNGFlMmNhZTNhNDk2YjNmZDYzYyxj
					aGFyc2V0PXV0Zi04
					</response>")
	end

	def test_updateUserStatus
	  myfile = File.read("data/users.xml")
	  @chat.createUserList(myfile)
	  @chat.updateUserStatus("u1476193635@chat.facebook.com", "dnd")
	  friend = @chat.search_jid("u1476193635@chat.facebook.com")
	  assert_equal(friend.status, "dnd")
	  @chat.updateUserStatus("u1476193635@chat.facebook.com", "chat")
	  assert_equal(friend.status, "chat")
	end

	def test_online_users
		users = File.read("data/users.xml")
		@chat.createUserList(users)
		#receive presence
		presence = File.read("data/presence.xml")
		@chat.XMLProcessor(presence)
		assert_equal(10, @chat.countOnlineFriends)
	end

	def test_received_messages
		users = File.read("data/users.xml")
		@chat.createUserList(users)
		messages = File.read("data/messages.xml")
		@chat.XMLProcessor(messages)
		messages = @chat.getMessages
		assert_equal(3, messages.size)
	end
end
