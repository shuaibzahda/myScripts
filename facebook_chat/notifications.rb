
class Notifications
	
	def self.status_error
		puts "Error in setting status. available status are: chat, dnd, away"
	end
	
	def self.noFriendsError
		puts "The ID does not match any of your friends. Make sure you entered the correct ID"
	end
	
	def self.chat_show_error(name)
		puts("Enter friend ID e.g " + name + " 15")
	end

	def self.wrong_command
		puts "Wrong command. Type help for more information"
	end
	
	def self.bye
		puts "Thank you for using Facebook command line chat - Good Bye.\n"
	end
	
	def self.exit_error
		puts "Failed to connect to the server."
	end
	
	def self.authentication_error
		"Failed to authenticate with server. Enter correct username and/or password"
	end
	
	def self.help
		tabs = "\t\t"
		puts "========= HELP ==========="
		puts
		puts "Command" + tabs + " - Description"
		puts "chat" + tabs + " - start chatting with a friend e.g chat [ID]"
		puts "show" + tabs + " - display a chatting window with a friend e.g show [ID]"		
		puts "exit" + tabs + " - Exit the program"
		puts "help" + tabs + " - Show this page"
		puts "messages" + tabs + " - display who sent new messages"
		puts "online" + tabs + " - show all online friends"
		puts "status" + tabs + " - change current status e.g. status away"
		puts tabs + "\t available status: chat (online), away, dnd (busy)"
		puts "$exit" + tabs + "exit chatting with friend and go back to command line mode"
	end
end

