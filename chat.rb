require "socket"  
require "openssl"
require "base64"
require 'rexml/document'
require 'digest/md5'

class StdClass

	@@friends = []
	def initialize
		
	end
	
	def getJID(text)
		#text = '<iq id="bind_1" type="result"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><jid>shuaibzahda@chat.facebook.com/d9a2852b_484D38B3AA5A7</jid></bind></iq>'
		jid = []
		data, others = REXML::Document.new(text), []
		data.elements.each("iq/bind/*") do |ele|
			jid = ele.text.split("/")
		end	
		jid
	end
	
	def get_challange(text)
		cipher = ""
		data, others = REXML::Document.new(text), []
		data.elements.each do |ele|
			#puts ele.name
			cipher = ele.text
		end
		Base64.decode64(cipher)
	end
	
	def getValuesFromDecoded(text, separator)
		values = {}
		text.split(separator).each do |pair|
			val = pair.split("=")
			values[val[0]] = val[1]
		end
		values
	end
	
	def construct_response(hash, username, password)
		response = {}
		response["username"] = "\"" + username + "\""
		response["realm"] = hash["realm"]
		response["nonce"] = hash["nonce"]
		response["nc"] = "00000001"
		response["qop"] = hash["qop"].gsub("\"", '')
		response["digest-uri"] = "\"xmpp/chat.facebook.com\""
		response["charset"] = hash["charset"]
		response["cnonce"] = "\"" + Digest::MD5.hexdigest("al-zahi") + "\""
		
		#creating response entry
		# 1. Create a string of the form "username:realm:password". Call this string X.
		x = username + ":" + response["realm"].gsub("\"", '') + ":" + password
		#2. Compute the 16 octet MD5 hash of X. Call the result Y.
		y = Digest::MD5.digest(x)
		#3. Create a string of the form "Y:nonce:cnonce". Call this string A1.
		#authzid="rob@cataclysm.cx/myResource"
		a1 = y + ":" + response["nonce"].gsub("\"", '') + ":" + response["cnonce"].gsub("\"", '')
		#4. Create a string of the form "AUTHENTICATE:digest-uri". Call this string A2.
		a2 = "AUTHENTICATE:xmpp/chat.facebook.com"
		#5. Compute the 32 hex digit MD5 hash of A1. Call the result HA1.
		ha1 = Digest::MD5.hexdigest(a1)
		#6. Compute the 32 hex digit MD5 hash of A2. Call the result HA2.
		ha2 = Digest::MD5.hexdigest(a2)
		#7. Create a string of the form "HA1:nonce:nc:cnonce:qop:HA2". Call this string KD.
		kd = ha1 + ":" + response["nonce"].gsub("\"", '') + ":" + response["nc"] + ":" + response["cnonce"].gsub("\"", '') + ":" + response["qop"] + ":" + ha2
		#8. Compute the 32 hex digit MD5 hash of KD. Call the result Z.
		z = Digest::MD5.hexdigest(kd)
		response["response"] = z
		
		#now create the string and send it to the main function for decryption
		#username="someone    ",realm="chat.facebook.com",nonce="67ED7BA876807C28B3AB6FA634FA1605",cnonce="d33c8862126626563771097b70",nc=00000001,qop=auth,digest-uri="xmpp/chat.facebook.com",response=520a27b9dc9195dc12c55cdf81529b62,charset=utf-8

		response_auth = "username=" + response["username"] + ",realm=" + response["realm"] + ",nonce=" +
						response["nonce"] + ",cnonce=" + response["cnonce"] + ",nc=" + response["nc"] +
						",qop=" + response["qop"] + ",digest-uri=" + response["digest-uri"] + ",response=" + response["response"] + ",charset=" +
						response["charset"]
	end
	
	def connection
		to = "chat.facebook.com"
		host = "chat.facebook.com"
		port = 5222

		print "Username: "
		username = gets
		print "password: "
		password = gets
		
		username.gsub!("\n","")
		password.gsub!("\n","")
				
		initiate = "<stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' to='#{to}' version='1.0'>"	
		sasl = "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>"
		tls =  "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"
		
		ss = TCPSocket.new(host, port)  	
		ss.write(initiate)

		puts "step1: "
		puts ss.recv(650)
		puts ss.recv(500)

		puts "step2: "
		ss.write(sasl)
		challange = ss.recv(1000)
		puts challange

		decoded = get_challange(challange)
	#	md5Values = getValuesFromDecoded(decoded, "&")
		md5Values = getValuesFromDecoded(decoded, ",") #md5 mechanism
		puts md5Values.inspect
		response_value = construct_response(md5Values, username, password)
		puts response_value

		#step 3 send the response for authentication
		#encode the response value
		response = "<response xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>" + Base64.encode64(response_value) + "</response>"	
		puts response
		puts "step 3: "
		ss.write(response)
		challange = ss.recv(1000)
		puts challange 
		decoded = get_challange(challange)
		puts decoded
		
		puts "step 4: "
		res = "<response xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>"
		ss.write(res)
		puts ss.recv(1000)

		puts "step5: "
		ss.write(initiate)
		
		while line = ss.recv(1000)   # Read lines from the socket
			if line.end_with?("</stream:features>")
				puts line
				break
			else
				puts line 
			end
		end	
		
		puts "step 6: bind resource"
		binding = "<iq type='set' id='bind_1'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></iq>"
		ss.write(binding)
		jid = getJID(ss.recv(1000))		
		puts jid.inspect
		
		puts "step 7: start session"
		session = "<iq to='#{to}' type='set' id='sess_1'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>"
		ss.write(session)
		puts ss.recv(1000)
		
		#getting the user list called roster
		roster = "<iq from='#{jid[0]}/#{jid[1]}' type='get' id='roster_1'><query xmlns='jabber:iq:roster'/></iq>"
		puts "Roster: " + roster
		ss.write(roster)
		puts "Receiving user list"
		#receive the user list and print them in a formated way
		userList = ""
		while line = ss.recv(1000)   # Read lines from the socket
			if line.end_with?("</iq>")
				userList += line
				break
			else
				userList += line 
			end
			puts line
		end
		
		createUserList(userList)
		puts "All Friends list has been created"
		
		puts "Step 8: send the status and receive messages and stutuses from people"
		presence = "<presence><show>chat</show></presence>"
		ss.write(presence)
		msg = "<message to='u21312807@chat.facebook.com' from='#{jid[0]}/#{jid[1]}' type='chat'><body>allora?! 60 minuti</body></message>"
		ss.write(msg)
		
		data_chunk = ""
		while line = ss.recv(1000)
			#if the tag is not closed </> that means it is not yet completed and we have to wait for the rest of it.
			#if it is completed then we can process what ever we received
			
			if line.end_with?("</presence>") || line.end_with?("</message>") 
				data_chunk += line
				XMLProcessor(data_chunk)
				data_chunk = ""
				getOnlineFriends
			else
				data_chunk += line
			end
#			puts data_chunk
		end
		ss.close
	end
	
	def XMLProcessor(xml)
		#xml = File.read("replies.xml")
		#wrap the xml with <replies> </replies>
		xml.insert(0, "<replies>")
		xml.insert(xml.size.to_i, "</replies>")
		
		#puts "XML: ----" + xml
		
		#then process each xml entry according to its tag i.e presence for status and message for messages		
		data, others = REXML::Document.new(xml), []
		data.elements.each("replies/*") do |ele|
			if ele.name == "presence"
				process_presence(ele)
			elsif ele.name == "message"
				process_message(ele)
			end
		end
	end
	
	def process_message(message)
		friendJID = message.attributes["from"]
		text = ""
		if message.attributes["type"] == "chat"
			message.elements.each do |element|
				text += element.text unless element.text.nil?
			end
			puts [friendJID, text] unless text.empty?
		end
	end

	def process_presence(presence)
		status = ""
		friendJID = presence.attributes["from"]
		#if the type is set - the person is not available
		if !(presence.attributes["type"].nil?)
			status = presence.attributes["type"]
		else #the user would either be available or busy or away
			presence.elements.each do |element|
				status = element.text if element.name == "show"
			end
		end
		#if the status is not away or unavailable i.e. the friend is online
		status = "online" if status.empty?

		#update the userList 
		puts [friendJID, status]
		updateUserStatus(friendJID, status)
	end
	
	def updateUserStatus(jid, status)
		@@friends.each do |friend|
			friend.status = status if friend.jid == jid
		end
	end
	
	def getOnlineFriends
		puts "==================="
		puts "== Online Friends  "
		puts "==================="
		
		@@friends.each do |friend|
			if friend.status != "offline"
				puts friend.id.to_s + ". " + friend.name + " - " + friend.status 
			end
		end
	end
	
	def createUserList(users)
		#<item jid="u526052968@chat.facebook.com" subscription="both" name="Nasir Dawod Musa"><group>malaysia</group></item>
		#users = File.open("users.txt")
		id = 1
		data, others = REXML::Document.new(users), []
		data.elements.each("iq/query/*") do |ele|
			friend = Friend.new(id, ele.attributes["jid"], ele.attributes["name"], "offline")
			@@friends << friend
			id += 1
		end	

=begin				
		@@friends.each do |f|
			puts "----\n" + f.id.to_s
			puts f.name
			puts f.jid
			puts f.messages
		end
=end

	end
end


class Friend
	attr_accessor :id, :jid, :name, :status, :messages
	def initialize(id, jid, name, status)
		@id = id
		@jid = jid
		@name = name
		@status = status
		@messages = ""
	end
	
	def search_jid
		
	end
end

x = StdClass.new
x.connection
#x.createUserList("a")
#x.getJID("a")
#x.buildUserList("a")
