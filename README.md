[![Build Status](https://secure.travis-ci.org/invadersmustdie/Kibana.png?branch=kibana-ruby)](https://travis-ci.org/invadersmustdie/Kibana)

# Kibana
__NOTE__: You have reached the repository for Kibana 2, the ruby version of Kibana. Kibana 3 can be found at [https://github.com/elasticsearch/kibana](https://github.com/elasticsearch/kibana)

Copyright 2012 Rashid Khan <rashidkpc #logstash irc.freenode.net>

Kibana is a browser based interface for Logstash and ElasticSearch that allows 
you to efficiently search, visualize, analyze and otherwise make sense of your 
logs. 

More information at [http://www.kibana.org](http://www.kibana.org)

## Requirements

__Base__

* ruby >= 1.8.7 (probably?)  
* bundler  
* logstash >= 1.1.0  
* elasticsearch >= 0.18.0  

__JRuby__

* java >= 1.6
* warbler if you want to create an executable standalone war file

## Installation
__Install__  
1. git clone --branch=kibana-ruby https://github.com/rashidkpc/Kibana.git	
2. cd Kibana  
3. gem install bundler  
4. bundle install  

__Configure__  
Set your elasticsearch server in KibanaConfig.rb:  
	`Elasticsearch = "elasticsearch:9200"`

__Run__  
`ruby kibana.rb`  

__Use__  
  Point your browser at http://localhost:5601

## JRuby

To run Kibana with JRuby, e.g. if you have to run in on a windows machine, you can create a (executable) WAR archive.

```
git clone --branch=kibana-ruby https://github.com/rashidkpc/Kibana.git	
cd Kibana  	
jruby -S gem install bundler  
jruby -S bundle install   
```

Configure your environment (see above). 	
`jruby -S rake war  `
or  
`jruby -S warble executable war  `
if you want to include a webserver (default: jetty).  

Run:	
`	java [-Djetty.port=5601] -jar Kibana.war`

_Todo_: Externalize the configuration. Any help would be appreciated.  

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

Q: How do I run Kibana under Apache?
A: There's a few samples in the sample/apache directory on how to do this.

Q: Kibana is great, but I want to make it so users have to authenticate in order
to access it. How do I do that?
A: This can be handled a number of ways. The best way is to run Kibana with 
Passenger and Apache or Nginx. There's sample configurations in the sample 
directory. You can then handle your preferred authentication mechanism with
Apache or Nginx.

Q: Where can I get some help with this?                                         
A: Find me on Freenode - rashidkpc in #logstash   
