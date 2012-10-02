require 'rubygems'
require 'sinatra'
require 'json'
require 'time'
require 'date'
require 'rss/maker'
require 'yaml'
require 'tzinfo'
require 'rpam'

include Rpam

$LOAD_PATH << '.'
$LOAD_PATH << './lib'

require 'KibanaConfig'
Dir['./lib/*.rb'].each{ |f| require f }

ruby_18 { require 'fastercsv' }
ruby_19 { require 'csv' }

configure do
  set :bind, defined?(KibanaConfig::KibanaHost) ? KibanaConfig::KibanaHost : '0.0.0.0'
  set :port, KibanaConfig::KibanaPort
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions

  @@auth_module = nil
  begin
    if KibanaConfig::Auth_module != ""
      require "./lib/modules/auth_#{KibanaConfig::Auth_module}"
      @@auth_module = get_auth_module(KibanaConfig)
    end
  rescue
    puts "Failed to load the auth module: #{KibanaConfig::Auth_module}"
  end

  @@storage_module = nil
  begin
    require "./lib/modules/storage_#{KibanaConfig::Storage_module}"
    @@storage_module = get_storage_module(KibanaConfig)
  rescue
    puts "Failed to load the storage module: #{KibanaConfig::Storage_module}"
  end
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

before do
  if @@auth_module
    unless session[:username]
      if request.path.start_with?("/api")
        # ajax api call, just return an error
        halt 401, JSON.generate({"error" => "Not logged in"})
      elsif !request.path.start_with?("/auth")
        # normal web call, redirect to login
        halt redirect '/auth/login'
      end
    else
      @user_perms = @@storage_module.get_permissions(session[:username])
      if !@user_perms
        # User is authenticated, but not authorized. Put them in 
        # a holding state until an admin grants them authorization
        if request.path.start_with?("/api")
          halt 401, JSON.generate({"error" => "Not authorized for any security groups"})
        elsif !request.path.start_with?("/auth/logout")
          halt 401, "You are not authorized for any search groups. Please contact the kibana administrator to grant you permission."
        end
      else
        if !(defined? @user_perms[:is_admin])
          @user_perms[:is_admin] = false
        end
        if request.path.start_with?("/auth/admin")
          # only admins get to go here
          if !@user_perms[:is_admin]
            halt 401, "You are not authorized to be here"
          end
        end
      end
    end
  end
end

get '/' do
  locals = {}
  if @@auth_module 
    locals[:username] = session[:username]
    locals[:is_admin] = @user_perms[:is_admin]
  end
  erb :index, :locals => locals
end

get '/stream' do
  send_file File.join(settings.public_folder, 'stream.html')
end

get '/auth/login' do
  locals = {}
  if !@@auth_module
    redirect '/'
  end
  if session[:login_message]
    locals[:login_message] = session[:login_message]
  end
  erb :login, :locals => locals
end

post '/auth/login' do
  if !@@auth_module
    redirect '/'
  end
  username = params[:username]
  password = params[:password]
  if @@auth_module.authenticate(username,password)
    session[:username] = username
    session[:login_message] = ""
    redirect '/'
  else
    session[:login_message] = "Invalid username or password"
    halt redirect '/auth/login'
  end
end

get '/auth/logout' do
  if !@@auth_module
    redirect '/'
  end
  session[:username] = nil
  session[:login_message] = "Successfully logged out"
  redirect '/auth/login'
end

# User/permission administration
get '/auth/admin' do
  locals = {}
  if @@auth_module
    locals[:username] = session[:username]
    locals[:is_admin] = @user_perms[:is_admin]
    locals[:show_back] = true

    locals[:users] = [ @user_perms ]
  end
  erb :admin, :locals => locals
end

get '/auth/admin/:username' do
  locals = {}
  if @@auth_module
    locals[:username] = session[:username]
    locals[:is_admin] = @user_perms[:is_admin]
    locals[:show_back] = true
    
    locals[:user_data] = @@storage_module.get_permissions(params[:username])
  end
  erb :adminedit, :locals => locals
end

post '/auth/admin/save' do
  redirect '/auth/admin'
end

# Returns
get '/api/search/:hash' do
  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,@user_perms,req.from,req.to,req.offset)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)

  # Not sure this is required. This should be able to be handled without
  # server communication
  result.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}
  result.response['kibana']['default_fields'] = KibanaConfig::Default_fields

  JSON.generate(result.response)
end

get '/api/graph/:mode/:interval/:hash/?:segment?' do
  segment = params[:segment].nil? ? 0 : params[:segment].to_i

  req     = ClientRequest.new(params[:hash])
  case params[:mode]
  when "count"
    query   = DateHistogram.new(req.search,@user_perms,req.from,req.to,params[:interval].to_i)
  when "mean"
    query   = StatsHistogram.new(req.search,@user_perms,req.from,req.to,req.analyze,params[:interval].to_i)
  end
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticSegment.new(query,indices,segment)

  JSON.generate(result.response)
end

get '/api/id/:id/:index' do
  ## TODO: Make this verify that the index matches the smart index pattern.
  id      = params[:id]
  index   = "#{params[:index]}"
  query   = IDQuery.new(id,@user_perms)
  result  = Kelastic.new(query,index)
  JSON.generate(result.response)
end

get '/api/analyze/:field/trend/:hash' do
  limit = KibanaConfig::Analyze_limit
  show  = KibanaConfig::Analyze_show
  req           = ClientRequest.new(params[:hash])

  query_end     = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit,'@timestamp','desc')
  indices_end   = Kelastic.index_range(req.from,req.to)
  result_end    = KelasticMulti.new(query_end,indices_end)

  # Oh snaps. too few results for full limit analysis, rerun with less
  if (result_end.response['hits']['hits'].length < limit)
    limit         = (result_end.response['hits']['hits'].length / 2).to_i
    query_end     = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit,'@timestamp','desc')
    indices_end   = Kelastic.index_range(req.from,req.to)
    result_end    = KelasticMulti.new(query_end,indices_end)
  end

  count_end     = KelasticResponse.count_field(result_end.response,params[:field])

  query_begin   = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit,'@timestamp','asc')
  indices_begin = Kelastic.index_range(req.from,req.to).reverse
  result_begin  = KelasticMulti.new(query_begin,indices_begin)
  count_begin   = KelasticResponse.count_field(result_begin.response,params[:field])



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

get '/api/analyze/:field/score/:hash' do
  limit = KibanaConfig::Analyze_limit
  show  = KibanaConfig::Analyze_show
  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)
  count   = KelasticResponse.count_field(result.response,params[:field])

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
  indices = Kelastic.index_range(req.from,req.to)
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
  query   = SortedQuery.new(req.search,@user_perms,from,to,0,30)
  result  = Kelastic.new(query,Kelastic.current_index)
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
  query   = SortedQuery.new(req.search,@user_perms,from,to,0,count)
  indices = Kelastic.index_range(from,to)
  result  = KelasticMulti.new(query,indices)
  flat    = KelasticResponse.flatten_response(result.response,req.fields)

  content = RSS::Maker.make('2.0') do |m|
    m.channel.title = "Kibana #{req.search}"
    m.channel.link  = "www.example.com"
    m.channel.description =
      "A event search for: #{req.search}.
      With title fields: #{req.fields.join(', ')} "
    m.items.do_sort = true

    result.response['hits']['hits'].each do |hit|
      i = m.items.new_item
      hash    = IDRequest.new(hit['_id'],hit['_index']).hash
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
  query   = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,count)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)
  flat    = KelasticResponse.flatten_response(result.response,req.fields)

  headers "Content-Disposition" => "attachment;filename=Kibana_#{Time.now.to_i}.csv",
    "Content-Type" => "application/octet-stream"

  if RUBY_VERSION < "1.9"
    FasterCSV.generate({:col_sep => sep}) do |file|
      flat.each { |row| file << row }
    end
  else
    CSV.generate({:col_sep => sep}) do |file|
      flat.each { |row| file << row }
    end
  end

end

get '/js/timezone.js' do
  erb :timezone
end
