require 'rubygems'
require 'json'
require 'KibanaConfig.rb'

=begin
= Class: Query
  A basic query contains only the data needed to get results, without any
  sorting or facets. Every query should share this. Maybe.

  Ideally you'll append to this
== Parameters:
  query::   The query text. Blank or * queries are converted to match_all
  from::    Beginning of time range (Time object)
  to::      End of time range (Default: NOW) (Time object)
=end
class Query
  attr_accessor :query,:from,:to
  def initialize(question, from = nil, to = nil)
    # Build query part of the filtered query
    question = question == "" ? "*" : question
    question = KibanaConfig::Filter == "" ?
      question : "(#{question}) AND #{KibanaConfig::Filter}"

    if (question == "*")
      @question = { "match_all" => {}}
    else
      @question = {
        "query_string" => {
          "default_field" => KibanaConfig::Primary_field,
          "query" => question
        }
      }
    end

    from = from.nil? ? nil : from.iso8601
    to = to.nil? ? nil : to.iso8601

    # Build the filter part
    @filter = {
      "range" => {
        "@timestamp" => {
          "from" => from,
          "to" => to
        }
      }
    }

    # Put it all together
    @query = {
      "size"  => 0,
      "query" => {
        "filtered" => {
          "query" => @question,
          "filter" => @filter
        }
      }
    }
  end

  def to_s
    JSON.pretty_generate(@query)
  end

end

=begin
= Class: IDQuery < Query
  Create a query that only returns 1 record for a single ID

== Parameters:
  id::  ID of the record to search for
=end
class IDQuery < Query
  attr_accessor :query
  def initialize(id)
    question = "_id:\"#{id}\""
    super(question)
    @query['size'] = 1
  end
end

=begin
= Class: SortedQuery < Query
  Sort results ascending or decending by a given field

== Parameters:
  query::   The query text. Blank or * queries are converted to match_all
  from::    Beginning of time range
  to::      End of time range (Default: NOW)
  offset::  Offset from beginning of results
  field::   Field to sort on, be careful of fields with many unique values
  order::   desc/asc
=end
class SortedQuery < Query
  attr_accessor :query,:from,:to
  def initialize(question, from, to, offset = 0, size = 50, field = "@timestamp", order = "desc")
    super(question, from, to)
    @query['from'] = offset
    @query['size'] = size
    @query['sort'] = {
      field => {
        "order" => order
      }
    }
  end
end

=begin
= Class: SortedQuery < Query
  Sort results ascending or decending by a given field

== Parameters:
  query::   The query text. Blank or * queries are converted to match_all
  from::    Beginning of time range
  to::      End of time range (Default: NOW)
  field::   Field to sort on, be careful of fields with many unique values
  order::   desc/asc
=end
class DateHistogram < Query
  def initialize(question, from, to, interval, field = '@timestamp')
    super(question, from, to)
    @query['facets'] = {
      "count" => {
        "date_histogram" => {
          "field" => field,
          "interval" => interval
        }
      }
    }
  end
end

=begin
= Class: StatsFacet < Query
  Perform statistical analysis on a field

== Parameters:
  query::   The query text. Blank or * queries are converted to match_all
  from::    Beginning of time range
  to::      End of time range (Default: NOW)
  field::   Field to analyze
=end
class StatsFacet < Query
  def initialize(question, from, to, field)
    super(question, from, to)
    @query['facets'] = {
      "stats" => {
        "statistical" => {
          "field" => field,
        }
      }
    }
  end
end

=begin
= Class: StatsHistogram < Query
  Perform statistical analysis on a field

== Parameters:
  query::   The query text. Blank or * queries are converted to match_all
  from::    Beginning of time range
  to::      End of time range (Default: NOW)
  field::   Field to analyze
=end
class StatsHistogram < Query
  def initialize(question, from, to, field, interval, key_field = '@timestamp')
    super(question, from, to)
    @query['facets'] = {
      "mean" => {
        "date_histogram" => {
          "value_field" => field,
          "key_field" => key_field,
          "interval" => interval
        }
      }
    }
  end
end

