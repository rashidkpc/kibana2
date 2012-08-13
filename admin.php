<?php

if (!defined('KIBANA_CONFIG_FILE')) {
  // KIBANA_CONFIG_FILE is the path to the file that defines the
  // $KIBANA_CONFIG configuration array.
  // The default value will look for the file in the same directory as this
  // script.

  // allow overriding the config file via an environment variable.
  $config_path = getenv('KIBANA_CONFIG_FILE');
  if (empty($config_path)) {
    $config_path = dirname(__FILE__) . DIRECTORY_SEPARATOR . 'config.php';
  }

  define('KIBANA_CONFIG_FILE', $config_path);
}
require_once KIBANA_CONFIG_FILE;

if ($KIBANA_CONFIG['use_auth']){

  require_once 'auth.php';
}else{
  die('ERROR: user accounts are disabled');
}
if (!$USER['admin']){
  die('ERROR: permission denied');
}
//TODO: All sorts of injection could go on here...
$formdata=array();
//Allow only alphanumeric characters or underscores
$formdata['name']=preg_replace("/[^a-zA-Z0-9_]/","",$_POST['name']);
//TODO: how on earth can I properly sanitise filters while not intefering with them?
$formdata['filter']=$_POST['filter'];
//TODO: sanitise passwords
$formdata['password']=$_POST['password'];
$formdata['password2']=$_POST['password2'];
if(isset($_POST['new'])){
  if(empty($formdata['name'])||empty($formdata['password'])||empty($formdata['password2'])){
    echo 'required attribute not specified';//TODO: nice validating form, not just ugly errors
  }elseif(isset($users[$formdata['name']])){
    echo 'Username already taken';
  }else{
    if($formdata['password']==$formdata['password2']){
      $new_user=array();
      $new_user['name']=$formdata['name'];
      $new_user['salt']=make_salt();
      $new_user['pass']=md5($formdata['password'].$new_user['salt']);
      $new_user['admin']=false;
      $new_user['filter']=$formdata['filter'];
      $users[$new_user['name']]=$new_user;
      $users_string=var_export($users,true);
      $users_file=fopen('users.php','w');
      fwrite($users_file,'<?php'."\n".'$users='.$users_string."\n".'?>');
      fclose($users_file);
    }else{
      echo 'Passwords don\'t match';
    }
  }
}elseif(!empty($formdata['name'])){
  $users[$formdata['name']]['filter']=$formdata['filter'];
  if(!empty($formdata['password'])){
    if($formdata['password']==$formdata['password2']){
      $users[$formdata['name']]['pass']=md5($formdata['password'].$users[$formdata['name']]['salt']);
    }else{
      echo 'Passwords don\'t match';
    }
  }
  $users_string=var_export($users,true);
  $users_file=fopen('users.php','w');
  fwrite($users_file,'<?php'."\n".'$users='.$users_string."\n".'?>');
  fclose($users_file);
}

foreach ($users as $u){
  echo '<form id="edituser_'.$u['name'].'" method="post" action="admin.php">'.$u['name'].
       '<input type="hidden" name="name" value="'.$u['name'].'"><br />
        Filter:<input name="filter" value="'.str_replace('"','&quot;',$u['filter']).'"><br />
        New Password:<input name="password" type="password"><br />
        Confirm:<input name="password2" type="password"><br />
        <input type="submit" value="Update"></form>';
}
  echo '<form method="post" action="admin.php">New user:
        <input type="hidden" name="new" value="true"><br />
        Username:<input name="name"><br />
        Filter:<input name="filter" value="'.$u['filter'].'"><br />
        New Password:<input name="password" type="password"><br />
        Confirm:<input name="password2" type="password"><br />
        <input type="submit" value="New User"></form>';

function make_salt($length=12){
  $characters='qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890';
  for ($i=0;$i<$length;$i++){
    $string.=$characters[mt_rand(0,35)];
  }
  return $string;
}
?>
