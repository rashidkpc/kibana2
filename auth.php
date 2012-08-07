<?php

//some bits stolen from git diff 4052967 988816f
//TODO: is this secure? It's been a while since rashidkpc did it and a lot has changed...
session_start();

require('users.php');

$name = $_POST['username'];
$pass = $_POST['password'];

if(isset($_GET['logout'])) {
	setcookie("username", '');
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
	if( md5($pass . $users[$name]['salt']) == $users[$name]['pass'] ) {
		$_SESSION['auth'] = 1;
		$_SESSION['user'] = $name;
		header('Location: index.php');
	}
} 

if($_SESSION['auth'] == 1) {
	$USER=$users[$_SESSION['user']];
	$KIBANA_CONFIG['filter_string']=$USER['filter'];
}else{
	session_destroy();
        header('Location: login.php');
	exit;
}

?>

