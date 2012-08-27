require 'rubygems'
require 'json'
require 'time'
require 'curb'
require 'query'
require 'KibanaConfig'

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

    @url = "http://#{KibanaConfig::Elasticsearch}/#{index}/_search"
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
      url = "http://#{KibanaConfig::Elasticsearch}/_status"
      c = Curl::Easy.new(url)
      c.perform
      @status = JSON.parse(c.body_str)
      @status['indices'].keys.sort
    end

    def date_range(from,to)
      (Date.parse(from.getutc.to_s)..Date.parse(to.getutc.to_s)).to_a
    end

    def index_range(from,to)
      if KibanaConfig::Smart_index == true
        requested = date_range(from,to).map{ |date| date.strftime("logstash-%Y.%m.%d") }
        intersection = requested & all_indices
        if intersection.length <= KibanaConfig::Smart_index_limit
          intersection.sort.reverse
        else
          KibanaConfig::Default_index
        end
      else
        KibanaConfig::Default_index
      end
    end

    # TODO: Verify this index exists?
    def current_index
      (Time.now).strftime("logstash-%Y.%m.%d")
    end

    def mapping(index)
      url = "http://#{KibanaConfig::Elasticsearch}/#{index}/_mapping"
      c = Curl::Easy.new(url)
      c.perform
      JSON.parse(c.body_str)
    end

    # It would be nice to handle different types here, but we don't do that
    # anywhere else.
    def field_type(index,field)
      attributes = collect_item_attributes(mapping(index),field)
      attributes['type']
    end

    def collect_item_attributes(h,field)
      result = {}
      h.each do |k, v|
        if k == field
          h[k].each {|k, v| result[k] = v }
        elsif v.is_a? Hash
          collect_item_attributes(h[k],field).each do |k, v|
            result[k] = v
          end
        end
      end
      result
    end

    def run(url,query)
      c = Curl::Easy.http_post(url, query.to_s) do |curl|
        curl.headers['Accept'] = 'application/json'
        curl.headers['Content-Type'] = 'application/json'
      end
      JSON.parse(c.body_str)
    end

    def index_path(index)
      if KibanaConfig::Type != ''
        path = "http://#{KibanaConfig::Elasticsearch}/#{index}/#{KibanaConfig::Type}"
      else
        path = "http://#{KibanaConfig::Elasticsearch}/#{index}"
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
    index = indices[segment]
    @url = "#{Kelastic.index_path(index)}/_search"
    
    # TODO: This badly needs error handling for missing indices
    @response = Kelastic.run(@url,query)

    @response['kibana'] = {
      "index" => indices,
    }

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
  - Will query indices sequentially and append to result set until query['size'] is reached
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

    index = indices.first
    @url = "#{Kelastic.index_path(index)}/_search"
    # TODO: This badly needs error handling for missing indices
    @response = Kelastic.run(@url,query)

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
      @url = "http://#{Kelastic.index_path(index)}/_search"
      segment_response = Kelastic.run(@url,query)

      # Concatonate the hits array
      @response['hits']['hits'] += segment_response['hits']['hits']

      # Add the total hits together
      @response['hits']['total'] += segment_response['hits']['total']
      i += 1
    end

    @response['kibana'] = {
      "index" => indices,
    }

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

    index = indices.join(',')
    @url = "#{Kelastic.index_path(index)}/_search"
    # TODO: This badly needs error handling for missing indices
    @response = Kelastic.run(@url,query)

    @response['kibana'] = {
      "index" => index,
    }

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
      field[0,1] == '@' ? hit['_source'][field].to_s : hit['_source']['@fields'][field].to_s;
    end

    # Very similar to flatten_response, except only returns an array of field
    # values, without seperating into hit objects things.
    def collect_field_values(response,field)
      @hit_list = Array.new
      response['hits']['hits'].each do |hit|
        @hit_list << get_field_value(hit,field)
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
