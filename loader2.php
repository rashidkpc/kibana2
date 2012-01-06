<?
include 'config.php';
if ($use_auth) include 'auth.php';
$real_timezone = date_default_timezone_get();

if ($_GET['page']) {

	// Use _all by default, unless logic further down tells us otherwise
    $index = "_all";

    // Get JSON
    $json = json_decode(base64url_decode($_GET['page']));

    // Preparse parameters
    $url_query = ($json->{'search'} == "" ? "*" : $json->{'search'});
    $fields = (isset($json->{'fields'}) ? $json->{'fields'} : '');
    $time = (isset($json->{'time'}) ? $json->{'time'} : '');
    $interval = (isset($json->{'interval'}) ? $json->{'interval'} : 600000);
    $from = (isset($json->{'offset'}) ? $json->{'offset'} : 0);
    $interval = (isset($_GET['interval']) ? roundInterval($_GET['interval']) : 600000);

	// Contruct the query
    $query['from'] = $json->{'offset'};
    $query['query']['filtered']['query']['query_string']['query'] = "(" . $url_query . ")";
    $query['size'] = 50;
    $query['sort']['@timestamp']['order'] = 'desc';
    $query['fields'] = array('@timestamp', '@fields', '@message', '@tags', '@type');


	// Check the mode
	switch($_GET['mode']) {
		case 'graph':
			$return->{'mode'} = 'graph';
			$query['size'] = 0;
        	$query['facets']['histo1']['date_histogram']["field"] = "@timestamp";
        	$query['facets']['histo1']['date_histogram']["interval"] = $interval;	
			break;
        case 'trend':
		case 'analyze':
            $field = $json->{'analyze_field'};
            $query['facets']['stats']['statistical']["field"] = '@timestamp';
			$return->{'mode'} = 'analyze';
			break;
		default:
			$query['facets']['stats']['statistical']["field"] = '@timestamp';	
	}

	// Unless the user gives us exact times, compute relative timeframe based on drop down
    if ($json->{'timeframe'} != "custom") {
        $time->{'from'} = date('c', strtotime($json->{'timeframe'} . " ago"));
        $time->{'to'} = date('c');
    }

	// Dates in this section are UTC
    date_default_timezone_set('UTC');

	// Check if we have a time range, if so filter
    if ($time != '') {
		$query['query']['filtered']['filter']['range']['@timestamp'] = $time;
        $facet = ($_GET['mode'] == 'graph' ? "histo1" : "stats");
        // If our timerange only covers 1 index, only use that index instead of _all
        if ($smart_index) {
            $index = implode(',',getIndicesByTime($time->{'from'},$time->{'to'}));
		    //$index = (date('Y.m.d',strtotime($time->{'from'})) == date('Y.m.d',strtotime($time->{'to'})) ? 'logstash-' . date('Y.m.d', strtotime($time->{'from'})) : '_all');
        }
    }

	// After this, dates are in local timezone
    date_default_timezone_set($real_timezone);
    $result = esQuery($query);

    // Add some top level statistical and informational data
    $return->{'index'} = $index;
    $return->{'hits'} = $result->{'hits'}->{'total'};
    $return->{'graph'}->{'data'} = $result->{'facets'}->{'histo1'}->{'entries'};
    $return->{'total'} = esTotal();

    // Compute an interval to give us around 100 bars
    $return->{'graph'}->{'interval'} = ($_GET['mode'] == 'graph' ? $interval : ($result->{'facets'}->{'stats'}->{'max'} - $result->{'facets'}->{'stats'}->{'min'}) / 100);
 
    // Are we analyzing data or displaying logs? 
    $i = 0;

    switch($_GET['mode']) {
        case 'analyze':
            $field = (substr($field,0,1) != '@' ? '@fields.'.$field : $field);
            $query['size'] = $analyze_limit;
            $query['fields'] = $field;
            $result = esQuery($query);
            foreach ($result->{'hits'}->{'hits'} as $hit) {
                $i++;
                $analyze[$i] = implode(',',$hit->{'fields'}->{$field});
            }
            unset($result);

            $analyze = array_count_values($analyze);
            arsort($analyze);
            $analyze = array_slice($analyze,0,$analyze_show,true);

            foreach ($analyze as $key => $value) {
                $final[$key]['count'] = $value;
            }

            $return->{'analysis'}->{'results'} = $final;
            $return->{'analysis'}->{'count'} = $i;
            break;
        case 'trend':
            // See how many hits we'd get
            $field = (substr($field,0,1) != '@' ? '@fields.'.$field : $field);
            $query['size'] = 0;
            $query['fields'] = $field;
            $result = esQuery($query);
            
            // Scale samples. If analyze_limit is more than 50% of the results, then change size to 50%
            // of the results to avoid overlap
            $query['size'] = ($return->{'hits'} < $analyze_limit*2 ? $return->{'hits'}/2 : $analyze_limit);
            $result = esQuery($query);           
 
            $i = 0;
            foreach ($result->{'hits'}->{'hits'} as $hit) {
                $i++;
                $analyze[$i] = implode(',',$hit->{'fields'}->{$field});
            }
            unset($result);         
            $analyze = array_count_values($analyze);
   
            $query['sort']['@timestamp']['order'] = 'asc';
            $result = esQuery($query);

            $i = 0;
            foreach ($result->{'hits'}->{'hits'} as $hit) {
                $i++;
                $analyze2[$i] = implode(',',$hit->{'fields'}->{$field});
            }
            unset($result);
            $analyze2 = array_count_values($analyze2);
        
            foreach ($analyze as $key => $value) {
                $final[$key]['count'] = $value;
                $final[$key]['start'] = $analyze2[$key];
                $final[$key]['trend'] = round((($value/$query['size'])-($analyze2[$key]/$query['size']))*100,2);
                $final[$key]['abs'] = abs($final[$key]['trend']);
            }

            aasort($final,"abs");
 
            $final = array_slice($final,0,$analyze_show,true);
            $return->{'analysis'}->{'results'} = $final;
            $return->{'analysis'}->{'count'} = $i;
            break;
        default:
            $return->{'all_fields'} = array('@message', '@tags', '@type');
            foreach ($result->{'hits'}->{'hits'} as $hit) {
                $i++;
                $return->{'results'}[$hit->{'_id'}]['@cabin_time'] = date('m/d H:i:s', strtotime($hit->{'fields'}->{'@timestamp'}));
                $return->{'results'}[$hit->{'_id'}]['@timestamp'] = $hit->{'fields'}->{'@timestamp'};
                foreach ($hit->{'fields'}->{'@fields'} as $fieldname => $field) {
                    $value = $hit->{'fields'}->{'@fields'}->{$fieldname};
                    $return->{'results'}[$hit->{'_id'}][$fieldname] = $value;
                    if (!in_array($fieldname, $return->{'all_fields'})) array_push($return->{'all_fields'}, $fieldname);
                }
                $return->{'results'}[$hit->{'_id'}]['@message'] = $hit->{'fields'}->{'@message'};
                $return->{'results'}[$hit->{'_id'}]['@tags'] = $hit->{'fields'}->{'@tags'};
                $return->{'results'}[$hit->{'_id'}]['@type'] = $hit->{'fields'}->{'@type'};
            }
            sort($return->{'all_fields'});
            $return->{'page_count'} = $i;
    }
    $return->{'fields_requested'} = $fields;
    $return->{'elasticsearch_json'} = json_encode($query);

    //$return->{'debug'} = memory_get_usage();
    $return = json_encode($return);
    echo $return;

} else {

    echo "No Page parameter";

}

function esQuery($query) {
    global $index,$type, $elasticsearch_server;
    $ch = curl_init();
    $data = json_encode($query);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/' . $index . '/'.$type.'/_search');
    curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
    $result = json_decode(curl_exec($ch));
    return $result;
}

function esTotal() {
    global $elasticsearch_server;
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/_status');
    $result = json_decode(curl_exec($ch));

    $indices = $result->{'indices'};
    $totaldocs = 0;
    foreach ($indices as $index) {
        $totaldocs += $index->{'docs'}->{'num_docs'};
    }
    return $totaldocs;
}

function roundInterval($int) {
    switch ($int) {
        case ($int <= 500):
            return 100;
        case ($int <= 5000):
            return 1000;
        case ($int <= 7500):
            return 5000;
        case ($int <= 15000):
            return 10000;
        case ($int <= 45000):
            return 30000;
        case ($int <= 180000):
            return 60000;
        case ($int <= 450000):
            return 300000;
        case ($int <= 1200000):
            return 600000;
        case ($int <= 2700000):
            return 1800000;
    }
    return 3600000;
}

function base64url_decode($base64url) {
    $base64 = strtr($base64url, '-_', '+/');
    $plainText = base64_decode($base64);
    return ($plainText);
}

function aasort (&$array, $key) {
    $sorter=array();
    $ret=array();
    reset($array);
    foreach ($array as $ii => $va) {
        $sorter[$ii]=$va[$key];
    }
    arsort($sorter);
    foreach ($sorter as $ii => $va) {
        $ret[$ii]=$array[$ii];
    }
    $array=$ret;
}

function getIndicesByTime($strDateFrom,$strDateTo) {
    global $smart_index_limit;
    $aryRange=array();
    $iDateFrom=strtotime($strDateFrom);
    $iDateTo=strtotime($strDateTo);

    if ($iDateTo>=$iDateFrom) {
        array_push($aryRange,'logstash-' . date('Y.m.d',$iDateFrom)); // first entry

        while ($iDateFrom<$iDateTo) {
            $iDateFrom+=86400; // add 24 hours
            if ($iDateTo>=$iDateFrom) array_push($aryRange,'logstash-' . date('Y.m.d',$iDateFrom));
        }
    }

    $aryRange = array_intersect($aryRange,getAllIndices());
    if (count($aryRange) > $smart_index_limit) $aryRange = array('_all'); 
    return $aryRange;
}

function getAllIndices() {
    global $elasticsearch_server;
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/_status');
    $result = json_decode(curl_exec($ch));

    $indices = array();
    foreach ($result->{'indices'} as $indexname => $index) {
        array_push($indices,$indexname);
    }
    return $indices;    
}


?>
