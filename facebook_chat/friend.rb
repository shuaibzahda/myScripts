class Friend
	attr_accessor :id, :jid, :name, :status, :messages
	def initialize(id, jid, name, status)
		@id = id
		@jid = jid
		@name = name
		@status = status
		@messages = ""
	end
end
