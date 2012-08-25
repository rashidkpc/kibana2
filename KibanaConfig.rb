module KibanaConfig
	attr_accessor :elasticsearch
  # Your elastic search server
  Elasticsearch = "elasticsearch:9200"

  # The port Kibana should listen on
  KibanaPort = 5601

  # The record type as defined in your logstash configuration.
  # Seperate multiple types with a comma, no spaces. Leave blank
  # for all.
  Type = ''

  # TODO: Not functional yet. Results to show per page
  Per_page = 50

  # TODO: Not functional yet. 
  # You may wish to insert a default search which all user searches
  # must match. For example @source_host:www1 might only show results
  # from www1.
  Filter = ''

  # TODO: Not functional yet. (Smart indexing is always on right now) 
  # When searching, Kibana will attempt to only search indices
  # that match your timeframe, to make searches faster. You can
  # turn this behavior off if you use something other than daily
  # indexing
  Smart_index = true

  # TODO: Not functional yet. (Smart indexing is always on right now) 
  # ElasticSearch has a default limit on URL size for REST calls,
  # so Kibana will fall back to _all if a search spans too many
  # indices. Use this to set that 'too many' number. 
  Smart_index_limit = 60

  # When using analyze, use this many of the most recent
  # results for user's query
  Analyze_limit = 2000

  # Show this many results in analyze/ mode
  Analyze_show = 25

  # Show this many results in an rss feed
  Rss_show = 20

  # Show this many results in an exported file
  Export_show = 2000

  # Delimit exported file fields with what?
  # You may want to change this to something like "\t" (tab) if you have
  # commas in your logs
  Export_delimiter = ","

  # You probably don't want to touch anything below this line
  # unless you really know what you're doing

  # Primary field. By default Elastic Search has a special
  # field called _all that is searched when no field is specified.
  # Dropping _all can reduce index size significantly. If you do that
  # you'll need to change primary_field to be '@message'
  Primary_field = '_all'

  # TODO: Make this functional Re: smart_index
  # Default Elastic Search index to query
  Default_index = '_all'

  # TODO: This isn't functional yet
  # Prevent wildcard search terms which result in extremely slow queries
  # See: http:#www.elasticsearch.org/guide/reference/query-dsl/wildcard-query.html
  Disable_fullscan = false
end
