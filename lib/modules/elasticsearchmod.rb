class Elasticsearchmod

  def initialize(index,type)
    @index=index
    @type=type
    @query_url = "http://#{Elasticsearchmod.server}/#{@index}/#{@type}"
  end

  def get_by_id(id)
    r = Elasticsearchmod.run("#{@query_url}/#{id}", '', 'get')
    if ! r['exists']
      nil
    else
      r['_source']
    end
  end

  def set_by_id(id, values)
    values = values.to_json
    result  = Elasticsearchmod.run("#{@query_url}/#{id}", values)
  end

  def del_by_id(id)
    result  = Elasticsearchmod.run("#{@query_url}/#{id}", '', 'delete')
  end

  def get_all(field=nil)
    results = Array.new
    r = Elasticsearchmod.run("#{@query_url}/_search", '{}')
    r['hits']['hits'].each do |hit|
      if field
        results << hit['_source'][field]
      else
        results << hit['_source']
      end
    end
    return results
  end

  def del_term_from_record_array(id, term, value)
    query = '{ "script" : "ctx._source.'+term+'.remove(value)", "params" : {"value" : "'+value+'"}}'
    r = Elasticsearchmod.run("#{@query_url}/#{id}/_update", query)
    return True
  end

  def add_term_to_record_array(id, term, value, defaults)
    defaults = defaults.to_json
    query = '{ "script" : "ctx._source.'+term+' += value",
               "params" : {"value" : "'+value+'"},
               "upsert" : '+defaults+'
             }'
    r = Elasticsearchmod.run("#{@query_url}/#{id}/_update", query)
    return True
  end

  def get_record_ids_with_term(term, value)
    results = Array.new
    r = Elasticsearchmod.run("#{@query_url}/_search", '{ "query": { "term": { "'+term+'": "'+value+'" } } }')
    r = r['hits']
    if r['total'] >= 1
      r['hits'].each do |hit|
        results << hit['_id']
      end
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
      when 'delete' then
        res = http.delete(url.path, 'Accept' => 'application/json')
      end

      o = JSON.parse(res.body)
      error = "Invalid query" if res.code.to_i.between?(500, 599)
      o
    end
  end


end
