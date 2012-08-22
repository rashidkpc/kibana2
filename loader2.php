<?php

if (!defined('KIBANA_CONFIG_FILE')) {
  // KIBANA_CONFIG_FILE is the path to the file that defines the
  // $KIBANA_CONFIG configuration array.
  // The default value will look for the file in the same directory as this
  // script.

  // allow overriding the config file via an environment variable.
  $config_path = getenv('KIBANA_CONFIG_FILE');
  if (empty($config_path)) {
    $config_path = dirname(__FILE__) . DIRECTORY_SEPARATOR . 'config.php';
  }

  define('KIBANA_CONFIG_FILE', $config_path);
}
require_once KIBANA_CONFIG_FILE;

/**
 * Handle requests for Logstash data via JSON requests.
 *
 * @author Rashid Khan <rashidkpc #logstash irc.freenode.net>
 * @copyright Copyright 2011 Rashid Khan
 * @license BSD 2 Clause <http://www.opensource.org/licenses/BSD-2-Clause>
 */
class LogstashLoader {

  /**
   * Configuration data.
   * @var array
   */
  protected $config;

  /**
   * Index(es) to select from.
   *
   * When config['smart_index'] is true we will try to guess the exact index
   * paritions to search. If this list turns out to be longer than
   * config['smart_index_limit'] or if smart index is disabled we will
   * search using config['default_index'] instead.
   *
   * @var string
   */
  protected $index;


  /**
   * Constructor.
   * @param array $config Configuration data
   */
  public function __construct ($config = array()) {
    $this->config = $config;
    $this->index = $config['default_index'];
    $this->indexSuffix = $config['index_suffix'];
  }


  /**
   * Handle a request.
   * @return void
   */
  public function handleRequest () {
    $req = $this->collectInput();
    if ($req) {

      if($req->mode == 'getindices') {
        $result = $this->getAllIndices();
        $indexNames = array();
        foreach($result as $index) {
            $indexParts = explode("-", $index);
            if(!empty($this->indexSuffix)) {
                if(count($indexParts) == 3 && strpos($this->indexSuffix, $indexParts[2]) !== FALSE) {
                    if(empty($this->index) || ($this->index == $indexParts[0]))
                        $indexNames[] = $indexParts[0];
                }
            }
            else if(count($indexParts) == 2)
                if(empty($this->index) || ($this->index == $indexParts[0]))
                    $indexNames[] = $indexParts[0];
        }
        $return = array_values(array_unique($indexNames));
        sort($return);
      }
      else {
        $req->fields = array_filter($req->fields);
        $query = $this->buildQuery($req);
        if(!$this->index) $return = array();
        else $return = $this->processQuery($req, $query);
      }


      switch ($req->mode) {
        case 'csv':
          header('Content-type: application/ms-excel');
          header('Content-Disposition: attachment; filename=kibana_'.
            implode('_',$req->fields).'-'.time().'.csv');
          echo  $this->csvFeed($req, $query, $return);
          break;
        case 'rss':
          echo  $this->rssFeed($req, $query, $return);
          break;
        default:
          echo  json_encode($return);
      }
    } else {
      echo "No Page parameter";
    }
  } //end handleRequest


  /**
   * Get the request data.
   * @return object Request or false if none available
   */
  protected function collectInput () {
    $req = false;
    if (isset($_GET['page'])) {
      // XXX: validation and/or error trapping?
      $base64 = strtr($_GET['page'], '-_', '+/');
      $req = json_decode(base64_decode($base64));

      // make sure default keys are populated
      foreach ($this->config['default_search'] as $key => $default) {
        if (!isset($req->{$key})) {
          $req->{$key} = $default;
        }
      }
      $req->segment = isset($_GET['segment'])? $_GET['segment']: '';
      $req->mode = isset($_GET['mode'])? $_GET['mode']: '';
      $req->interval = (isset($_GET['interval']))?
        self::roundInterval($_GET['interval']): 600000;

    }
    else if($_GET['getindices']) {
        $req = new stdClass();
        $req->mode = 'getindices';
    }
    return $req;
  } //end collectInput


  /**
   * Build an Elastic Search query for the given request.
   *
   * @param object $req Request data
   * @return object ES query
   */
  protected function buildQuery ($req) {
    // Preparse parameters
    $time = $req->time;
    $this->index = implode(",", $req->index);

    // Contruct the query
    $query = new stdClass;
    $query->from = $req->offset;

    $filter_string = ($this->config['filter_string'] == "")?
        "":" AND ".$this->config['filter_string'];

    /** 
     * This will prevent extremely slow queries from running because of 
     * wildcard search terms.
     *
     * See: http://www.elasticsearch.org/guide/reference/query-dsl/wildcard-query.html
     */
    if ($this->config['disable_fullscan']) {
      $sanitized_search = "";
      $search = $req->search;
      $last_char = "";
      for ($i=0; $i < strlen($search); $i++) {
        if ($search[$i] == "*" || $search[$i] == "?") {
	  /**
	   * if the wildcard isn't at the beginning of the term (not first 
	   * character in search, not preceded by whitespace, not first
	   * character after a query component), then add it to the list 
           */
          $bad_chars = array('(', ':', '"', '\'', ' ', '\t', ',');
          if ($last_char != "" && !in_array($last_char, $bad_chars)) {
            $sanitized_search .= $search[$i];
            $last_char = $search[$i];
          }
        } else {
            $sanitized_search .= $search[$i];
            $last_char = $search[$i];
        }
      }
      $req->search = $sanitized_search;
    }

    $query->query->filtered->query->query_string->query =
        ($req->search == "")? "*" . $filter_string:
        "(".$req->search.")" . $filter_string;
    $query->query->filtered->query->query_string->default_field =
        $this->config['primary_field'];

    $query->query->filtered->query->query_string->default_operator =
        $this->config['default_operator'];

    if ($query->query->filtered->query->query_string->query == "*") {
      unset($query->query->filtered->query);
      $query->query->filtered->query->match_all = new StdClass;
    }

    $query->size = $this->config['results_per_page'];
    $query->sort->{'@timestamp'}->order = 'desc';

    // Unless the user gives us exact times, compute relative
    // timeframe based on drop down
    if ($req->timeframe != "custom") {
      $time = new stdClass;
      if($req->timeframe == 'all') {
        $time->from = date('c', strtotime("100 years ago"));
      } else {
        $time->from = date('c', strtotime("{$req->timeframe} ago"));
      }
      $time->to = date('c');
    }

    $req->time = $time;

    // Check if we have a time range, if so filter
    if ($time != '') {
      $query->query->filtered->filter->range->{'@timestamp'} = $time;
      // Figure out which indices to search
      if ($this->config['smart_index']) {
        $this->index_array = $this->getIndicesByTime(
            $time->from, $time->to);
        $this->index = implode(',', $this->index_array);
      }
    }

    // Check the mode
    switch ($req->mode) {
      case 'countgraph':
        unset($query->sort);
        $query->size = 0;
        $query->facets->histo1->date_histogram->field =
          "@timestamp";
        $query->facets->histo1->date_histogram->interval =
          $req->interval;
        break;
      case 'meangraph':
        unset($query->sort);
        $query->size = 0;
        $query->facets->histo1->date_histogram->key_field =
          "@timestamp";
        $query->facets->histo1->date_histogram->value_field =
          $req->analyze_field;
        $query->facets->histo1->date_histogram->interval =
          $req->interval;
        break;
      case 'trend':
      case 'analyze':
        $query->size = $this->config['analyze_limit'];
        $query->fields = self::canonicalFieldName($req->analyze_field); 
        break;
      case 'mean':
        unset($query->sort);
        $query->size = 0;
        $query->facets->statistics->statistical->field = $req->analyze_field;
        break;
      case 'rss':
        $query->size = $this->config['rss_show'];
        $query->query = $query->query->filtered->query;
        unset($query->facets);
        break;
      case 'csv':
        $query->size = $this->config['export_show'];
        unset($query->facets);
        break;
      case 'stream':
        $query->size = 15;
        unset($query->facets);
        break;
      default:
    }

    return $query;
  } //end buildQuery


  /**
   * Process a query.
   *
   * @param object $req Request data
   * @param object $query ES query
   * @return object Response to request
   */
  protected function processQuery ($req, $query) {
    // After this, dates are in local timezone
    date_default_timezone_set($this->config['local_timezone']);

    // build the response
    $return = new stdClass;

    //Store original query size to slice with
    $slice = $query->size;

    // Run the query
    if (strpos($req->mode,'graph') !== false) {
      $index_array = explode(',',$this->index);
      if(sizeof($index_array) > 1) {
        if($req->segment == '') {
          $this->index  = $index_array[0];
          $return->next = 1;
        } else {
          $this->index = $index_array[$req->segment];
          if(sizeof($index_array) > $req->segment+1) {
            $return->next = $req->segment + 1;
          }
        }
      }
      $return->graph->interval = $req->interval;
    } else {
      $return->graph->interval =
        (strtotime($req->time->to) - strtotime($req->time->from)) * 10;
    }

    if($req->mode != 'mean' && strpos($req->mode,'graph') === false) {
      $index_array = explode(',',$this->index);
      $this->index = $index_array[0];
      $result = $this->esQuery($query);
      $return->hits = $result->hits->total;
      $i = 1;
      while($return->hits <= ($req->offset + $slice) 
        && $i < sizeof($index_array)) 
      {
        $query->size = $slice - sizeof($result->hits->hits);
        if(($query->size - $req->offset) < 0) {
          $query->from = 0;
        }
        if ($req->offset > $return->hits) {
          $query->from = $req->offset - $return->hits;
        }
        $this->index = $index_array[$i];
        $result_tmp = $this->esQuery($query);
        $return->hits = $return->hits + $result_tmp->hits->total;
        $result->hits->hits = array_merge(
          $result->hits->hits,$result_tmp->hits->hits);
        $i++;
      }
    } else {
      $result = $this->esQuery($query);
      $return->hits = $result->hits->total;
    }

    // Add some top level statistical and informational data
    $return->indices  = $this->index;
    $return->time     = $req->time;
    $return->total    = $this->esTotalDocumentCount();

    if (isset($result->facets->histo1)) {
      $return->graph->data = $result->facets->histo1->entries;
    }

    switch ($req->mode) {
      case 'analyze':
        $result->hits->hits = array_slice($result->hits->hits, 0, $slice);
        $return = $this->analyzeField($req, $query, $return, $result);
        break;

      case 'trend':
        $result->hits->hits = array_slice($result->hits->hits, 0, $slice);
        $return = $this->trendField($req, $query, $return, $result);
        break;

      case 'mean':
        $return->analysis->results = $result->facets->statistics;
        break;

      default:
        $result->hits->hits = array_slice($result->hits->hits, 0, $slice);
        $base_fields = array_values(array_unique(array_merge(
          array('@message'),
          $this->config['default_fields'])));
        $return->all_fields = array_values(array_unique(array_merge(
          array('@message'),
          $this->config['default_fields'])));
        $return->page_count = count($result->hits->hits);
        $i=0;
        foreach ($result->hits->hits as $hitkey => $hit) {
          $i++;
          $hit_id = $hit->{'_id'};
          $hit->fields = $hit->{'_source'};
          $return->results[$hit_id]['@cabin_time'] =
              date('m/d H:i:s', strtotime(
                  $hit->fields->{'@timestamp'}));
          $return->results[$hit_id]['@timestamp'] =
              $hit->fields->{'@timestamp'};
          foreach ($hit->fields->{'@fields'} as $name => $value) {
            if (is_array($value))
              $value = implode(',',$value);
            $return->results[$hit_id][$name] = $value;
            if (!in_array($name, $return->all_fields)) {
              $return->all_fields[] = $name;
            }
          }

          foreach ($base_fields as $field) {
            $return->results[$hit_id][$field] =
              $hit->fields->{$field};
          }
          unset($result->hits->hits[$i]);
        }
        //sort($return->all_fields);
    }
    if (sizeof($req->fields) == 0) $req->fields = array('@message');
    $return->fields_requested = $req->fields;
    $return->elasticsearch_json = json_encode($query);

    // Insert meta data for javascript
    $return->meta->per_page = $this->config['results_per_page'];

    unset($result);
    return $return;
  } //end processQuery


  /**
   * Create an RSS feed from a set of results.
   *
   * @param object $req Request data
   * @param object $query ES query
   * @param object $return Partial response
   * @return object Response to request
   */
  protected function rssFeed ($req, $query, $return) {

    if (sizeof($req->fields) < 1)
      $req->fields = array('@message');

    $pDom = new DOMDocument();

    $pRSS = $pDom->createElement('rss');

    $pRSS->setAttribute('version', 0.91);
    $pDom->appendChild($pRSS);

    $pChannel = $pDom->createElement('channel');
    $pRSS->appendChild($pChannel);


    $e_query = $req->search;

    $pTitle = $pDom->createElement('title');
    $pLink = $pDom->createElement('link');
    $pDesc = $pDom->createElement('description');
    $pLang = $pDom->createElement('language');

    $pTitleText = $pDom->createTextNode(
      'Kibana: '.$e_query);
    $pLinkText  = $pDom->createTextNode(
      'http://' . $_SERVER['HTTP_HOST'] .
      dirname($_SERVER['REQUEST_URI']) . '/#'.
      base64_encode(json_encode($req)));
    $pDescText = $pDom->createTextNode(
      'An event search for: '.$e_query.
      '. Showing fields '.
      implode(', ',array_filter($req->fields)) . " in the title.");
    $pLangText = $pDom->createTextNode('en');

    $pTitle->appendChild($pTitleText);
    $pLink->appendChild($pLinkText);
    $pDesc->appendChild($pDescText);
    $pLang->appendChild($pLangText);

    $pChannel->appendChild($pTitle);
    $pChannel->appendChild($pLink);
    $pChannel->appendChild($pDesc);
    $pChannel->appendChild($pLang);

    foreach ($return->results as $result) {
      $pItem  = $pDom->createElement('item');
      $a_pTitle = array();
      foreach ($req->fields as $field) {
        if (is_array($result[$field])) {
          $a_pTitle[] .= implode(',',$result[$field]);
        } else {
          $a_pTitle[] .= $result[$field];
        }
      }

      $pTitle = $pDom->createElement('title');
      $pLink  = $pDom->createElement('pubDate',
        date('r',strtotime($result['@timestamp'])));
      $pDesc  = $pDom->createElement('description');

      $pTitleText = $pDom->createTextNode(implode(', ',$a_pTitle));
      $pDescText  = $pDom->createTextNode($result['@message']);

      $pTitle->appendChild($pTitleText);
      $pDesc->appendChild($pDescText);

      $pItem->appendChild($pTitle);
      $pItem->appendChild($pLink);
      $pItem->appendChild($pDesc);

      $pChannel->appendChild($pItem);
    }

    return $pDom->saveXML();
  } //end rssFeed

  /**
   * Create a CSV file from a set of results.
   *
   * @param object $req Request data
   * @param object $query ES query
   * @param object $return Partial response
   * @return object Response to request
   */
  protected function csvFeed ($req, $query, $return) {

    if (sizeof($req->fields) < 1)
      $req->fields = array('@message');

    $e_query = $req->search;

    $csv = array(
      'timestamp'.$this->config['export_delimiter'].
      implode($this->config['export_delimiter'],$req->fields));

    foreach ($return->results as $result) {
      $csv_line = array();
      array_push($csv_line,
        date('Y-m-d H:i:s',strtotime($result['@timestamp'])));
      foreach ($req->fields as $field) {
        if (is_array($result[$field])) {
          array_push($csv_line,implode('+',$result[$field]));
        } else {
          array_push($csv_line,$result[$field]);
        }
      }
      array_push($csv,
        implode($this->config['export_delimiter'],$csv_line));
      unset($csv_line);
    }

    return implode("\n",$csv);
  } //end csvFeed


  /**
   * Analyze a field from a set of results.
   *
   * @param object $req Request data
   * @param object $query ES query
   * @param object $return Partial response
   * @return object Response to request
   */
  protected function analyzeField ($req, $query, $return, $result) {
    $field = self::canonicalFieldName($req->analyze_field);
    $return->analysis->count = count($result->hits->hits);

    $analyze = self::collectFieldValues($result->hits->hits, $field);
    unset($result);

    $analyze = array_count_values($analyze);
    arsort($analyze);
    $analyze = array_slice(
        $analyze, 0, $this->config['analyze_show'], true);

    $final = array();
    foreach ($analyze as $key => $value) {
      $final[$key] = array();
      $final[$key]['count'] = $value;
    }

    $return->analysis->results = $final;

    return $return;
  } //end analyzeField

  /**
   * Compute trends in the values of a field.
   *
   * @param object $req Request data
   * @param object $query ES query
   * @param object $return Partial response
   * @return object Response to request
   */
  protected function trendField ($req, $query, $return, $result) {
    $field = self::canonicalFieldName($req->analyze_field);

    // Scale samples. If analyze_limit is more than 50% of the
    // results, then change size to 50% of the results to avoid
    // overlap
    $analyze_limit = $this->config['analyze_limit'];
    $query->size = $analyze_limit;
    if ($return->hits < $analyze_limit * 2) {
      $query->size = $return->hits / 2;
    }

    $result = $this->esQuery($query);
    $analyze = self::collectFieldValues($result->hits->hits, $field);
    unset($result);
    $analyze = array_count_values($analyze);

    $query->sort->{'@timestamp'}->order = 'asc';
    $result = $this->esQuery($query);
    $return->analysis->count = count($result->hits->hits);
    $analyze2 = self::collectFieldValues($result->hits->hits, $field);
    unset($result);
    $analyze2 = array_count_values($analyze2);

    $final = array();
    foreach ($analyze as $key => $value) {
      $first = isset($analyze2[$key]) ? $analyze2[$key] : 0;
      $final[$key] = array();
      $final[$key]['count'] = $value;
      $final[$key]['start'] = $first;
      $final[$key]['trend'] = round((($value / $query->size) -
        ($first / $query->size)) * 100, 2);
      $final[$key]['abs'] = abs($final[$key]['trend']);
    }

    aasort($final, "abs");

    $final = array_slice($final, 0, $this->config['analyze_show'], true);
    $return->analysis->results = $final;

    return $return;
  } //end trendField


  /**
   * Query Elastic Search.
   *
   * @param object $query Search API query
   * @return object ES response
   */
  function esQuery ($query) {
    $ch = curl_init();
    $data = json_encode($query);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, 1);
    if ($this->config['type'] != "") {
      $url = "http://" . $this->config['elasticsearch_server'] .
        "/{$this->index}/{$this->config['type']}".
        "/_search?search_type=query_then_fetch";
    } else {
      $url = "http://" . $this->config['elasticsearch_server'] .
        "/{$this->index}/_search?search_type=query_then_fetch";
    }
    curl_setopt($ch, CURLOPT_URL, $url);    
  curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
    $response = curl_exec($ch);
    $return = json_decode($response);
    unset($response);
    return $return;
  } //end esQuery


  /**
   * Query Elastic Search for the total number of documents indexed.
   * @return int Total document count
   */
  function esTotalDocumentCount () {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_URL,
        "http://{$this->config['elasticsearch_server']}/_status");
    $result = json_decode(curl_exec($ch));

    $indices = $result->indices;
    $totaldocs = 0;
    foreach ($indices as $index) {
        $totaldocs += $index->docs->num_docs;
    }
    return $totaldocs;
  } //end esTotalDocumentCount

  /**
   * Get a list of all indices that fall within the given time range.
   *
   * @param string $strDateFrom Range start date
   * @param string $strDateTo Range end date
   * @return array List of index names that should be queried
   */
  protected function getIndicesByTime ($strDateFrom, $strDateTo) {
    // Dates in this section are UTC
    $save_tz = date_default_timezone_get();
    date_default_timezone_set('UTC');
    $aryRange = array();
    $iDateFrom = strtotime(date("F j, Y", strtotime($strDateFrom)));
    $iDateTo = strtotime(date("F j, Y", strtotime($strDateTo)));
    $indices = explode(",", $this->index);
    foreach($indices as $index) {
        if ($iDateTo >= $iDateFrom) {
            $aryRange[] = $index . '-' . date('Y.m.d', $iDateFrom) . $this->indexSuffix;
            while ($iDateFrom < $iDateTo) {
                $iDateFrom += 86400;
                if ($iDateTo >= $iDateFrom) {
                    $aryRange[] = $index . '-' . date('Y.m.d', $iDateFrom) . $this->indexSuffix;
                }
            }
        }
    }

    $aryRange = array_intersect($aryRange, $this->getAllIndices());
    if (count($aryRange) > $this->config['smart_index_limit']) {
      $aryRange = array('_all');
    }
    rsort($aryRange);

    // back to default timezone
    date_default_timezone_set($save_tz);
    return $aryRange;
  } //end getIndicesByTime


  /**
   * Query ElastciSearch server to get a list of all indexes available for
   * searching.
   *
   * @return array List of index names
   */
  protected function getAllIndices () {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_URL,
        "http://{$this->config['elasticsearch_server']}/_status");
    $result = json_decode(curl_exec($ch));
    $indices = array();
    foreach ($result->indices as $indexname => $index) {
      $indices[] = $indexname;
    }
    return $indices;
  } //end getAllIndices


  /**
   * Round an interval value.
   *
   * @param int $int Interval
   * @return int Rounded interval
   */
  public static function roundInterval ($int) {
    switch ($int) {
      case ($int <= 500):   return 100;
      case ($int <= 5000):  return 1000;
      case ($int <= 7500):  return 5000;
      case ($int <= 15000):   return 10000;
      case ($int <= 45000):   return 30000;
      case ($int <= 180000):  return 60000;
      case ($int <= 450000):  return 300000;
      case ($int <= 1200000): return 600000;
      case ($int <= 2700000): return 1800000;
      default:        return 3600000;
    }
  } //end roundInterval


  /**
   * Construct the canonical name of a given field.
   *
   * Fields that don't start with '@' are actually subfields of the
   * '@fields' collection.
   *
   * @param string $name Field name
   * @return string Canonical field name
   */
  public static function canonicalFieldName ($name) {
    return ('@' == $name[0]) ? $name : "@fields.{$name}";
  }


  /**
   * Collect all values of a given field from a collection of documents.
   *
   * @param array $documents ES documents
   * @param string $field Field to extract
   * @return array List of field values
   */
  public static function collectFieldValues ($documents, $field) {
    $values = array();
    foreach ($documents as $doc) {
      if (isset($doc->fields)) {
        $value = $doc->fields->{$field};
        if (is_array($value)) {
          $value = implode(',', $value);
        }
        $values[] = $value;
      }
    }
    return $values;
  } //end collectFieldValues


} //end LogstashLoader

function aasort (&$array, $key) {
  $sorter = array();
  $ret = array();
  reset($array);
  foreach ($array as $ii => $va) {
    $sorter[$ii] = $va[$key];
  }
  arsort($sorter);
  foreach ($sorter as $ii => $va) {
    $ret[$ii] = $array[$ii];
  }
  $array = $ret;
}

$handler = new LogstashLoader($KIBANA_CONFIG);
$handler->handleRequest();

// vim:sw=2 ts=2 sts=2 et :
