require "socket"  
require "openssl"
require "base64"
require 'rexml/document'
require 'digest/md5'

class StdClass
	def initialize
		
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
	
	def construct_response(hash)
		response = {}
		response["username"] = "\"shuaibzahda\""
		response["realm"] = hash["realm"]
		response["nonce"] = hash["nonce"]
		response["nc"] = "00000001"
		response["qop"] = hash["qop"].gsub("\"", '')
		response["digest-uri"] = "\"xmpp/chat.facebook.com\""
		response["charset"] = hash["charset"]
		response["cnonce"] = "\"" + Digest::MD5.hexdigest("al-zahidi") + "\""
		
		#creating response entry
		# 1. Create a string of the form "username:realm:password". Call this string X.
		x = "shuaibzahda:" + response["realm"].gsub("\"", '') + ":hi.man.za."
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
		#username="shuaibzahda",realm="chat.facebook.com",nonce="7B2F6986A71F3958D392269889A58461",cnonce="8f78449bdae4fa47bdb56907499522b2",nc=00000001,qop=auth,digest-uri="xmpp/chat.facebook.com",response=5b8169472fe466e25975fdfa9de4a797,charset=utf-8

		response_auth = "username=" + response["username"] + ",realm=" + response["realm"] + ",nonce=" +
						response["nonce"] + ",cnonce=" + response["cnonce"] + ",nc=" + response["nc"] +
						",qop=" + response["qop"] + ",digest-uri=" + response["digest-uri"] + ",response=" + response["response"] + ",charset=" +
						response["charset"]
	end
	
	def construct_facebook(hash)
		#API Key	1d72371aae915837ae7fe828ffc6bd86
		#Secret	c96122dff1f6acde22cec42698154bc4
		response = {}		
		response["api_key"] = "1d72371aae915837ae7fe828ffc6bd86"
		response["secret"] = "c96122dff1f6acde22cec42698154bc4"
		response["nonce"] = hash["nonce"]
		response["cnonce"] = Digest::MD5.hexdigest("al-zahidi")
		response["method"] = hash["method"]
		response["v"] = "1.0" #hash["version"]
		response["call_id"] = Time.now.to_f
		#response['session_key'] = ""
		
		sig = 'api_key=' + response["api_key"] + 'call_id=' + response['call_id'].to_s +
				'method=' + response['method'] + 'nonce=' + response['nonce'] +
				'v=' + response['v'] + response["secret"]
				#'session_key=' + response['session_key'] + 'v=' + response['v'] + response["secret"]
						
		response['sig'] = Digest::MD5.hexdigest(sig)
		
		response_text = 'api_key=' + response["api_key"] + '&call_id=' + response['call_id'].to_s +
				'&method=' + response['method'] + '&nonce=' + response['nonce'] + '&cnonce=' +
				response["cnonce"] + '&v=' + response['v']
		response_text
=begin

API Key	1d72371aae915837ae7fe828ffc6bd86
Secret	c96122dff1f6acde22cec42698154bc4

version=1&method=auth.xmpp_login&nonce=AC1EF310FD20284F556638263B51E94C

So, server sent you a challenge like 
dmVyc2lvbj0xJm1ldGhvZD1hdXRoLnhtcHBfbG9naW4mbm9uY2U9NDM0NkI5QkZDNUExNjBENDZBRjI1NzMyQUNGQzdDQzM= 
which is base64 encoded. Decoded message is version=1&method=auth.xmpp_login&nonce=4346B9BFC5A160D46AF25732ACFC7CC3 . 
You separate the message to some sort of map with keys and values. Then you have to construct the response. 
This is the funny part. First of all, prepare these values: api_key, api_secret and session_key. 
What is really hard is to find out how to calculate sig. So there it is. 
Add api_key, call_id, method, nonce, session_key and v to map in alphabetical order
(method and nonce is from server challenge, v is 1.0 and call_id can be current time in millis). 
Then construct the string like key1=value1key2=value2... without & and without url encoding values. 
Concat the api_secret. Calculate MD5 and translate to hex(big probability it has to be lowercase). 
This is the sig value. Now, you need to construct url encoded string of params(the same as when calculating sig, 
but separated with & and url encoded). Also add the sig param. At this point encode the string with base64 and 
you should be ready to send it back to server and connect. Dont forget, you have to have xmpp_login permission.


$fb_api_key = 'YOUR_FB_API_KEY';
$fb_api_secret= 'YOUR_FB_API_SECRET';
$fb_session_key = $facebook_client->api_client->session_key;

$challenge = base64_decode($the_value_from_the_challenge_tag);
$vars = array();
parse_str($challenge, $vars);

if (!empty($vars['nonce'])) {
  $response = array(
    'api_key'     => $fb_api_key,
    'call_id'     => time(),
    'method'      => $vars['method'],
    'nonce'       => $vars['nonce'],
    'session_key' => $fb_session_key,
    'v'           => '1.0',
  );

  $response['sig'] = 'api_key=' . $response['api_key']
                   . 'call_id=' . $response['call_id']
                   . 'method=' . $response['method']
                   . 'nonce=' . $response['nonce']
                   . 'session_key=' . $response['session_key']
                   . 'v=' . $response['v']
                   . $fb_api_secret;

  $response['sig'] = md5($response['sig']);
  $response = http_build_query($response);
  $response = base64_encode($response);

  $connection->send("<response xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>{$response}</response>");
}
string method Should be the same as the method specified by the server.
string nonce Should be the same as the nonce specified by the server.
string v This must be set to 1.0 to use this version of the API.
string api_key The application key associated with the calling application.

string session_key The session key of the logged in user.
float call_id The request's sequence number.
string sig An MD5 hash of the current request and your secret key.
=end
		
	end
	
	def connection
	to = "chat.facebook.com"
	host = "chat.facebook.com"
#	to = "gmail.com"
#	host = "talk.google.com"
	port = 5222

	initiate = "<stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' to='#{to}' version='1.0'>"	
	sasl = "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>"
	#sasl = "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='X-FACEBOOK-PLATFORM'/>"
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
	#decoded = Base64.decode64(extracted_code)
	#puts decoded
#	md5Values = getValuesFromDecoded(decoded, "&")
	md5Values = getValuesFromDecoded(decoded, ",") #md5 mechanism
	puts md5Values.inspect
	#response_value = construct_facebook(md5Values)
	#puts response_value.inspect
	#encode the response value
	#response = "<response xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>" + Base64.encode64(response_value) + "</response>"	
	#puts response
	response_value = construct_response(md5Values)
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
	puts ss.recv(1000)

	ss.close
	end
end

x = StdClass.new
x.connection

#google = "<?xml version='1.0'?> \n <stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' to='#{gmail}' version='1.0'>";	
#	req = "<iq type='get' id='reg1' to='#{to}'><query xmlns='jabber:iq:register'/></iq>"
