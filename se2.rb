class StdClass
	def initialize
		
	end

	def startMe
		#filename = "allLogs.txt"
		#filename = "allLogsDetailed.txt"
		filename = "sample.txt"

		revision = ""
		date = ""
		bug = ""
		lines = 0
		
		revisionEx = /^r\d*/
		dateEx = /\d{4}-\d{2}-\d{2}/
		
		bugs = []
		counter = 1.to_i
		f = File.open(filename, "r") 
		f.each_line do |line|
=begin
			puts "-------------"
			puts "dash: " + first_dash
			puts "info: " + info_line
			puts "revision: " + revision
			puts "bug: " + bug
			puts "-------------"
=end	
			#read first dashes which contain first line
			next if line =~ /^-{20}/ # first_dash == 'no' and line.include? "-----------------------"
						
			if line =~ revisionEx
				revision = revisionEx.match(line)
				date = dateEx.match(line)
				next
			end

			#now seach for bug
			if  line =~ /BUG=\d*/ && !(line =~ /BUG=[Nn]/)
				bug = line
				#once the bug number is found - report it and reinitialize every variable
				bugs << revision.to_s + " " +  date.to_s  + " " + bug
				#puts bug
				#puts revision
				#puts "bug " + counter.to_s + " has been recorder"
				#counter = counter + 1.to_i
				bug = ""
				revision = ""	
				date = ""	
				next		
			end

		end
		
		puts "All Bugs"
		puts bugs
		#puts bugs.inspect
		puts "Size: " +  bugs.size.to_s
		#puts "counter: " + counter.to_s
	end

end

x = StdClass.new
x.startMe
