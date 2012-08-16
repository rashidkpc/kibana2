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
 $USER=$_SESSION['user'];

}else{
  die('ERROR: user accounts are disabled');
}

if (!$USER->admin){
  die('ERROR: permission denied');
}

$USERS=fetch_users();

//TODO: All sorts of injection could go on here...
$formdata=array();
//Allow only alphanumeric characters or underscores; strip underscores to prevent ES injection
$formdata['name']=trim(preg_replace("/[^a-zA-Z0-9_]/","",$_POST['name']),'_');
//TODO: how on earth can I properly sanitise filters while not intefering with them?
$formdata['filter']=$_POST['filter'];
//TODO: sanitise passwords
$formdata['password']=$_POST['password'];
$formdata['password2']=$_POST['password2'];


if(isset($_POST['new'])){
  if(empty($formdata['name'])||empty($formdata['password'])||empty($formdata['password2'])){
    echo 'required attribute not specified';//TODO: nice validating form, not just ugly errors
  }elseif(isset($USERS[$formdata['name']])){
    echo 'Username already taken';
  }else{
    if($formdata['password']!=$formdata['password2']){
      echo 'Passwords don\'t match';
    }else{
      $USERS[$formdata['name']]=new stdClass();
      $USERS[$formdata['name']]->name=$formdata['name'];
      $USERS[$formdata['name']]->salt=make_salt();
      $USERS[$formdata['name']]->pass=md5($formdata['password'].$new_user->salt);
      $USERS[$formdata['name']]->admin=false;
      $USERS[$formdata['name']]->filter=$formdata['filter'];
      if (! create_user($USERS[$formdata['name']])) echo 'Error creating default admin user';

    }
  }
}elseif(!empty($formdata['name'])){
 $USERS[$formdata['name']]->filter=$formdata['filter'];
  if(!empty($formdata['password'])){
    if($formdata['password']!=$formdata['password2']){
      echo 'Passwords don\'t match';
    }else{
      $USERS[$formdata['name']]->pass=md5($formdata['password'].$USERS[$formdata['name']]->salt);
    }
  }
  update_user($USERS[$formdata['name']]);
}

foreach ($USERS as $u){
  echo '<form id="edituser_'.$u->name.'" method="post" action="admin.php">'.$u->name.
       '<input type="hidden" name="name" value="'.$u->name.'"><br />
        Filter:<input name="filter" value="'.str_replace('"','&quot;',$u->filter).'"><br />
        New Password:<input name="password" type="password"><br />
        Confirm:<input name="password2" type="password"><br />
        <input type="submit" value="Update"></form>';
}
  //TODO: select admins from this interface
  //TODO: _ttl field could make temporary users easy, might be useful?
  //TODO: ability to delete users
  //TODO: sort users
  echo '<form method="post" action="admin.php">New user:
        <input type="hidden" name="new" value="true"><br />
        Username:<input name="name"><br />
        Filter:<input name="filter" value="'.$u->filter.'"><br />
        New Password:<input name="password" type="password"><br />
        Confirm:<input name="password2" type="password"><br />
        <input type="submit" value="New User"></form>';

?>
