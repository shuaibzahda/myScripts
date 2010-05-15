require 'rexml/document'
require 'rubygems'
require 'active_record'

	ActiveRecord::Base.establish_connection(
		:adapter => 'mysql',
		:host     => 'localhost',
		:username => 'root',
		:password => 'zahdeh',
		:database => 'se2v4')

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

		filename = "version4.xml"
		#filename = "logxml.xml"
		bugs = []

		total_faults = 0
		
		#files
		modified = []
		
		extensions = /(.cc$|.c$|.cpp$)/
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

				#search for bugs - search for better regexp
				if sub_element.name == "msg"
					@@bug = sub_element.text.scan(bugEx) if sub_element.text
				end
				#report only if a bug is mentioned in the message	
				unless @@bug.empty?	
					#create a database record for the bug
					aRevision = Revision.create(:revision => @@revision)
					puts @@revision
					
					#count number of changes per file using svn diff
					reprted_files = getRemoteDiff(@@revision)

					reprted_files.each do |file|
						if extensions.match(file["filename"]) #file["filename"].end_with?(".cc")
							puts "name: " + file["filename"]
							puts "faults: " + file["faults"].to_s
							modification = Modification.find_by_filename(file["filename"])
							if modification
								modification.faults += file["faults"].to_i
								modification.save
							else
								aRevision.modifications.create(:filename => file["filename"], :faults => file["faults"].to_i)
							end							
						end
					end
				end
			end 
			
			reset #reset all variables
			
		end #/log
		puts startedAt
		puts Time.now
	end

	def reset
		@@bug = []
		@@revision = ""
		@@date = ""
		@@files = {}
		@@developer = ""
	end
	
	def getRemoteDiff(revision)
		prev = revision.to_i - 1
		puts "svn diff -r r#{prev.to_s}:r#{revision.to_s}"
		output = `svn diff -r r#{prev.to_s}:r#{revision.to_s} http://src.chromium.org/svn/trunk/src/`

		#output = File.read("out.txt")
		reg = /Index: /
		faultReg = /^[@]{2} [+-]\d*,\d* [+-]\d*,\d* [@]{2}$/		
		current = ""
		faults = 0
		counter = 0
		report = []
		file = {}
		output.each do |line|
			if reg.match(line)
				#this is to avoid the reporting of the first file which is not yet counted and it actually skips 
				#last file but it is reported after the loop
				if counter != 0 
					#report
					file["filename"] = current
					file["faults"] = faults.to_i
					report << file
				end
				current = line.split(reg).to_s.gsub("\n", "")
				counter += 1
				faults = 0
				file = {}
			end
			
			faults += 1 if faultReg.match(line)
		end
		
		#report the last file
		file["filename"] = current
		file["faults"] = faults.to_i
		report << file		
		return report
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
	
	def compute80
		modifications = Modification.find(:all, :order => "faults desc")
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
		puts "faulty module has at least: " + last_fault.to_s + " faults"
=begin
		#now mark the faulty and non faulty files. Faulty = 1, non faulty = 0
		modifications.each do |modification|
			if modification.faults.to_i >= last_fault.to_i
				puts "faulty"
				modification.faulty = 1
			else
				puts "non-faulty"
				modification.faulty = 0			
			end
			modification.save
		end
=end
	end
	
	def sourceMonitor
		#this will read the source monitor output file and dump it into the database
		#filename = "source_monitor/chromev3.xml"
		filename = "v4SourceMonitor.xml"
		xml = File.read(filename)
		data, others = REXML::Document.new(xml), []
		extensions = /(.cc$|.c$|.cpp$)/
		counter = 0
		non_exe = 0
		not_in_db = 0
		data.elements.each('/sourcemonitor_metrics/project/checkpoints/checkpoint/files/*') do |ele|
			#convert the file into linux format
			file = ele.attributes['file_name'].gsub("\\","/").to_s
			modification = Modification.find_by_filename(file)
			if modification
				counter += 1
				puts file + " ----------------"
				ele.each_element("metrics/*") do |sub_element|
					if sub_element.attributes['id'] == "M0"
						puts "Lines: " + sub_element.text.to_s
						modification.lines_source = sub_element.text.to_i
					elsif sub_element.attributes['id'] == "M1"
						puts "statements: " + sub_element.text.to_s
						modification.statements = sub_element.text.to_i
					elsif sub_element.attributes['id'] == "M2"
						puts "percent_branch_statement: " + sub_element.text.to_s
						modification.percent_branch_statement = sub_element.text.to_f
					elsif  sub_element.attributes['id'] == "M3"
						puts "percent_lines_with_comments: " + sub_element.text.to_s
						modification.percent_lines_with_comments = sub_element.text.to_f
					elsif  sub_element.attributes['id'] == "M4"
						puts "class_defined: " + sub_element.text.to_s
						modification.class_defined = sub_element.text.to_i
					elsif  sub_element.attributes['id'] == "M5"
						puts "method_per_class: " + sub_element.text.to_s
						modification.method_per_class = sub_element.text.to_f
					elsif  sub_element.attributes['id'] == "M6"
						puts "average_statement_method: " + sub_element.text.to_s
						modification.average_statement_method = sub_element.text.to_f
					elsif  sub_element.attributes['id'] == "M9"
						puts "maximum_complexity: " + sub_element.text.to_s
						modification.maximum_complexity = sub_element.text.to_i
					elsif  sub_element.attributes['id'] == "M11"
						puts "maximum_depth: " + sub_element.text.to_s
						modification.maximum_depth = sub_element.text.to_i
					elsif  sub_element.attributes['id'] == "M12"
						puts "average_depth: " + sub_element.text.to_s
						modification.average_depth = sub_element.text.to_f
					elsif  sub_element.attributes['id'] == "M13"
						puts "average_complexity : " + sub_element.text.to_s
						modification.average_complexity = sub_element.text.to_f
					elsif  sub_element.attributes['id'] == "M14"
						puts "functions: " + sub_element.text.to_s
						modification.functions = sub_element.text.to_i
					end
				end
				modification.save
			else
				if extensions.match(file)
					new_file = Modification.new()
					new_file.filename = file
					new_file.faults = 0
					ele.each_element("metrics/*") do |sub_element|
						if sub_element.attributes['id'] == "M0"
							puts "Lines: " + sub_element.text.to_s
							new_file.lines_source = sub_element.text.to_i
						elsif sub_element.attributes['id'] == "M1"
							puts "statements: " + sub_element.text.to_s
							new_file.statements = sub_element.text.to_i
						elsif sub_element.attributes['id'] == "M2"
							puts "percent_branch_statement: " + sub_element.text.to_s
							new_file.percent_branch_statement = sub_element.text.to_f
						elsif  sub_element.attributes['id'] == "M3"
							puts "percent_lines_with_comments: " + sub_element.text.to_s
							new_file.percent_lines_with_comments = sub_element.text.to_f
						elsif  sub_element.attributes['id'] == "M4"
							puts "class_defined: " + sub_element.text.to_s
							new_file.class_defined = sub_element.text.to_i
						elsif  sub_element.attributes['id'] == "M5"
							puts "method_per_class: " + sub_element.text.to_s
							new_file.method_per_class = sub_element.text.to_f
						elsif  sub_element.attributes['id'] == "M6"
							puts "average_statement_method: " + sub_element.text.to_s
							new_file.average_statement_method = sub_element.text.to_f
						elsif  sub_element.attributes['id'] == "M9"
							puts "maximum_complexity: " + sub_element.text.to_s
							new_file.maximum_complexity = sub_element.text.to_i
						elsif  sub_element.attributes['id'] == "M11"
							puts "maximum_depth: " + sub_element.text.to_s
							new_file.maximum_depth = sub_element.text.to_i
						elsif  sub_element.attributes['id'] == "M12"
							puts "average_depth: " + sub_element.text.to_s
							new_file.average_depth = sub_element.text.to_f
						elsif  sub_element.attributes['id'] == "M13"
							puts "average_complexity : " + sub_element.text.to_s
							new_file.average_complexity = sub_element.text.to_f
						elsif  sub_element.attributes['id'] == "M14"
							puts "functions: " + sub_element.text.to_s
							new_file.functions = sub_element.text.to_i
						end
					end
					modification.save
					not_in_db += 1
				else
					non_exe += 1
				end
				#puts file + " does not exist in database"
			end	
		end
		puts "Total files: " + counter.to_s
		puts "Executables not in db: " + not_in_db.to_s
		puts "Non executable: " + non_exe.to_s
	end
	
	def understand
		#Kind0,Name1,File2,CountDeclClass3,CountDeclFunction4,CountLine5,CountLineBlank6,CountLineCode7,
		#CountLineCodeExe8,CountLineInactive9,CountLinePreprocessor10,CountSemicolon11,SumCyclomatic12
		#Kind0,Name1,File2,CountDeclClass3,CountDeclFunction4,CountLine5,CountLineBlank6,CountLineCode7,
		#CountLineCodeExe8,CountLineInactive9,CountLinePreprocessor10,CountSemicolon11,SumCyclomatic12

		#this script has been modified for version 4
		extensions = /(.cc$|.c$|.cpp$)/
		counter = 0
		non_exe = 0
		not_in_db = 0
		file = File.read("understand_files.csv")
		file.each_line do |line|
			data = line.split(",")
			puts " --------------- "
			modification = Modification.find_by_filename(data[2].gsub("\\", "/"))
			if modification
				counter += 1
				puts "Filename: " + data[2].gsub("\\", "/")
				puts "CountDeclClass: " + data[3]
				modification.CountDeclClass = data[3] 
				puts "CountDeclFunction: " + data[4]
				modification.CountDeclFunction = data[4]
				puts "CountLine: " + data[5]
				modification.CountLine = data[5]
				puts "CountLineBlank: " + data[6]
				modification.CountLineBlank = data[6]
				puts "CountLineCode: " + data[7]
				modification.CountLineCode = data[7]
				puts "CountLineCodeExe: " + data[8]
				modification.CountLineCodeExe = data[8]
				puts "CountLineInactive: " + data[9]
				modification.CountLineInactive = data[9]
				puts "CountLinePreprocessor: " + data[10]
				modification.CountLinePreprocessor = data[10]
				puts "CountSemicolon: " + data[11]
				modification.CountSemicolon = data[11]
				puts "SumCyclomatic: " + data[12]
				modification.SumCyclomatic = data[12]
				modification.save
			else
				
				if extensions.match(data[2])
					modification = Modification.new()
					modification.filename = data[2].gsub("\\", "/")
					modification.faults = 0
					puts "Filename: " + data[2].gsub("\\", "/")
					puts "CountDeclClass: " + data[3]
					modification.CountDeclClass = data[3] 
					puts "CountDeclFunction: " + data[4]
					modification.CountDeclFunction = data[4]
					puts "CountLine: " + data[5]
					modification.CountLine = data[5]
					puts "CountLineBlank: " + data[6]
					modification.CountLineBlank = data[6]
					puts "CountLineCode: " + data[7]
					modification.CountLineCode = data[7]
					puts "CountLineCodeExe: " + data[8]
					modification.CountLineCodeExe = data[8]
					puts "CountLineInactive: " + data[9]
					modification.CountLineInactive = data[9]
					puts "CountLinePreprocessor: " + data[10]
					modification.CountLinePreprocessor = data[10]
					puts "CountSemicolon: " + data[11]
					modification.CountSemicolon = data[11]
					puts "SumCyclomatic: " + data[12]
					modification.SumCyclomatic = data[12]
					modification.save
					not_in_db += 1
				else
					non_exe += 1
				end
			end
		end
		
		puts "Files: " + counter.to_s
		puts "Executables not in db: " + not_in_db.to_s
		puts "Non executable: " + non_exe.to_s
	end	
	
	def model_v4
=begin
CountLineBlank	.011
average_depth	.399
average_complexity	-.046
CountLineInactive	-.004
CountDeclClass	-.002
Constant	-1.605
z = constant + coefficients of variables
1 / (1 +  Math.exp(-z))
Math.exp

=end
		modifications = Modification.all
		modifications.each do |modification|
			probability = (-1.605) + (0.011 * modification.CountLineBlank.to_f) + (0.399 * modification.average_depth.to_f) + 
						(-0.046 * modification.average_complexity.to_f) + (-0.004 * modification.CountLineInactive.to_f) + 
						(-0.002 * modification.CountDeclClass.to_f)
			logistic = (1 / (1 + Math.exp(-probability)))
			puts probability.to_s + " - " + logistic.to_s 
			modification.probability = logistic.to_f
			modification.save
		end
	end
	
	def percentages
		all_faults = Modification.sum('faults')
		puts "Faults: " + all_faults.to_s
		
		puts "25% - "
		p25 = compute_percentage(all_faults * 25 / 100)
		report_percentage(p25)

		puts "\n 50% - "
		p50 = compute_percentage(all_faults * 50 / 100)
		report_percentage(p50)

		puts "\n 75% - "		
		p75 = compute_percentage(all_faults * 75 / 100)
		report_percentage(p75)
		
		puts "\n 90% - "				
		p90 = compute_percentage(all_faults * 90 / 100)
		report_percentage(p90)
	end
	
	def report_percentage(per)
		exe_files = 4199
		puts "total faults: " + per[0].to_s
		puts "files: " + per[1].to_s
		per_files = (per[1].fdiv(exe_files)) * 100
		puts "% files: " +  per_files.to_s
		puts "false positive: " + per[2].to_s
	end
	
	def compute_percentage(percent)
		modifications = Modification.all(:order => "probability desc")
		
		total = 0 
		files = 0
		false_positive = 0
		modifications.each do |modification|
			if total <= percent
				total += modification.faults.to_i 
				files += 1
				
				#alert me for false positive files
				if modification.faults.to_i == 0
					false_positive += 1
					#puts modification.filename + " " + modification.probability.to_s + " " + modification.faults.to_s
				end				
			end
		end
		[total, files, false_positive]
	end
	
end

x = StdClass.new
x.startMe
#x.compute80
#x.sourceMonitor
#x.understand
#x.percentages
#x.model_v4
