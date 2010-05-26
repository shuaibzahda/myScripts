require "socket"
require "openssl"
require "base64"
require 'rexml/document'
require 'digest/md5'
require "friend"
require "notifications"

class Chatting
	KEYWORDS = ["help", "exit", "online", "messages", "chat", "show", "status"]
	STATUS = ["chat", "away", "dnd"]
	HOST = "chat.facebook.com"
	PORT = 5222
	
	@@friends = []
	@@messages = []
		
	def command_line
		puts "Facebook> "
		while line = gets
			process_input(line.strip)
			puts "Facebook> "
		end
	end
	
	def process_input(input)
		command = input.split(" ")
		args = command.size
		if KEYWORDS.include?(command[0])
			case command[0]
				when "help"
					Notifications.help
				when "online"
					getOnlineFriends
				when "exit"
					exit_chat(Notifications.bye)
				when "chat"
					if args.to_i == 2 && is_number(command[1].to_i)
						if command[1].to_i >= getNumberOfFriends
							Notifications.noFriendsError
						else
							open_chat(command[1].to_i)
						end
					else
						Notifications.chat_show_error("chat")
					end
				when "show"
					if args.to_i == 2 && is_number(command[1].to_i)
						if command[1].to_i >= getNumberOfFriends
							noFriendsError
						else
							chatting_window(command[1].to_i)
						end
					else
						Notifications.chat_show_error("show")
					end
				when "messages"
					new_messages
				when "status"
					args.to_i == 2 && STATUS.include?(command[1]) ? change_status(command[1]) : Notifications.status_error
			end
		else
			Notifications.wrong_command
		end
	end
	
	def is_number(input)
		(input.class == Fixnum) && !(input.zero?)
	end
	
	def getNumberOfFriends
		@@friends.size + 1
	end
		
	def exit_chat(message)
		puts message
		@@socket.close
		exit
	end
	
	def open_chat(id)
		#open chatting window only for this user
		chatting_window(id)
		puts "Chatting mode - to exit type $exit"	
		puts "Enter your messages: "
		update_chat = Thread.new {
			check_if_message_recieved_in_chat_mode(id)
		}
		while message = gets
			break if message.strip == "$exit"
			send_data(construct_message(@@myJID, id, message))
			append_send_message(id, message)
			chatting_window(id)
		end
		puts "Command line mode"
		#closing the thread
		update_chat.exit
	end
	
	def chatting_window(id)
		delete_friend_from_messages(id)
		friend =  @@friends[id.to_i - 1]
		puts "============================"
		puts friend.id.to_s + ". " + friend.name
		puts "============================"
		puts friend.messages
		puts "============================"		
	end
	
	def check_if_message_recieved_in_chat_mode(friend_id)
		while true
			@@messages.each do |message| 
				if message.id.to_i == friend_id.to_i
					chatting_window(friend_id)
				end
			end
			sleep(1)
		end
	end
	
	def delete_friend_from_messages(friend_id)
		ids = []		
		@@messages.each { |message| ids << message if message.id.to_i == friend_id.to_i }
		ids.each {|id| @@messages.delete(id)}
	end
	
	def new_messages
		if @@messages.size.zero?
			puts "No new messages"
		else
			@@messages.each { |message| puts message.id.to_s + ". " + message.name + " - " + message.status }
		end
	end

	def change_status(status)
		send_data(set_status(status))
		puts "Your status has changed to #{status}"
	end
	
	def set_status(status)
		"<presence><show>#{status}</show></presence>"
	end

	def getJID(xml)
		#'<iq id="bind_1" type="result"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><jid>shuaibzahda@chat.facebook.com/d9a2852b_484D38B3AA5A7</jid></bind></iq>'
		if xml.include?('type="result"')
			jid = ""
			data, others = REXML::Document.new(xml), []
			data.elements.each("iq/bind/*") { |ele| jid = ele.text }
			return jid
		else
			exit_chat(Notifications.authentication_error)			
		end
	end
	
	def get_challange(text)
		cipher = ""
		data, others = REXML::Document.new(text), []
		data.elements.each do |ele|
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
		response["cnonce"] = "\"" + Digest::MD5.hexdigest("al-zahide") + "\""
		
		#creating response entry
		# 1. Create a string of the form "username:realm:password". Call this string X.
		x = username + ":" + response["realm"].gsub("\"", '') + ":" + password
		#2. Compute the 16 octet MD5 hash of X. Call the result Y.
		y = Digest::MD5.digest(x)
		#3. Create a string of the form "Y:nonce:cnonce". Call this string A1.
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
		"<response xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>" + Base64.encode64(response_auth) + "</response>"
	end
	
	def receive_initiate_data
		while line = receive_data_once
			break if line.end_with?("</stream:features>")
		end	
	end
	
	def create_connection
		@@socket = TCPSocket.new(HOST, PORT)
	end
	
	def send_data(data)
		@@socket.write(data)
	end
	
	def receive_data_once
		@@socket.recv(1000)
	end
	
	def process_challange_response(xml)
		if xml.include?("<failure ")
			exit_chat(Notifications.authentication_error)
		elsif xml.include?("<challenge ")
			get_challange(xml)
		end
	end
	
	def is_successful_authentication(xml)
		if xml.include?("<failure ")
			exit_chat(Notifications.authentication_error)
		end		
	end
	
	def get_password
		system("stty", "-echo")
		password = gets.chomp
		puts "#{"*" * password.size}"
		system("stty", "echo")
		password
	end
	
	def connection
		initiate = "<stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' to='#{HOST}' version='1.0'>"	
		sasl = "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>"
		tls =  "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"
		response_sasl = "<response xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>"
		binding = "<iq type='set' id='bind_1'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></iq>"
		session = "<iq to='#{HOST}' type='set' id='sess_1'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>"
		userList = ""
				
		print "Username: "
		username = gets
		print "password: "
		password = get_password
		
		username.gsub!("\n","")
		password.gsub!("\n","")
		
		puts "Started the connection with #{HOST}"
		create_connection
		send_data(initiate)
		receive_initiate_data
		
		puts "Authenticating username and password ..."
		#choose the authentication mechanism
		send_data(sasl)
		
		decoded = process_challange_response(receive_data_once)
		md5Values = getValuesFromDecoded(decoded, ",") #md5 mechanism
		response_value = construct_response(md5Values, username, password)
		
		#send the response for authentication with username and password encrypted
		send_data(response_value)
		process_challange_response(receive_data_once)
		
		#send the response sasl xml
		send_data(response_sasl)
		is_successful_authentication(receive_data_once)
		puts "Authentication is successful"
		
		#initiate the connection again after successful authentication
		send_data(initiate)
		receive_initiate_data
		
		puts "Binding and starting session with server."
		send_data(binding)
		@@myJID = getJID(receive_data_once)
		
		send_data(session)
		while line = receive_data_once
			exit_chat(Notifications.authentication_error) if line.include?("error")
			break if line.include?("</iq>")
		end
		
		#getting the user list called roster
		puts "Retrieving your friends list."
		roster = "<iq from='#{@@myJID}' type='get' id='roster_1'><query xmlns='jabber:iq:roster'/></iq>"
		send_data(roster)
		
		xml_roster_stopper = "</group></item></query></iq>"
		
		puts "Please wait ..."
		while line = receive_data_once
			if line.include?(xml_roster_stopper) || userList.include?(xml_roster_stopper)
				userList += line
				break
			else
				userList += line 
			end
			print "."
		end

		#sometimes the stream of data has more thant the </iq>, so we split it and store the remaining for next steps
		userXML = userList.split(xml_roster_stopper)
		createUserList(userXML[0])		
		puts "\nFriends list has been retrieved."
		
		send_data(set_status("chat"))
		puts "Status has been set to Online"
		
		data_chunk = ""
		#this is the remaining of the data that received with the userList
		data_chunk += userXML[1] unless userXML[1].nil?
		#start a thread that keeps receiving data
		receiver = Thread.new {
			while line = receive_data_once
				#if the tag is not closed </> that means it is not yet completed and we have to wait for the rest of it.
				#if it is completed then we can process what ever we received
				if line.end_with?("</presence>") || line.end_with?("</message>") 
					data_chunk += line
					XMLProcessor(data_chunk)
					data_chunk = ""
				else
					data_chunk += line
				end
			end
		} #thread
		
		puts "You are ready to start chatting"
		Notifications.help
		command_line
	end
	
	def XMLProcessor(xml)
		#wrap the xml with <replies> </replies> in order to process it with REXML
		xml.insert(0, "<replies>")
		xml.insert(xml.size.to_i, "</replies>")
		
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
		if message.attributes["type"] == "chat"
			message.elements.each {|element| append_message(friendJID, element.text) unless element.text.nil? }
		end
	end

	def process_presence(presence)
		status = ""
		friendJID = presence.attributes["from"]
		#if the type is set - the person is not available
		if !(presence.attributes["type"].nil?)
			status = presence.attributes["type"]
		else #the user would either be available or busy or away
			presence.elements.each { |element| status = element.text if element.name == "show" }
		end
		#if the status is not away or unavailable i.e. the friend is online
		status = "online" if status.empty?
		#update the userList 
		updateUserStatus(friendJID, status)
	end

	def append_message(jid, message)
		friend = search_jid(jid)
		message_formatted = friend.name + " " + Time.now.strftime("%H:%M:%S") + ": " + message + "\n"
		friend.messages += message_formatted
		#include it in @@messages
		is_exist = 0
		@@messages.each { |msg| is_exist = 1 if msg == friend }
		@@messages << friend if is_exist == 0
	end
	
	def append_send_message(toJID, text)
		friend = @@friends[toJID.to_i - 1]
		message_formatted = "Me " + Time.now.strftime("%H:%M:%S") + ": " + text
		friend.messages += message_formatted
	end
	
	def construct_message(myJID, toJID, text)
		friend = @@friends[toJID.to_i - 1]
		message = "<message to='#{friend.jid}' from='#{myJID}' type='chat'>"
		message += "<body>" + text + "</body></message>"
		message
	end
	
	def search_jid(jid)
		target_friend = ""
		@@friends.each do |friend|
			if friend.jid == jid
				target_friend = friend
				break
			end 
		end
		target_friend
	end
	
	def updateUserStatus(jid, status)
		@@friends.each do |friend|
			if friend.jid == jid
				friend.status = status
				break	
			end 
		end
	end
	
	def getOnlineFriends
		puts "======================"
		puts "==  Online Friends  =="
		puts "======================"
		statuses = ["offline", "unavailable"]
		@@friends.each do |friend|
			unless statuses.include?(friend.status)
				puts friend.id.to_s + ". " + friend.name + " - " + friend.status
			end
		end
	end
	
	def createUserList(users)
		users.insert(users.size.to_i, "</group></item></query></iq></replies>")
		users.insert(0, "<replies>")

		id = 1
		data, others = REXML::Document.new(users), []
		data.elements.each("replies/iq/query/*") do |ele|
			if ele.attributes["subscription"] == "both"
				friend = Friend.new(id, ele.attributes["jid"], ele.attributes["name"], "offline")
				@@friends << friend
				id += 1
			end
		end	
	end
	
	#for testing only
	def countOnlineFriends
		statuses = ["offline", "unavailable"]
		counter = 0
		@@friends.each do |friend|
			counter += 1 unless statuses.include?(friend.status)
		end	
		counter
	end
	
	def getMessages
		@@messages
	end
	
	def getFriends
		@@friends
	end

end
