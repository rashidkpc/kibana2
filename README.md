[![Build Status](https://secure.travis-ci.org/invadersmustdie/Kibana.png?branch=kibana-ruby)](https://travis-ci.org/invadersmustdie/Kibana)

# Kibana
Copyright 2012 Rashid Khan <rashidkpc #logstash irc.freenode.net>

http://www.kibana.org

Kibana is a browser based interface for Logstash and ElasticSearch that allows 
you to efficiently search, visualize, analyze and otherwise make sense of your 
logs. 

## Requirements

ruby >= 1.8.7 (probably?)  
bundler  
logstash >= 1.1.0  
elasticsearch >= 0.18.0  
java >= 1.6 if you want to run Kibana in JRuby	

## Installation
Install:  
  git clone --branch=kibana-ruby https://github.com/rashidkpc/Kibana.git	
  cd Kibana  
	gem install bundler  
	bundle install  

Configure:  
Set your elasticsearch server in KibanaConfig.rb:  
	Elasticsearch = "elasticsearch:9200"  

Run:  
	ruby kibana.rb  

Use:  
  Point your browser at http://localhost:5601

## JRuby

To run Kibana with JRuby, e.g. if you have to run in on a windows machine, you can create a (executable) WAR archive.
Currently you still need Ruby for creating the archive.	

git clone --branch=jruby https://github.com/falkenbt/Kibana.git	
cd Kibana  	
Configure your environment (see above). 	
warble [executable] war	

Run:	
	java -jar Kibana.war [--httpPort=5601]

Todo: Externalize the configuration. Any help would be appreciated.  

## FAQ
Q: Why is there no last button?  
A: ElasticSearch isn't so hot at going to the last result of a many million 
result query. 

Q: Why is this Ruby instead of PHP now?  
A: Closer integration with logstash, Ruby is shiny. Its mostly javascript 
anyway. If you want it in something else, it shouldn't be too hard to port.  

Q: Why do I have to set a limit on events to analyze?
A: Big result sets take a long time to retrieve from elasticsearch and parse out  

Q: Well then why don't you use the Elastic Search terms facet?  
A: I've found the terms facet to cause out of memory crashes with large result 
sets. I don't know a way to limit the amount of memory a facet may use. Until 
there's a way to run a facet and know for sure it  won't crash Elastic Search, 
I'm going to keep analysis features implemented in Ruby. I'm open to other 
suggestions though. I suggest you be careful with the Statistics mode, its more
stable than terms, and I try to detect when it might be dangerous but can still
bite you.  

Q: Why do some results not show up when I search for a string I know is in
the elasticsearch indexes?  
A: If you are searching analyzed fields, which is the default in ES for string
fields, remember that they are broken down into terms.  For instance, a search
for "test" will match records containing test@bleh.com, since @ is a term
boundary and is broken down into "test" and "bleh.com".  However, this will NOT
match records containing blah@test.com because "test.com" is the full term and
you are searching for an exact match.  You would need to use test to match both
of these records.  Note you may also want to configure the ES analyze behavior
for certain fields if this is not the desired behavior.  Helpful References:  

  http://www.elasticsearch.org/guide/reference/mapping/core-types.html  
  http://www.elasticsearch.org/guide/reference/api/admin-indices-templates.html  

Q: Where can I get some help with this?                                         
A: Find me on Freenode - rashidkpc in #logstash   
