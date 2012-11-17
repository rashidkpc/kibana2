module KibanaConfig

  # A Note: While the only option you really have to set is "Elasticsearch" it
  # is HIGHLY recommended you glance over every option. I personally consider
  # 'Facet_index_limit' really important.

  # Your elastic search server(s). This may be set as an array for round robin
  # load balancing
  # Elasticsearch = ["elasticsearch1:9200","elasticsearch2:9200"]
  Elasticsearch = "localhost:9200"

  # The port Kibana should listen on
  KibanaPort = 5601

  # The adress ip Kibana should listen on. Comment out or set to
  # 0.0.0.0 to listen on all interfaces.
  KibanaHost = '127.0.0.1'

  # The record type as defined in your logstash configuration.
  # Seperate multiple types with a comma, no spaces. Leave blank
  # for all.
  Type = ''

  # Results to show per page
  Per_page = 50

  # Timezone. Leave this set to 'user' to have the user's browser autocorrect.
  # Otherwise, set a timezone string
  # Examples: 'UTC', 'America/Phoenix', 'Europe/Athens', MST
  # You can use `date +%Z` on linux to get your timezone string
  Timezone = 'user'

  # Format for timestamps. Defaults to mm/dd HH:MM:ss.
  # For syntax see: http://blog.stevenlevithan.com/archives/date-time-format
  # Time_format = 'isoDateTime' 
  Time_format = 'mm/dd HH:MM:ss'

  # Change which fields are shown by default. Must be set as an array
  # Default_fields = ['@fields.vhost','@fields.response','@fields.request']
  Default_fields = ['@message']

  # The default operator used if no explicit operator is specified.
  # For example, with a default operator of OR, the query capital of
  # Hungary is translated to capital OR of OR Hungary, and with default
  # operator of AND, the same query is translated to capital AND of AND
  # Hungary. The default value is OR.
  Default_operator = 'OR'

  # When using analyze, use this many of the most recent
  # results for user's query
  Analyze_limit = 2000

  # Show this many results in analyze/trend/terms/stats modes
  Analyze_show = 25

  # Show this many results in an rss feed
  Rss_show = 25

  # Show this many results in an exported file
  Export_show = 2000

  # Delimit exported file fields with what?
  # You may want to change this to something like "\t" (tab) if you have
  # commas in your logs
  Export_delimiter = ","

  # You may wish to insert a default search which all user searches
  # must match. For example @source_host:www1 might only show results
  # from www1.
  Filter = ''

  # When searching, Kibana will attempt to only search indices
  # that match your timeframe, to make searches faster. You can
  # turn this behavior off if you use something other than daily
  # indexing
  Smart_index = true
  
  # You can define your custom pattern here for index names if you 
  # use something other than daily indexing. Pattern needs to have 
  # date formatting like '%Y.%m.%d'.  Will accept an array of smart 
  # indexes.  
  # Smart_index_pattern = ['logstash-web-%Y.%m.%d', 'logstash-mail-%Y.%m.%d'] 
  Smart_index_pattern = 'logstash-%Y.%m.%d'

  # ElasticSearch has a default limit on URL size for REST calls,
  # so Kibana will fall back to _all if a search spans too many
  # indices. Use this to set that 'too many' number. By default this
  # is set really high, ES might not like this
  Smart_index_limit = 150

  # Elasticsearch has an internal mechanism called "faceting" for performing
  # analysis that we use for the "Stats" and "Terms" modes. However, on large
  # data sets/queries facetting can cause ES to crash if there isn't enough 
  # memory available. It is suggested that you limit the number of indices that
  # Kibana will use for the "Stats" and "Terms" to prevent ES crashes. For very
  # large data sets and undersized ES clusers, a limit of 1 is not unreasonable.
  # Default is 0 (unlimited)
  Facet_index_limit = 0

  # You probably don't want to touch anything below this line
  # unless you really know what you're doing

  # Primary field. By default Elastic Search has a special
  # field called _all that is searched when no field is specified.
  # Dropping _all can reduce index size significantly. If you do that
  # you'll need to change primary_field to be '@message'
  Primary_field = '_all'

  # Default Elastic Search index to query
  Default_index = '_all'

  # TODO: This isn't functional yet
  # Prevent wildcard search terms which result in extremely slow queries
  # See: http:#www.elasticsearch.org/guide/reference/query-dsl/wildcard-query.html
  Disable_fullscan = false

  # Set headers to allow kibana to be loaded in an iframe from a different origin.
  Allow_iframed = false

  # Use this interval as fallback.
  Fallback_interval = 900
end
