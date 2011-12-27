<?php
// How many days of logs should I keep?
$days = 4;

include '../config.php';

//echo 'logstash-'.date('Y.m.d',strtotime($days . " days ago"));

$before = strtotime($days . " days ago");

$ch = curl_init();
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_URL, 'http://' . $elasticsearch_server . '/_status');
$result = json_decode(curl_exec($ch));

foreach($result->{'indices'} as $index => $nothing) {
	$parts = explode("-",$index);
	$date = DateTime::createFromFormat('Y.m.d', $parts[1]);
	$date = $date->format('U');
	if($date < $before) {
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
