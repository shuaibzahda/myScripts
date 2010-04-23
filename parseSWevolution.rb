require 'rexml/document'
require 'rubygems'
require 'gruff'
require 'active_record'

	ActiveRecord::Base.establish_connection(
		:adapter => 'mysql',
		:host     => 'localhost',
		:username => 'root',
		:password => 'zahdeh',
		:database => 'evolution')
		
class Programmer < ActiveRecord::Base
	has_many :commits
end

class Modification < ActiveRecord::Base
	belongs_to :commit
end

class Commit < ActiveRecord::Base
	belongs_to :programmer
	has_many :modifications
end

class StdClass

	@@revision = ""
	@@date = ""
	@@dates = {}
	@@files = {}
	@@developer = ""
	@@developers = {}
	
	def startMe
		startedAt = Time.now
		filename = "firebird_continue.xml"
#		filename = "firebird.xml"
		bugs = []
		modified = []
		
		extensions = /(.cs$|.cpp$|.c$|.java$)/
		dateEx = /\d{4}-\d{2}-\d{2}/
		reset()
		
		xml = File.read(filename)
		data, others = REXML::Document.new(xml), []
		data.elements.each('/log/*') do |ele|
			#get the revision number
			@@revision = ele.attributes['revision']
			
			#search through the elements for information
			ele.each_element do |sub_element|
				#get the date and how many commits per day
				@@date = sub_element.text.scan(dateEx) if sub_element.name == "date"
				#get the name of the developer
				@@developer = sub_element.text if sub_element.name == "author"
				#record all executable files
=begin
				if sub_element.name == "paths"
					sub_element.each_element do |path|
						modified << path.text.to_s if extensions.match(path.text.to_s) 
					end
					@@files = {:modified => modified}
					modified = []
				end				
=end
			end 

			#dump information to database
			programmer = Programmer.find_by_name(@@developer.to_s)
			if programmer 
				programmer.increment('total_commits', 1)
				programmer.last_at = @@date.to_s
				#increase lines of code added and delted
				programmer.save
			else
				programmer = Programmer.create(:name => @@developer.to_s, :started_at => @@date.to_s, 
					:last_at => @@date.to_s)
			end
			commit =  programmer.commits.create(:revision => @@revision.to_i, :date => @@date.to_s)
=begin
			#get number of deleted and added files
			@@files[:modified].each do |file| 
				file.slice!(0)  #this will delete the first char "/" from the path 
				puts file
				values = countChanges(@@revision, file)
				#deduct 1 from each category for the first lines of the revisions because they include ---- ++++
				addedLOC = values[0].to_i - 1
				deletedLOC = values[1].to_i - 1
				if addedLOC >= 0 and deletedLOC >= 0
					modification = Modification.create(:name => file, :commit_id => commit.id, :addLOC =>addedLOC,
					:deletedLOC => deletedLOC, :started_at => @@date.to_s, :last_at => @@date.to_s)
					#add the number of delted and added lines to the developers
					programmer.increment('addedLOC', addedLOC)
					programmer.increment('deletedLOC', deletedLOC)
					programmer.save
				end
			end
=end

			#find the number of addition and deletion per file
			filesCount = getDiff(@@revision)			
			filesCount.each do |file|
			#dump to database
				puts file["filename"].inspect
				puts "Added: " + file["added"].to_s
				puts "Deleted: " + file["deleted"].to_s	
				
				modification = Modification.create(:name => file["filename"].gsub("\n","").to_s, :commit_id => commit.id, 
				:addLOC =>file["added"].to_i, :deletedLOC => file["deleted"].to_i, :started_at => @@date.to_s, :last_at => @@date.to_s)
				#add the number of delted and added lines to the developers
				
				programmer.increment('addedLOC', file["added"].to_i)
				programmer.increment('deletedLOC', file["deleted"].to_i)
				programmer.save	
			end
			#puts filesCount.inspect
			
			#report						
			bugs << {:revision => @@revision, :date => @@date.to_s, :files => @@files, :developer => @@developer }
			reset #reset all variables
			
		end #/log
=begin
		bugs.each do |bug|
			puts "Revision: " + bug[:revision]
			puts "Developer: " + bug[:developer]
			puts "Date: " + bug[:date]
			puts "Modified: " + bug[:files][:modified].inspect if bug[:files][:modified]
			#puts "Added: " + bug[:files][:added].size.to_s #if bug[:files][:added]
			#puts "Deleted: " + bug[:files][:deleted].size.to_s #if bug[:files][:deleted]
			puts "------------"
		end
=end
		puts bugs.size
		puts startedAt
		puts Time.now
#		puts @@developers.sort.inspect #h.sort {|a,b| a[1]<=>b[1]}   #=> [["c", 10], ["a", 20], ["b", 30]]
		#puts @@developers.sort {|a,b| b[1]<=>a[1]}   #=> [["c", 10], ["a", 20], ["b", 30]]
		#puts @@dates.sort {|a,b| b[1]<=>a[1]}
	end

	def drawDevelopers
		g = Gruff::Bar.new(750)
		g.title = "Developers"
		#g.theme_37signals
		#g.draw_line_markers
		@@developers.each do |key, value|
			g.data(key, value)
		end
		g.minimum_value = 0
		#g.maximum_value = 600
		g.marker_count = 5 #interval between values
		
		g.x_axis_label = 'Developer Names'
		g.y_axis_label = "Commits"
		#g.hide_legend = false
		#g.labels = labels#{0 => 'Developer Name'}
		g.write('developers.png')
	end
	
	def drawCommits
		g = Gruff::Line.new
		g.title = "Commits"
		g.data("Number of commits", @@dates.values)
		g.y_axis_label = "Commits"
		size = (@@dates.size / 5).to_i
		labels = {}
		1.upto(5) do |i|
			labels[size * i] = (2005 + i).to_s
		end
		puts labels.inspect
		g.labels = labels #{0 => '2006', 70 => '2007', 140 => '2008', 210 => '2009', 280 => '2010'}
		g.write('commits.png')
	end
	
	def countChanges(revision, file)
		prev = revision.to_i - 1
		puts "svn diff -r r#{prev.to_s}:r#{revision.to_s} #{file}"
		out = `svn diff -r r#{prev.to_s}:r#{revision.to_s} #{file}`
		addition = 0
		deletion = 0
		additionEx = /^[+]/
		deletionEx = /^[-]/
		added = out.scan(additionEx)
		deleted = out.scan(deletionEx)
		[added.size, deleted.size]
	end
	
	def getDiff(revision)
		prev = revision.to_i - 1
		puts "svn diff -r r#{prev.to_s}:r#{revision.to_s}"
		out = `svn diff -r r#{prev.to_s}:r#{revision.to_s} https://firebird.svn.sourceforge.net/svnroot/firebird/ | diffstat -t`
		output = {}
		result = []
		#filename = "out.txt"
		extensions = /(.cs$|.cpp$|.c$|.java$)/

		#data = File.read(filename)		
		out.each do |line|
			if extensions.match(line)
				values = line.split(",")
				output["filename"] = values[3].to_s
				output["added"] = values[0].to_s
				output["deleted"] = values[1].to_s
				result << output
				output = {}
 				#puts "File: " +  values[3].to_s
				#puts "Added: " + values[0].to_s
				#puts "Deleted: " + values[1].to_s
			end
		end
		result
	end
	
	def deleteEntries
		commits = Commit.find(:all, :conditions => "revision <= 314")
		commits.each do |commit|
			puts commit.revision
			puts commit.programmer.total_commits.to_s
			commit.programmer.decrement("total_commits", 1)
			commit.programmer.save
			commit.destroy
		end
	end
	
	def reset
		@@revision = ""
		@@date = ""
		@@files = {}
		@@developer = ""
	end
end

x = StdClass.new
x.startMe
#x.drawDevelopers
#x.drawCommits
#x.getDiff(1)
#x.deleteEntries
