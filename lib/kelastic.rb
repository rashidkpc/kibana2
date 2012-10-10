require 'rubygems'
require 'json'
require 'time'
require 'curb'

$LOAD_PATH << './lib'
$LOAD_PATH << '..'
require 'query'
require 'compat'
require 'kibana_config'

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
      url = "http://#{Kelastic.server}/_status"
      c = Curl::Easy.new(url)
      c.perform
      @status = JSON.parse(c.body_str)
      @status['indices'].keys.sort
    end

    def date_range(from,to)
      (Date.parse(from.getutc.to_s)..Date.parse(to.getutc.to_s)).to_a
    end

    def index_range(from,to)
      if KibanaConfig[:smart_index]
      	index_pattern = "logstash-%Y.%m.%d"
      	if KibanaConfig[:smart_index_pattern] != ""
      	  index_pattern = KibanaConfig[:smart_index_pattern]
      	end
        requested = date_range(from,to).map{ |date| date.strftime(index_pattern) }
        intersection = requested & all_indices
        if intersection.length <= KibanaConfig[:smart_index_limit]
          intersection.sort.reverse
        else
          KibanaConfig[:default_index]
        end
      else
        KibanaConfig[:default_index]
      end
    end

    def server
      list = KibanaConfig[:elasticsearch]
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

    # TODO: Verify this index exists?
    def current_index
      if KibanaConfig[:smart_index]
        index_pattern = "logstash-%Y.%m.%d"
      	if KibanaConfig[:smart_index_pattern] != ""
      	  index_pattern = KibanaConfig[:smart_index_pattern]
      	end
        (Time.now.utc).strftime(index_pattern)
      else
        KibanaConfig[:default_index]
      end
    end

    def mapping(index)
      url = "http://#{Kelastic.server}/#{index}/_mapping"
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

    def error_msg(error)
      result = {}
      result['kibana'] = {
        'error' => error
      }
      result
    end

    def run(url,query)
      c = Curl::Easy.http_post(url, query.to_s) do |curl|
        curl.headers['Accept'] = 'application/json'
        curl.headers['Content-Type'] = 'application/json'
      end
      parsed = JSON.parse(c.body_str)
      parsed['kibana'] = {
        'per_page'    => KibanaConfig[:per_page]
      }
      if c.response_code == 500
        parsed['kibana']['error'] = "Invalid query"
      end
      parsed
    end

    def index_path(index)
      if KibanaConfig[:type] != ''
        path = "http://#{Kelastic.server}/#{index}/#{KibanaConfig[:type]}"
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

      # Concatonate the hits array
      @response['hits']['hits'] += segment_response['hits']['hits']

      # Add the total hits together
      @response['hits']['total'] += segment_response['hits']['total']
      i += 1
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
      field[0,1] == '@' ? hit['_source'][field] : hit['_source']['@fields'][field];
    end

    # Very similar to flatten_response, except only returns an array of field
    # values, without seperating into hit objects things.
    def collect_field_values(response,field)
      @hit_list = Array.new
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
