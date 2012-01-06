<?php

include 'config.php';

session_start();

$name = $_POST['username'];
$pass = $_POST['password'];

if(isset($_GET['logout'])) {
	setcookie("username", '');
	session_destroy();
	header('Location: login.php');
	exit;        
}

$badpass = '';
if( isset($name) || isset($pass) ) {
	if( empty($name) || empty($pass)) {
	   $badpass = '?fail';
	}

	if( $name == $auth_username && $pass == $auth_password ) {
		$_SESSION['auth'] = 1;
		$_SESSION['username'] = $name;
		setcookie("username", $name);
		header('Location: index.php');
	}
    $badpass = '?fail';
} 

if($_SESSION['auth'] != 1) {
	session_destroy();
        header('Location: login.php'.$badpass);
	exit;
}

?>
