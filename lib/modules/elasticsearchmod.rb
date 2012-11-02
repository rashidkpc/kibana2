class Elasticsearchmod
  puts "Elasticsearchmod..."

  def initialize(index,type)
    @index=index
    @type=type
    @query_url = "http://#{Elasticsearchmod.server}/#{@index}/#{@type}"
  end

  def get_by_id(id)
    r = Elasticsearchmod.run("#{@query_url}/#{id}", '', 'get')
    r['_source']
  end

  def set_by_id(id, values)
    values = values.to_json
    result  = Elasticsearchmod.run("#{@query_url}/#{id}", values)
  end

  def get_all
    results = Array.new
    r = Elasticsearchmod.run("#{@query_url}/_search", '{}')
    r['hits']['hits'].each do |hit|
      results << hit['_source']
    end
    return results
  end

  class << self
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

    def run(url,query,method='post')
      url = URI.parse(url)
      http = Net::HTTP.new(url.host, url.port)
      case method
      when 'post' then
        res = http.post(url.path, query.to_s,
                        'Accept' => 'application/json',
                        'Content-Type' => 'application/json')
      when 'get' then
        res = http.get(url.path, 'Accept' => 'application/json')
      end

      o = JSON.parse(res.body)
      error = "Invalid query" if res.code.to_i.between?(500, 599)
      o
    end
  end


end
