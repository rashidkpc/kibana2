require 'rubygems'
require 'json'
require 'time'
require 'net/http'

=begin
= Class: Kelastic
	- Performs an elastic search request
	- Adds Kibana specific object for JS communication
== Parameters:
  query::   The query object to send to ES
  index::   The index to query
=end
class Kelastic
	attr_accessor :response,:url
  def initialize(query,index)

    @url = "http://#{Kelastic.server}/#{index}/_search"
    # TODO: This badly needs error handling for missing indices
  	@response = Kelastic.run(@url,query)

  	@response['kibana'] = {
  		"index"	=> index,
  	}

  end

  def to_s
    JSON.pretty_generate(@response)
  end

  class << self
    def all_indices
      url = URI.parse("http://#{Kelastic.server}/_aliases")
      http = Net::HTTP.new(url.host,url.port)
      if KibanaConfig.constants.include?("ElasticsearchTimeout")
        if KibanaConfig::ElasticsearchTimeout != ''
          http.read_timeout = KibanaConfig::ElasticsearchTimeout
        end
      end

      @status = JSON.parse(
        http.request(Net::HTTP::Get.new(url.request_uri)).body)
      indices = @status.keys
      @status.keys.each do |index|
        if @status[index]['aliases'].count > 0
          indices.concat(@status[index]['aliases'].keys)
        end
      end
      indices.uniq.sort
    end

    # Returns list of index-date names which intersect with range defined by 
    # from and to
    def index_range(from,to,limit = -1)
      if KibanaConfig::Smart_index == true
      	index_pattern = "logstash-%Y.%m.%d"
      	if KibanaConfig::Smart_index_pattern != ""
      	  index_pattern = KibanaConfig::Smart_index_pattern
      	end
        requested = [] # Initialize empty array
        index_pattern = index_pattern.kind_of?(Array) ? 
          index_pattern : [index_pattern]
        for index in index_pattern do
          step_time = from
          begin
            requested << step_time.getutc.strftime(index)
          end while (step_time += KibanaConfig::Smart_index_step) <= to
          unless requested.include? to.getutc.strftime(index)
            requested << to.getutc.strftime(index)
          end
        end

        intersection = requested & all_indices
        if intersection.length <= KibanaConfig::Smart_index_limit
          intersection.sort.reverse[0..limit]
        else
          [KibanaConfig::Default_index]
        end
      else
        [KibanaConfig::Default_index]
      end
    end

    def server
      list = KibanaConfig::Elasticsearch
      if list.kind_of?(Array)
        $eslb ||= 0
        $eslb = $eslb < list.length ? $eslb : 0
        server = list[$eslb]
        $eslb += 1
        server
      else
        list
      end
    end

    # TODO: Verify this index exists?  This is no longer being called.  
    # Possibly remove?
    def current_index
      if KibanaConfig::Smart_index == true
        index_pattern = (KibanaConfig::Smart_index_pattern.empty? ? 
          "logstash-%Y.%m.%d" : KibanaConfig::Smart_index_pattern)
        index_patterns = (index_pattern.kind_of?(Array) ? 
          index_pattern : [index_pattern])

        index_patterns.map do |index|
          (Time.now.utc).strftime(index)
        end
      else
        KibanaConfig::Default_index
      end
    end

    def mapping(index)
      url = URI.parse("http://#{Kelastic.server}/#{index}/_mapping")
      http = Net::HTTP.new(url.host,url.port)
      if KibanaConfig.constants.include?("ElasticsearchTimeout")
        if KibanaConfig::ElasticsearchTimeout != ''
          http.read_timeout = KibanaConfig::ElasticsearchTimeout
        end
      end
      JSON.parse(http.request(Net::HTTP::Get.new(url.request_uri)).body)
    end

    # It would be nice to handle different types here, but we don't do that
    # anywhere else.
    def field_type(index,field)
      attributes = collect_item_attributes(mapping(index),field)[0]
      attributes['type']
    end

    def collect_item_attributes(h,field)
      r = []
      field = field.gsub("\.",".properties.")
      types = h.sort_by { |k,v| v }[0][1]
      types.each do | type |
        r << field.split(".",3).inject(type[1]['properties']) { |hash, key|
          if defined?hash[key]
            hash[key]
          end
        }
      end
      r.reject! { |c| c == nil }
      r
    end

    def error_msg(error)
      result = {}
      result['kibana'] = {
        'error' => error
      }
      result
    end

    def run(url,query)
      url = URI.parse(url)
      http = Net::HTTP.new(url.host, url.port)
      if KibanaConfig.constants.include?("ElasticsearchTimeout")
        if KibanaConfig::ElasticsearchTimeout != ''
          http.read_timeout = KibanaConfig::ElasticsearchTimeout
        end
      end
      res = http.post(url.path, query.to_s,
                      'Accept' => 'application/json',
                      'Content-Type' => 'application/json')

      o = JSON.parse(res.body)
      o['kibana'] = {'per_page' => KibanaConfig::Per_page}
      o['kibana']['error'] = "Invalid query" if res.code.to_i.between?(500, 599)
      o['kibana']['curl_call'] = "curl -XGET #{url}?pretty -d '#{query}'"
      o
    end

    def index_path(index)
      if KibanaConfig::Type != ''
        path = "http://#{Kelastic.server}/#{index}/#{KibanaConfig::Type}"
      else
        path = "http://#{Kelastic.server}/#{index}"
      end
      path
    end

  end

end

=begin
= Class: KelasticSegment
  - Query a specific index in an array of indices
  - Return the position of the next segment if one exists
== Parameters:
  query::   The query object to send to ES
  indices:: An array of indices to query across
  segment:: Position in index array
=end
class KelasticSegment
 attr_accessor :response,:url
  def initialize(query,indices,segment)

    # Make sure we're passed an array, if not, make one
    indices = indices.kind_of?(Array) ? indices : [indices]

    if indices.length < 1
      @response = Kelastic.error_msg("no index")
      return @response
    end

    index = indices[segment]
    @url = "#{Kelastic.index_path(index)}/_search"

    # TODO: This badly needs error handling for missing indices
    @response = Kelastic.run(@url,query)

    @response['kibana']['index'] = indices

    # If there are still indices left, tell the browser which one to request
    if (segment < indices.length - 1)
      @response['kibana']['next'] = segment + 1
    end

  end

  def to_s
    JSON.pretty_generate(@response)
  end
end


=begin
= Class: KelasticMulti
  - Will query indices sequentially and append to result set until 
    query['size'] is reached
== Requires:
  query['size']
  query['from']
== Parameters:
  query::   The query object to send to ES
  indices:: An array of indices to query across
=end
class KelasticMulti
 attr_accessor :response,:url
  def initialize(query,indices)

    if indices.length < 1
      @response = Kelastic.error_msg("no index")
      return @response
    end

    index = indices.first
    @url = "#{Kelastic.index_path(index)}/_search"
    # TODO: This badly needs error handling for missing indices
    @response = Kelastic.run(@url,query)
    if @response['kibana'].has_key?("error")
      return @response
    end


    # Store the original values for reference
    target = query.query['size']
    offset = query.query['from']

    i = 1
    # Didn't get enough hits, and still have indices left?
    while @response['hits']['hits'].length < target and i < indices.length
      # Subtract from size however many hits we already have
      query.query['size'] = target - response['hits']['hits'].length

      # Calculate an offset to account for anything that might have been shown
      # on the previous page, otherwise, set to 0
      query.query['from'] = (offset - response['hits']['total'] < 0) ?
        0 : (offset - response['hits']['total'])

      index = indices[i]
      @url = "#{Kelastic.index_path(index)}/_search"
      if @response['kibana'].has_key?("error")
        return @response
      end

      segment_response = Kelastic.run(@url,query)

      if !segment_response['status'] && segment_response['hits']
        # Concatonate the hits array
        @response['hits']['hits'] += segment_response['hits']['hits']

        # Add the total hits together
        @response['hits']['total'] += segment_response['hits']['total']
        i += 1
      elsif segment_response['status'] && 404 == segment_response['status']
        i += 1
      else
        raise "Bad response for query to: #{@url}, query: #{query} response" +
              " data: #{segment_response.to_yaml}"
      end
    end

    @response['kibana']['index'] = indices

  end

  def to_s
    JSON.pretty_generate(@response)
  end
end

=begin
= Class: KelasticMultiFlat
  - Performs an elastic search request across several indices in 1 query
  - Useful for things like faceting
  - Adds Kibana specific object for JS communication
== Parameters:
  query::   The query object to send to ES
  index::   The indices to query
=end
class KelasticMultiFlat
  attr_accessor :response,:url
  def initialize(query,indices)

    if indices.length < 1
      @response = Kelastic.error_msg("no index")
      return @response
    end

    index = indices.join(',')
    @url = "#{Kelastic.index_path(index)}/_search"
    # TODO: This badly needs error handling for missing indices
    @response = Kelastic.run(@url,query)
    if @response['kibana'].has_key?("error")
      return @response
    end

    @response['kibana']['index'] = index

  end

  def to_s
    JSON.pretty_generate(@response)
  end
end


=begin
= Class: KelasticResponse
  - Helper methods for response objects
=end
class KelasticResponse
  class << self

    # Flatten a response object into an list of objects that contain only the
    # fields in 'fields'
    def flatten_response(response,fields)
      @flat = Array.new
      response['hits']['hits'].each do |hit|
        @flat << flatten_hit(hit,fields)
      end
      @flat
    end

    # Flatten a hit object into an array with only the fields in 'fields'
    def flatten_hit(hit,fields)
      @hit_list = Array.new
      fields.each do |field|
        @hit_list << get_field_value(hit,field)
      end
      @hit_list
    end

    # Retrieve a field value from a hit
    def get_field_value(hit,field)
      recurse_field_dots(hit['_source'],field)
    end

    # Recursively check for multi-dot fields and nested arrays
    def recurse_field_dots(obj,field)
      if !obj[field].nil?
        obj[field]
      elsif field =~ /(.*?)\.(.*)/
        if !obj[$1].nil? and !obj[$1][$2].nil?
          obj[$1][$2]
        elsif !obj[$1].nil?
          recurse_field_dots(obj[$1],$2)
        end
      else
        nil
      end
    end

    # Very similar to flatten_response, except only returns an array of field
    # values, without seperating into hit objects things.
    # Not sure when this broke. Doesn't work for fields store as arrays   
=begin
    def collect_field_values(response,fields)
      @hit_list = Array.new
      fvs = Array.new
      response['hits']['hits'].each do |hit|
        count = 0
        fields.each do |field|
          fv = get_field_value(hit,field)
          if fv.kind_of?(Array)
            fvs[count] = fv.map(&:to_s)
          else
            fvs[count] = fv.to_s
          end
          count=count+1
        end
        @hit_list << fvs.join('||')
      end
      @hit_list
    end
=end
    def collect_field_values(response,field)
      @hit_list = Array.new
      # TODO: Fix this Nasty hack
      field = field[0]
      response['hits']['hits'].each do |hit|
        fv = get_field_value(hit,field)
        if fv.kind_of?(Array)
          @hit_list = @hit_list + fv.map(&:to_s)
        else
          @hit_list << fv.to_s
        end
      end
      @hit_list
    end


    # Returns a hash with a count of values
    def count_field(response,field,limit = 0)
      count = Hash.new(0)
      collect_field_values(response,field).each do |value|
        count[value] += 1
      end
      count = count.sort_by{|key, value| value}.reverse
      if limit > 0
        Hash[count[0..(limit - 1)]]
      else
        Hash[count]
      end
    end

  end
end
