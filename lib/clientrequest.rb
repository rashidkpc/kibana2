require 'rubygems'
require 'json'
require 'base64'
require 'time'

$LOAD_PATH << './lib'
$LOAD_PATH << '..'
require 'KibanaConfig'
require 'compat'


=begin
= Class: ClientRequest
  Creates an object out of the hash passed by a client
== Parameters:
  hash::   Base64 encoded JSON string
=end
class ClientRequest
  attr_accessor :search,:from,:to,:offset,:fields,:analyze

  def initialize(hash)
    @request = JSON.parse(Base64.decode64(hash))

    @search = @request['search']
    @index  = @request['index']
    @offset = @request['offset'].nil? ? 0 : @request['offset']

    @fields = @request['fields']

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
      # TODO: validation here
      @from = (Time.now - @request['timeframe'].to_i)
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

=begin
= Class: IDRequest
  Creates an client request for a specific ID
== Parameters:
  id::    ID of log
  index:: Index ID is found in
=end
class IDRequest
  attr_accessor :request
  def initialize(id,index)
    @request = {
      "id"        => "#{id}",
      "index"     => index,
      "timeframe" => "900",
      "mode"      => "id",
      "fields"    => '',
      "offset"    => 0,
    }
  end

  def hash
    ClientRequest.hash(@request)
  end
end

