#!/usr/bin/env ruby
require 'net/http'
require 'rexml/document'
require 'md5'
require 'rubygems'
require 'gruff'

api_key = "5c0MqE0WQrDUNVKItj9pA"
email = "shuaib.zahda@gmail.com"

projects = []
retrieved_items = 0
items_available = 0

#link to retrieve the projects based on our parameters
#http://www.ohloh.net/p.xml?&q=tag%3Acharting+language%3Ajava&api_key=5c0MqE0WQrDUNVKItj9pA
#link to retrieve information about each project
#	response, data = session.get("/projects/#{project}/analyses/latest/activity_facts.xml?api_key=#{api_key}", nil)


# Connect to the Ohloh website and retrieve the account data.
http = Net::HTTP.new('www.ohloh.net', 80).start do |session|
	response, data = session.get("/p.xml?q=tag%3Acharting+language%3Ajava&api_key=#{api_key}", nil)
	# HTTP OK?
	if response.code != '200'
		STDERR.puts "#{response.code} - #{response.message}"
		exit 1
	end

# Parse the response into a structured XML object
xml = REXML::Document.new(data)

# Did Ohloh return an error?
	error = xml.root.get_elements('/response/error').first
	if error
		STDERR.puts "#{error.text}"
		exit 1
	end

	# Get how many projects are available in ohloh for our tags
	xml.root.get_elements('/response/').first.each_element do |element|
		items_available = element.text.to_i if element.name == "items_available"
	end

	page = 1
	puts "RETRIEVING PROJECTS NAMES .... "
	
	while retrieved_items < items_available do 
		#here we start retrieving all data from the begining
		response, data = session.get("/p.xml?page=#{page}&q=tag%3Acharting+language%3Ajava&api_key=#{api_key}", nil)
		#to track how many records are retrieved
		xml = REXML::Document.new(data)
		xml.root.get_elements('/response/').first.each_element do |element|
			#puts "#{element.name}:\t#{element.text}" unless element.has_elements?	
			retrieved_items += element.text.to_i	if element.name == "items_returned"
		end

		#get the names of the projects
		xml.root.get_elements('/response/result').first.each_element do |element|
			element.each_element do |sub_element|
					#get the url name of each project in order to use it later to retrieve the information about each project
					puts sub_element.text if 	sub_element.name == "url_name"
					projects << sub_element.text if 	sub_element.name == "url_name"
			end
		end 
		page = page + 1
	end

	#now we have the list of the projects, we loop through them and we retrieve all information about each project
	#then store it in CSV file for each project respectively
	puts "RETRIEVING PROJECTS INFORMATION .... "

	line = []
	file = []
	for project in projects
		#puts "/projects/#{project}/analyses/latest/activity_facts.xml?api_key=#{api_key}"
		#nil projects are projects without url names, in our case we can ignore them

		unless project == nil	
			puts "====================================="
			puts project
			puts "====================================="
			#get info of each project
			response, data = session.get("/projects/#{project}/analyses/latest/activity_facts.xml?api_key=#{api_key}", nil)
			xml = REXML::Document.new(data)
			
			xml.root.get_elements('/response/result').first.each_element do |element|			
				line = []	
				i = 1
				element.each_element do |sub_element|		
					if sub_element.name == "month"
						line << sub_element.text[0..6] + "	"
					else
						if i == 9
							line << sub_element.text		
						else
							line << sub_element.text + "	"		
						end
					end
					i = i + 1
				end
				
				line << "\n"
				file << line.to_s
			end 

			#write to the file
=begin			g = Gruff::Line.new
			g.title = project.to_s
			g.data("Apples", [1, 2, 3, 4, 4, 3])
			g.data("Oranges", [4, 8, 7, 9, 8, 9])
			g.data("Watermelon", [2, 3, 1, 5, 6, 8])
			g.data("Peaches", [9, 9, 10, 8, 7, 9])
			g.labels = {0 => '2003', 2 => '2004', 4 => '2005'}
			g.write("evo/" + project + '.png')
=end
			csvFile = File.new("evo/" + project.to_s + ".csv", 'w')
			csvFile.write(file.to_s)
			csvFile.close
		end
	end
end

