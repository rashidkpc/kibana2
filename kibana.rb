require 'rubygems'
require 'sinatra'
require 'json'
require 'time'
require 'date'
require 'rss/maker'
require 'yaml'
require 'tzinfo'

$LOAD_PATH << '.'
$LOAD_PATH << './lib'

if ENV["KIBANA_CONFIG"] 
  require ENV["KIBANA_CONFIG"]
else
  require 'KibanaConfig'
end
Dir['./lib/*.rb'].each{ |f| require f }
ruby_18 { require 'fastercsv' }
ruby_19 { require 'csv' }

configure do
  set :bind, defined?(KibanaConfig::KibanaHost) ? KibanaConfig::KibanaHost : '0.0.0.0'
  set :port, KibanaConfig::KibanaPort
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end

helpers do
  def link_to url_fragment, mode=:full_url
    case mode
    when :path_only
      base = request.script_name
    when :full_url
      if (request.scheme == 'http' && request.port == 80 ||
          request.scheme == 'https' && request.port == 443)
        port = ""
      else
        port = ":#{request.port}"
      end
      base = "#{request.scheme}://#{request.host}#{port}#{request.script_name}"
    else
      raise "Unknown script_url mode #{mode}"
    end
    "#{base}#{url_fragment}"
  end

end

get '/' do
  headers "X-Frame-Options" => "allow","X-XSS-Protection" => "0" if KibanaConfig::Allow_iframed
  send_file File.join(settings.public_folder, 'index.html')
end

get '/stream' do
  send_file File.join(settings.public_folder, 'stream.html')
end

# Returns
get '/api/search/:hash/?:segment?' do
  segment = params[:segment].nil? ? 0 : params[:segment].to_i

  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,req.from,req.to,req.offset)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)

  # Not sure this is required. This should be able to be handled without
  # server communication
  result.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}
  result.response['kibana']['default_fields'] = KibanaConfig::Default_fields
  result.response['kibana']['maxlines'] = KibanaConfig::Max_lines

  JSON.generate(result.response)
end

get '/api/graph/:mode/:interval/:hash/?:segment?' do
  segment = params[:segment].nil? ? 0 : params[:segment].to_i

  req     = ClientRequest.new(params[:hash])
  case params[:mode]
  when "count"
    query   = DateHistogram.new(req.search,req.from,req.to,params[:interval].to_i)
  when "mean"
    query   = StatsHistogram.new(req.search,req.from,req.to,req.analyze,params[:interval].to_i)
  end
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticSegment.new(query,indices,segment)

  JSON.generate(result.response)
end

get '/api/id/:id/:index' do
  ## TODO: Make this verify that the index matches the smart index pattern.
  id      = params[:id]
  index   = "#{params[:index]}"
  query   = IDQuery.new(id)
  result  = Kelastic.new(query,index)
  JSON.generate(result.response)
end

get '/api/analyze/:field/trend/:hash' do
  limit = KibanaConfig::Analyze_limit
  show  = KibanaConfig::Analyze_show
  req           = ClientRequest.new(params[:hash])

  query_end     = SortedQuery.new(req.search,req.from,req.to,0,limit,'@timestamp','desc')
  indices_end   = Kelastic.index_range(req.from,req.to)
  result_end    = KelasticMulti.new(query_end,indices_end)

  # Oh snaps. too few results for full limit analysis, rerun with less
  if (result_end.response['hits']['hits'].length < limit)
    limit         = (result_end.response['hits']['hits'].length / 2).to_i
    query_end     = SortedQuery.new(req.search,req.from,req.to,0,limit,'@timestamp','desc')
    indices_end   = Kelastic.index_range(req.from,req.to)
    result_end    = KelasticMulti.new(query_end,indices_end)
  end

  fields = Array.new
  fields = params[:field].split(',,')
  count_end     = KelasticResponse.count_field(result_end.response,fields)

  query_begin   = SortedQuery.new(req.search,req.from,req.to,0,limit,'@timestamp','asc')
  indices_begin = Kelastic.index_range(req.from,req.to).reverse
  result_begin  = KelasticMulti.new(query_begin,indices_begin)
  count_begin   = KelasticResponse.count_field(result_begin.response,fields)



  # Not sure this is required. This should be able to be handled without
  # server communication
  result_end.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}

  final = Array.new(0)
  count = result_end.response['hits']['hits'].length
  count_end.each do |key, value|
    first = count_begin[key].nil? ? 0 : count_begin[key];
    final << {
      :id    => key,
      :count => value,
      :start => first,
      :trend => (((value.to_f / count) - (first.to_f / count)) * 100).to_f
    }
  end
  final = final.sort_by{ |hsh| hsh[:trend].abs }.reverse

  result_end.response['hits']['count'] = result_end.response['hits']['hits'].length
  result_end.response['hits']['hits'] = final[0..(show - 1)]
  JSON.generate(result_end.response)
end

get '/api/analyze/:field/terms/:hash' do
  limit   = KibanaConfig::Analyze_show
  req     = ClientRequest.new(params[:hash])
  fields = Array.new
  fields = params[:field].split(',,')
  query   = TermsFacet.new(req.search,req.from,req.to,fields)
  indices = Kelastic.index_range(req.from,req.to,KibanaConfig::Facet_index_limit)
  result  = KelasticMultiFlat.new(query,indices)

  # Not sure this is required. This should be able to be handled without
  # server communication
  result.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}

  JSON.generate(result.response)
end

get '/api/analyze/:field/score/:hash' do
  limit = KibanaConfig::Analyze_limit
  show  = KibanaConfig::Analyze_show
  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,req.from,req.to,0,limit)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)
  fields = Array.new
  fields = params[:field].split(',,')
  count   = KelasticResponse.count_field(result.response,fields)

  # Not sure this is required. This should be able to be handled without
  # server communication
  result.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}

  final = Array.new(0)
  count.each do |key, value|
    final << {
      :id    => key,
      :count => value,
    }
  end
  final = final.sort_by{ |hsh| hsh[:count].abs }.reverse

  result.response['hits']['count']  = result.response['hits']['hits'].length
  result.response['hits']['hits']   = final[0..(show - 1)]
  JSON.generate(result.response)
end

get '/api/analyze/:field/mean/:hash' do
  req     = ClientRequest.new(params[:hash])
  query   = StatsFacet.new(req.search,req.from,req.to,params[:field])
  indices = Kelastic.index_range(req.from,req.to,KibanaConfig::Facet_index_limit)
  type    = Kelastic.field_type(indices.first,params[:field])
  if ['long','integer','double','float'].include? type
    result  = KelasticMultiFlat.new(query,indices)

    # Not sure this is required. This should be able to be handled without
    # server communication
    result.response['kibana']['time'] = {
      "from" => req.from.iso8601, "to" => req.to.iso8601}

    JSON.generate(result.response)
  else
    JSON.generate({"error" => "Statistics not supported for type: #{type}"})
  end
end

get '/api/stream/:hash/?:from?' do
  # This is delayed by 10 seconds to account for indexing time and a small time
  # difference between us and the ES server.
  delay = 10

  # Calculate 'from'  and 'to' based on last event in stream.
  from = params[:from].nil? ? Time.now - (10 + delay) : Time.parse("#{params[:from]}+0:00")

  # ES's range filter is inclusive. delay-1 should give us the correct window. Maybe?
  to = Time.now - (delay)

  # Build and execute
  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,from,to,0,30)
  indices = Kelastic.index_range(from,to)
  result  = KelasticMulti.new(query,indices)
  output  = JSON.generate(result.response)

  if result.response['hits']['total'] > 0
    JSON.generate(result.response)
  end
end

get '/rss/:hash/?:count?' do
  # TODO: Make the count number above/below functional w/ hard limit setting
  count = KibanaConfig::Rss_show
  # count = params[:count].nil? ? 30 : params[:count].to_i
  span  = (60 * 60 * 24)
  from  = Time.now - span
  to    = Time.now

  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,from,to,0,count)
  indices = Kelastic.index_range(from,to)
  result  = KelasticMulti.new(query,indices)
  flat    = KelasticResponse.flatten_response(result.response,req.fields)

  headers "Content-Type"        => "application/rss+xml",
          "charset"             => "utf-8",
          "Content-Disposition" => "inline; filename=kibana_rss_#{Time.now.to_i}.xml"

  content = RSS::Maker.make('2.0') do |m|
    m.channel.title = "Kibana #{req.search}"
    m.channel.link  = "www.example.com"
    m.channel.description =
      "A event search for: #{req.search}.
      With title fields: #{req.fields.join(', ')} "
    m.items.do_sort = true

    result.response['hits']['hits'].each do |hit|
      i = m.items.new_item
      hash    = IdRequest.new(hit['_id'],hit['_index']).hash
      i.title = KelasticResponse.flatten_hit(hit,req.fields).join(', ')
      i.date  = Time.iso8601(KelasticResponse.get_field_value(hit,'@timestamp'))
      i.link  = link_to("/##{hash}")
      i.description = "<pre>#{hit.to_yaml}</pre>"
    end
  end
  content.to_s
end

get '/export/:hash/?:count?' do

  count = KibanaConfig::Export_show
  # TODO: Make the count number above/below functional w/ hard limit setting
  # count = params[:count].nil? ? 20000 : params[:count].to_i
  sep   = KibanaConfig::Export_delimiter

  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,req.from,req.to,0,count)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)
  flat    = KelasticResponse.flatten_response(result.response,req.fields)

  headers "Content-Disposition" => "attachment;filename=Kibana_#{Time.now.to_i}.csv",
    "Content-Type" => "application/octet-stream"

  if RUBY_VERSION < "1.9"
    FasterCSV.generate({:col_sep => sep}) do |file|
      file << req.fields
      flat.each { |row| file << row }
    end
  else
    CSV.generate({:col_sep => sep}) do |file|
      file << req.fields
      flat.each { |row| file << row }
    end
  end

end

get '/js/timezone.js' do
  erb :timezone
end
