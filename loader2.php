<?php
include 'config.php';

/**
 * Handle requests for Logstash data via JSON requests.
 *
 * @author Rashid Khan <flipwork #logstash irc.freenode.net>
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
     * _all is used by default.
     * @var string
     */
    protected $index = '_all';


    /**
     * Constructor.
     * @param array $config Configuration data
     */
    public function __construct ($config = array()) {
        $this->config = $config;
    }


    /**
     * Handle a request.
     * @return void
     */
    public function handleRequest () {
        $req = $this->collectInput();
        if ($req) {
            $query = $this->buildQuery($req);
            $return = $this->processQuery($req, $query);
            echo  json_encode($return);

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
        if ($_GET['page']) {
            // XXX: validation and/or error trapping?
            $base64 = strtr($_GET['page'], '-_', '+/');
            $req = json_decode(base64_decode($base64));

            // make sure default keys are populated
            foreach ($this->config['default_search'] as $key => $default) {
                if (!isset($req->{$key})) {
                    $req->{$key} = $default;
                }
            }

            $req->mode = isset($_GET['mode'])? $_GET['mode']: '';
            $req->interval = (isset($_GET['interval']))?
                    self::roundInterval($_GET['interval']): 600000;

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

        // Contruct the query
        $query = new stdClass;
        $query->from = $req->offset;
        $query->query->filtered->query->query_string->query =
                ($req->search == "")? "*": $req->search;
        $query->size = 50;
        $query->sort->{'@timestamp'}->order = 'desc';
        $query->fields = array(
                '@timestamp', '@fields', '@message', '@tags', '@type');

        // Check the mode
        switch ($req->mode) {
            case 'graph':
                $query->size = 0;
                $query->facets->histo1->date_histogram->field =
                        "@timestamp";
                $query->facets->histo1->date_histogram->interval =
                        $req->interval;
                break;

            case 'trend':
            case 'analyze':
                $query->facets->stats->statistical->field = '@timestamp';
                break;

            default:
                $query->facets->stats->statistical->field = '@timestamp';
        }

        // Unless the user gives us exact times, compute relative 
        // timeframe based on drop down
        if ($req->timeframe != "custom") {
            $time = new stdClass;
            $time->from = date('c', strtotime("{$req->timeframe} ago"));
            $time->to = date('c');
        }

        // Check if we have a time range, if so filter
        if ($time != '') {
            $query->query->filtered->filter->range->{'@timestamp'} = $time;
            $facet = ($req->mode == 'graph') ? "histo1" : "stats";

            // Figure out which indices to search
            if ($this->config['smart_index']) {
                $index_array = $this->getIndicesByTime(
                        $time->from, $time->to);
                $this->index = implode(',', $index_array);

                // Ignore all the cursor stuff for now. Its for eventual 
                // segmented loading
                $cursor = isset($req->cursor) ?
                        $req->cursor : sizeof($index_array);
                // FIXME: obviously won't work from here now.
                //$return->cursor = $cursor;
            }
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

        // Run the query
        $result = $this->esQuery($query);

        // build the response
        $return = new stdClass;

        // Add some top level statistical and informational data
        $return->index = $this->index;
        $return->hits = $result->hits->total;
        if (isset($result->facets->histo1)) {
            $return->graph->data = $result->facets->histo1->entries;
        }
        $return->total = $this->esTotalDocumentCount();

        if ($req->mode == 'graph') {
            $return->graph->interval = $req->interval;

        } else {
            // Compute an interval to give us around 100 bars
            $return->graph->interval = ($result->facets->stats->max -
                    $result->facets->stats->min) / 100;
        }

        switch ($req->mode) {
            case 'analyze':
                $return = $this->analyzeField($req, $query, $return);
                break;

            case 'trend':
                $return = $this->trendField($req, $query, $return);
                break;

            default:
                $base_fields = array('@message', '@tags', '@type');
                $return->all_fields = array('@message', '@tags', '@type');
                foreach ($result->hits->hits as $hit) {
                    $hit_id = $hit->{'_id'};
                    $return->results[$hit_id]['@cabin_time'] =
                            date('m/d H:i:s', strtotime(
                                    $hit->fields->{'@timestamp'}));
                    $return->results[$hit_id]['@timestamp'] =
                            $hit->fields->{'@timestamp'};
                    foreach ($hit->fields->{'@fields'} as $name => $value) {
                        $return->results[$hit_id][$name] = $value;
                        if (!in_array($name, $return->all_fields)) {
                            $return->all_fields[] = $name;
                        }
                    }

                    foreach ($base_fields as $field) {
                        $return->results[$hit_id][$field] =
                                $hit->fields->{$field};
                    }
                }
                sort($return->all_fields);
                $return->page_count = count($result->hits->hits);
        }

        $return->fields_requested = $req->fields;
        $return->elasticsearch_json = json_encode($query);

        //$return->debug = memory_get_usage();

        return $return;
    } //end processQuery


    /**
     * Analyze a field from a set of results.
     *
     * @param object $req Request data
     * @param object $query ES query
     * @param object $return Partial response
     * @return object Response to request
     */
    protected function analyzeField ($req, $query, $return) {
        $field = self::canonicalFieldName($req->analyze_field);
        $query->size = $this->config['analyze_limit'];
        $query->fields = $field;

        $result = $this->esQuery($query);

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
    protected function trendField ($req, $query, $return) {
        $field = self::canonicalFieldName($req->analyze_field);
        $query->size = 0;
        $query->fields = $field;
        $result = $this->esQuery($query);

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
        curl_setopt($ch, CURLOPT_URL, "http://" .
            $this->config['elasticsearch_server'] .
            "/{$this->index}/{$this->config['type']}/_search");
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
        $response = curl_exec($ch);
        return json_decode($response);
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

        if ($iDateTo >= $iDateFrom) {
            $aryRange[] = 'logstash-' . date('Y.m.d', $iDateFrom);
            while ($iDateFrom < $iDateTo) {
                $iDateFrom += 86400;
                if ($iDateTo >= $iDateFrom) {
                    $aryRange[] = 'logstash-' . date('Y.m.d',$iDateFrom);
                }
            }
        }

        $aryRange = array_intersect($aryRange, $this->getAllIndices());
        if (count($aryRange) > $this->config['smart_index_limit']) {
            $aryRange = array('_all');
        }
        sort($aryRange);

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
            case ($int <= 500):     return 100;
            case ($int <= 5000):    return 1000;
            case ($int <= 7500):    return 5000;
            case ($int <= 15000):   return 10000;
            case ($int <= 45000):   return 30000;
            case ($int <= 180000):  return 60000;
            case ($int <= 450000):  return 300000;
            case ($int <= 1200000): return 600000;
            case ($int <= 2700000): return 1800000;
            default:                return 3600000;
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

// vim:sw=4 ts=4 sts=4 et :
