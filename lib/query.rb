require 'rubygems'
require 'json'
require 'tzinfo'

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
          "default_operator" => KibanaConfig::Default_operator,
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
  def initialize(question, from, to, offset = 0, size = KibanaConfig::Per_page, field = "@timestamp", order = "desc")
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
= Class: HighlightedQuery < Query
  Sort results ascending or decending by a given field and highlight results

== Parameters:
  query::   The query text. Blank or * queries are converted to match_all
  from::    Beginning of time range
  to::      End of time range (Default: NOW)
  offset::  Offset from beginning of results
  field::   Field to sort on, be careful of fields with many unique values
  order::   desc/asc
=end
class HighlightedQuery < Query
  attr_accessor :query,:from,:to
  def initialize(question, from, to, offset = 0, size = KibanaConfig::Per_page, field = "@timestamp", order = "desc")
    super(question, from, to)
    @query['from'] = offset
    @query['size'] = size
    @query['sort'] = {
      field => {
        "order" => order
      }
    }
    @query['highlight'] = {
      "pre_tags" => [ "@KIBANA_HIGHLIGHT_START@" ],
      "post_tags" => [ "@KIBANA_HIGHLIGHT_END@" ],
      "fields" => { KibanaConfig::Highlighted_field => { "fragment_size" => 9999 } }
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
= Class: TermsFacet < Query
  Perform a terms facet query on a field

== Parameters:
  query::   The query text. Blank or * queries are converted to match_all
  from::    Beginning of time range
  to::      End of time range (Default: NOW)
  field::   Field to facet
=end
class TermsFacet < Query
  def initialize(question, from, to, field, limit = KibanaConfig::Analyze_show)
    super(question, from, to)
    if (field.kind_of?(Array) and field.length > 1)
        script = ''
        glue = ''
        field.each do |f|
          script = script + glue + "(doc['"+f+"'].value !=null ? doc['"+f+"'].value : '')"
          glue = "+'||'+"
        end
        @query['facets'] = {
          "terms" => {
            "terms" => {
              "script" => script,
              "size"  => limit
          }
        }
      }
    else
      @query['facets'] = {
        "terms" => {
          "terms" => {
            "field" => field,
            "size"  => limit
          }
        }
      }
   end
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

