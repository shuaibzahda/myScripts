require 'rexml/document'
require 'rubygems'
require 'active_record'

	ActiveRecord::Base.establish_connection(
		:adapter => 'mysql',
		:host     => 'localhost',
		:username => 'root',
		:password => 'zahdeh',
		:database => 'se2')

class Revision < ActiveRecord::Base  
	has_many :modifications
end

class Modification < ActiveRecord::Base  
	belongs_to :revision
end


class StdClass
	@@bug = []
	@@revision = ""
	@@date = ""
	@@files = {}
	@@developer = ""

	def startMe
		startedAt = Time.now
		#filename = "firebird.xml"
		filename = "version3.xml"
		bugs = []

		total_faults = 0
		
		#files
		modified = []
		#added = []
		#deleted = []
		
		revisionEx = /\d/
		dateEx = /\d{4}-\d{2}-\d{2}/
		bugEx = /BUG=[0-9,]+/
		fileEx = /.cc/
		reset()

		xml = File.read(filename)
		data, others = REXML::Document.new(xml), []
		data.elements.each('/log/*') do |ele|
			#get the revision number
			@@revision = ele.attributes['revision']
			#@@revision = "r" + ele.attributes['revision']
			
			#search through the elements for information
			ele.each_element do |sub_element|
				#get the date
				#@@date = sub_element.text.scan(dateEx) if sub_element.name == "date"
				#@@developer = sub_element.text if sub_element.name == "author"

				#search for bugs - search for better regexp
				if sub_element.name == "msg"
					@@bug = sub_element.text.scan(bugEx) if sub_element.text #.to_s if bugEx.match(sub_element.text)
				end
				#report the revision if it is related to a bug				
				if sub_element.name == "paths"
					#loop in the paths and add the files into the arrays according to the status of the file
					sub_element.each_element do |path|
						modified << path.text.to_s if path.attributes['action'].to_s == "M" && fileEx.match(path.text)
						#added << path.text.to_s if path.attributes['action'].to_s == "A" && fileEx.match(path.text)
						#deleted << path.text.to_s if path.attributes['action'].to_s == "D" && fileEx.match(path.text)
					end
					@@files = {:modified => modified} #, :added => added, :deleted => deleted}
					modified = []
					#added = []
					#deleted = []
				end
				
				#report only if a bug is mentioned in the message	
				unless @@bug.empty?	
					#create a database record for the bug
					aRevision = Revision.create(:rev => @@revision)
					puts @@revision
					#now get the differences in files and count the number of faults	
					faults = 0
					#count number of changes per file using svn diff
					@@files[:modified].each do |file| 
						#split from source since the log brings from trunk/ version number and other places
						file = file.split("/src/")
#						puts file.inspect
						unless file[1].blank?
							faults = getDiff(@@revision, file[1])
							#write the filename and its count to database
							#check if the file existed before and increment the count of faults
							modification = Modification.find_by_filename(file[1])
							if modification
								modification.faults += faults
								modification.save
							else
								aRevision.modifications.create(:filename => file[1], :faults => faults)
							end
						end
						puts @@revision
					end
					#bugs << {:faults => faults, :revision => @@revision, :date => @@date.to_s, 
					#		:bug => @@bug.join(','), :files => @@files, :developer => @@developer }
				end
			end 
			
			reset #reset all variables
			
		end #/log
=begin
		bugs.each do |bug|		
			puts bug[:revision]
			#puts bug[:developer]
			#puts bug[:bug]
			puts "Faults: " + bug[:faults].to_s
			total_faults += bug[:faults]
			puts "Modified: " + bug[:files][:modified].size.to_s # + " " + bug[:files][:modified].inspect #if bug[:files][:modified]
			#puts "Added: " + bug[:files][:added].size.to_s # + " " + bug[:files][:added].inspect# if bug[:files][:added]
			#puts "Deleted: " + bug[:files][:deleted].size.to_s #+ " " +  bug[:files][:deleted].inspect # if bug[:files][:deleted]
			puts "------------"
		end
=end
		#puts bugs.size
		#puts "faults: " + total_faults.to_s
		puts startedAt
		puts Time.now
	end
	
	def differences
		filename = "diff2.txt"
		reg = /^[+|-]/
		f = File.read(filename)
		current = nil
		previous = nil
		faults = 0
		f.each_line do |line|
			current = reg.match(line)
			if(current == nil && (previous.to_s == '+' || previous.to_s == '-'))
				faults += 1
				previous = nil
				current == nil	
			elsif((current.to_s == '+' || current.to_s == '-'))
				previous = current.to_s
				current = nil
			end
		end
		puts faults
	end

	def reset
		@@bug = []
		@@revision = ""
		@@date = ""
		@@files = {}
		@@developer = ""
	end
	
	def getDiff(revision, file)
		prev = revision.to_i - 1
		puts "svn diff -r r#{prev.to_s}:r#{revision.to_s} #{file}"
		out = `svn diff -r r#{prev.to_s}:r#{revision.to_s} #{file}`
		faults = 0
		reg = /^[@]{2} [+-]\d*,\d* [+-]\d*,\d* [@]{2}$/		
		array = out.scan(reg)
		faults += array.size
		faults
	end
	
	def retrieveDB
		revisions = Revision.find(:all)
		
		revisions.each do |revision|
			puts "Revision: " + revision.rev.to_s
			#puts "Added: " + revision.added.to_s
			#puts "Deleted: " + revision.deleted.to_s
			#puts revision.modifications.faults
			puts "modified: " + revision.modifications.size.to_s
			puts '------------------'
			
		end
	end
	
	def readSLOC
		filename = "C_CPP_outfile.dat"
		reg = /\d+/
		# Total  Blank |    Comments    | Compiler  Data   Exec.  |Logical | File  Module
		# Lines  Lines | Whole Embedded | Direct.   Decl.  Instr. |  SLOC  | Type   Name
		#------------------------------------------------------------------------------------------------------
		#   957    119 |   203        0 |      21     100     307 |    428 | CODE chrome/browser/views/autocomplete/autocomplete_popup_contents_view.cc
		
		f = File.read(filename)
		f.each_line do |line|
			file = line.split("CODE ")
			array = line.scan(reg)
			#filter the data and store the metrics
			total_lines = array[0].to_i
			blank_lines = array[1].to_i
			comments = array[2].to_i + array[3].to_i
			logical_SLOC = array[7].to_i
			
			#check if the file exists on database
			aFile = Modification.find_by_filename(file[1].strip)
			aFile.total_lines = total_lines
			aFile.blank_lines = blank_lines
			aFile.comments = comments
			aFile.logical_SLOC = logical_SLOC
			aFile.save
			
			puts aFile.filename
			puts "file: " + file[1].strip
			puts "total_lines: " + total_lines.to_s
			puts "blank_lines: " + blank_lines.to_s
			puts "comments: " + comments.to_s
			puts "Logical SLOC: " + logical_SLOC.to_s
			puts "----------"
		end
	end
	
	def compute80
		modifications = Modification.find(:all, :conditions => "faults > 0", :order => "faults desc")
		#get total number of faults
		all_faults = Modification.sum('faults')
		eighty = all_faults * 80 / 100
		total = 0 
		files = 0
		#sum up to 80%
		last_fault = 0
		modifications.each do |modification|
			if total <= eighty
				total += modification.faults.to_i 
				last_fault = modification.faults.to_i
				files += 1
			end
		end
		puts "all faulty files: " + modifications.size.to_s
		puts "all faults: " + all_faults.to_s
		puts "80%: " + eighty.to_s
		puts "total: " + total.to_s
		puts "Files: " + files.to_s
		puts "faulty module has at least: " + last_fault.to_s + "faults"
		
		#now mark the faulty and non faulty files. Faulty = 1, non faulty = 0
	end
	
	def sourceMonitor
		#this will read the source monitor output file and dump it into the database
		filename = "source_monitor/ChromeV3.xml"
		#filename = "source_monitor/sourceSample.xml"
		xml = File.read(filename)
		data, others = REXML::Document.new(xml), []
		counter = 0
		
		data.elements.each('/sourcemonitor_metrics/project/checkpoints/checkpoint/files/*') do |ele|
			#get the file into linux format
			file = ele.attributes['file_name'].gsub("\\","/").gsub("src/","").to_s
			if Modification.find_by_filename(file, :conditions => "faults > 0")
				counter += 1
				ele.each_element("metrics/*") do |sub_element|
					#puts sub_element.text
					puts "Lines: " + sub_element.text.to_s if sub_element.attributes['id'] == "M0"
					puts "statements: " + sub_element.text.to_s if sub_element.attributes['id'] == "M1"
					puts "methods/class: " + sub_element.text.to_s if sub_element.attributes['id'] == "M5"
					puts "avg stmts/method: " + sub_element.text.to_s if sub_element.attributes['id'] == "M6"
					puts "functions: " + sub_element.text.to_s if sub_element.attributes['id'] == "M14"				
				end
			else
				puts file + " does not exist in database"
			end	
		end
		puts "Total files: " + counter.to_s
	end
end

x = StdClass.new
#x.getDiff
#x.differences
#x.startMe
#x.retrieveDB
#x.readSLOC
#x.compute80
x.sourceMonitor
