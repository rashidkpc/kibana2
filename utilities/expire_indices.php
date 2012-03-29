<?php
// How many days of logs should I keep?
$days = 5;

include dirname(__FILE__).'/../config.php';
$elasticsearch_server = $KIBANA_CONFIG['elasticsearch_server'];

//echo 'logstash-'.date('Y.m.d',strtotime($days . " days ago"));

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
		$to_delete = "logstash-".date('Y.m.d',$date);
		echo "Deleting: ".$to_delete."\n";
		$ch = curl_init();
	    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
	    curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/'.$to_delete);
	    $deleted = json_decode(curl_exec($ch));
	}
}


echo "\n";
?>
