<?php

require_once('config.php');//TODO: proper configurable location

//TODO: is this secure? It's been a while since rashidkpc did it and a lot has changed...
session_start();

//If there are no users, create an admin user with name admin and pass pass
$ch = curl_init();
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/_count');//TODO: _search etc are valid names...
$result = json_decode(curl_exec($ch))->count;
if($result==0){
  $new_user=new stdClass();
  $new_user->name='admin';
  $new_user->salt=make_salt();
  $new_user->pass=md5('pass'.$new_user->salt);
  $new_user->admin=true;
  $new_user->filter='';
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
  curl_setopt($ch, CURLOPT_POST, true);
  curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/'.$new_user->name);//TODO: _search etc are valid names...
  curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($new_user)); 
  $result=curl_exec($ch);//TODO: check it was sucessful
  echo '<script language="javascript">alert(\'default admin user created, go change your password\');</script>';
    $_SESSION['auth'] = 1;
    $_SESSION['user'] = $new_user;
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
	curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/'.$name);//TODO: _search etc are valid names...
	$result = json_decode(curl_exec($ch));
	$USER=$result->_source;//TODO: seems to tolerate non-existant users, have a closer look at what's going on

	if( md5($pass . $USER->salt) == $USER->pass ) {
		$_SESSION['auth'] = 1;
		$_SESSION['user'] = $USER;
		header('Location: index.php');
	}
} 

if($_SESSION['auth'] == 1) {

	$USER=$users[$_SESSION['user']];//TODO: Illegal offset type in /home/magd3281/git/Kibana/auth.php on line 44
	$KIBANA_CONFIG['filter_string']=$USER['filter'];
}else{
	session_destroy();
        header('Location: login.php');
	exit;
}

function make_salt($length=12){
  $characters='qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890';
  for ($i=0;$i<$length;$i++){
    $string.=$characters[mt_rand(0,35)];
  }
  return $string;
}
?>

