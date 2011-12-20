<?

include 'config.php';
if ($use_auth) include 'auth.php';

$real_timezone = date_default_timezone_get();

if ($_GET['page']) {

    $index = "_all";

    // Get JSON
    $json = json_decode(base64url_decode($_GET['page']));

    // Seperate
    $url_query = ($json->{'search'} == "" ? "*" : $json->{'search'});
    $fields = (isset($json->{'fields'}) ? $json->{'fields'} : '');
    $time = (isset($json->{'time'}) ? $json->{'time'} : '');
    $interval = (isset($json->{'interval'}) ? $json->{'interval'} : 600000);
    $from = (isset($json->{'offset'}) ? $json->{'offset'} : 0);

    $interval = (isset($_GET['interval']) ? roundInterval($_GET['interval']) : 600000);


    if ($_GET['mode'] == 'graph') {
        $return->{'mode'} = 'graph';
    }

    //$query = array("query" => array());
    $query['from'] = $json->{'offset'};
    $query['query']['query_string']['query'] = "(" . $url_query . ")";
    $query['size'] = 50;
    $query['sort']['@timestamp']['order'] = 'desc';
    $query['fields'] = array('@timestamp', '@fields', '@message', '@tags');



    // Check the mode
    if ($_GET['mode'] == 'graph') {
        $query['size'] = 0;
        $query['facets']['histo1']['date_histogram']["field"] = "@timestamp";
        $query['facets']['histo1']['date_histogram']["interval"] = $interval;
    } else {
        $query['facets']['stats']['statistical']["field"] = '@timestamp';
    }

    
    if ($json->{'timeframe'} != "custom") {
        $time->{'from'} = date('c', strtotime($json->{'timeframe'} . " ago"));
        $time->{'to'} = date('c');
    }
    

    // Check if we have a time range, if so filter
    date_default_timezone_set('UTC');
    if ($time != '') {
        $query['filter']['range']['@timestamp'] = $time;
        $facet = ($_GET['mode'] == 'graph' ? "histo1" : "stats");
        $query['facets'][$facet]['facet_filter']['range']['@timestamp'] = $time;
        // If our timerange only covers 1 index, only use that index instead of _all
        if (date('Y.m.d',strtotime($time->{'from'})) == date('Y.m.d',strtotime($time->{'to'}))) {
            $index = 'logstash-' . date('Y.m.d', strtotime($time->{'from'}));
        }
    }
    date_default_timezone_set($real_timezone);
    $result = esQuery($query);


    // Add some top level statistical and informational data
    $return->{'index'} = $index;
    $return->{'hits'} = $result->{'hits'}->{'total'};
    $return->{'graph'}->{'data'} = $result->{'facets'}->{'histo1'}->{'entries'};
    $return->{'total'} = esTotal();
    
    // Compute the interval for 100 bars
    $return->{'graph'}->{'interval'} = ($_GET['mode'] == 'graph' ? $interval : ($result->{'facets'}->{'stats'}->{'max'} - $result->{'facets'}->{'stats'}->{'min'}) / 100);
    
    $return->{'fields_requested'} = $fields;
    $return->{'all_fields'} = array('@message', '@tags');
    $return->{'elasticsearch_json'} = json_encode($query);
    
    // Process the hits
    $i = 0;
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
    }
    sort($return->{'all_fields'});
    $return->{'page_count'} = $i;
    $return = json_encode($return);

    echo $return;
} else {
    echo "No Page parameter";
}

function esQuery($query) {
    global $index, $elasticsearch_server;
    $ch = curl_init();
    $data = json_encode($query);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/' . $index . '/_search');
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

?>
