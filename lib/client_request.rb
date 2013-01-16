require 'rubygems'
require 'json'
require 'base64'
require 'time'

=begin
= Class: ClientRequest
  Creates an object out of the hash passed by a client
== Parameters:
  hash::   Base64 encoded JSON string
=end
class ClientRequest
  attr_accessor :search,:from,:to,:offset,:fields,:analyze

  def initialize(hash)
    @request = JSON.parse(Base64.decode64(URI.unescape(hash)))

    @search = @request['search']
    if @search != "" and @search.include? "|"
      @search = @search.strip().split('|')[0].strip()
    end

    @index  = @request['index']
    @offset = @request['offset'].nil? ? 0 : @request['offset']

    @fields = @request['fields'].length == 0 ?
      KibanaConfig::Default_fields : @request['fields']

    @analyze = @request['analyze_field']

    # Sort out proper to and from.
    # This eventually needs to move into javascript
    case @request['timeframe']
    when "custom"
      # TODO: Need some validation here
      @from = Time.iso8601(@request['time']['from'])
      @to = Time.iso8601(@request['time']['to'])
    when "all"
      @from = (Time.at(0))
      @to = (Time.now)
    else
      diff = (@request['timeframe'].to_i <= 0 ? 
        KibanaConfig::Fallback_interval  : @request['timeframe'].to_i)

      @from = (Time.now - diff)
      @to = (Time.now)
    end
  end

  def to_s
    JSON.pretty_generate(@request)
  end

  #
  # Creates a Base64 JSON hash out of a ruby object
  #
  class << self
    def hash(request)
      Base64.encode64(JSON.generate(request))
    end
  end
end
