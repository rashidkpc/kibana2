<?php

//TODO: is this secure? It's been a while since rashidkpc did it and a lot has changed...
session_start();

//If there are no users, create an admin user with name admin and pass pass
if(count(fetch_users())==0){
  $new_user=new stdClass();
  $new_user->name='admin';
  $new_user->salt=make_salt();
  $new_user->pass=md5('pass'.$new_user->salt);
  $new_user->admin=true;
  $new_user->filter='';
  if ( create_user($new_user)) {
    echo '<script language="javascript">alert(\'default admin user created, go change your password\');</script>';
    $_SESSION['auth'] = 1;
    $_SESSION['user'] = $new_user;
  }else{
    echo '<script language="javascript">alert(\'Error creating default admin user. This is likely to be caused by a problem connecting to Elasticsearch\');</script>';
  }
}

if (isset($_POST['auth_username'])) $name = $_POST['auth_username'];
if (isset($_POST['auth_password'])) $pass = $_POST['auth_password'];

if(isset($_GET['logout'])) {
	session_destroy();
	header('Location: login.php');
	exit;        
}

if( isset($name) || isset($pass) ) {

	if( empty($name) ) {
		die ("ERROR: Please enter username!");
	}
	if( empty($pass) ) {
		die ("ERROR: Please enter password!");
	}

	$ch = curl_init();
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/'.$name);
	$result = json_decode(curl_exec($ch));
	$USER=$result->_source;//TODO: seems to tolerate non-existant users, have a closer look at what's going on

	if( md5($pass . $USER->salt) == $USER->pass ) {
		$_SESSION['auth'] = 1;
		$_SESSION['user'] = $USER;
		header('Location: index.php');
	}
} 

if($_SESSION['auth'] == 1) {

	$USER=$_SESSION['user'];
	$KIBANA_CONFIG['filter_string']=$USER->filter;
}else{
	session_destroy();
        header('Location: login.php');
	exit;
}

function create_user($user){
  global $KIBANA_CONFIG;
  //TODO: validate the user object
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
  curl_setopt($ch, CURLOPT_POST, true);
  curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/'.$user->name);
  curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($user)); 
  $result=curl_exec($ch);
  return $result;
}

function update_user($user){
  global $KIBANA_CONFIG;
  //TODO: validate the user object
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_POST, true);
  curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/'.$user->name);
  curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($user)); 
  $result=curl_exec($ch);
  return $result;
}

function fetch_users(){
  global $KIBANA_CONFIG;
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/_search');
  $results = json_decode(curl_exec($ch))->hits->hits;
  $users=Array();
  foreach ($results as $result){
    $users[$result->_id]=$result->_source;
  }
  return $users;
}

function make_salt($length=12){
  $characters='qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890';
  $string='';
  for ($i=0;$i<$length;$i++){
    $string.=$characters[mt_rand(0,35)];
  }
  return $string;
}
?>

