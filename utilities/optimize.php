<?php
// Run an optimize on indices older than this many day
// By default logstash uses daily rolling indices. As does Kibana
// so leaving this at 1 is recommended
$days = 1;

// Optimize down to this many segments. 
// Less segments means less storage, 2 is recommended.
$max_num_segments = 2;

include dirname(__FILE__).'/../config.php';
$elasticsearch_server = $KIBANA_CONFIG['elasticsearch_server'];

$before = strtotime($days . " days ago");

$ch = curl_init();
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/_status');
$result = json_decode(curl_exec($ch));

foreach($result->{'indices'} as $index => $nothing) {
	$parts = explode("-",$index);
	$date = explode('.',$parts[1]);
	$date = strtotime($date[1].'/'.$date[2].'/'.$date[0]);
	if($date < $before && $parts[0] == 'logstash') {
		$to_opt = "logstash-".date('Y.m.d',$date); 
		echo "Optimizing: ".$to_opt."\n"; 
		$ch = curl_init();
	        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	        curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/'.$to_opt.'/_optimize?max_num_segments='.$max_num_segments);
	        $optimized = json_decode(curl_exec($ch));
	}
    print_r($optimized);
}

echo "\n";
?>
