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

$ch = curl_init();
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/_search');//TODO: _search etc are valid names...
$results = json_decode(curl_exec($ch))->hits->hits;


$USERS=Array();
foreach ($results as $result){
  $USERS[$result->_id]=$result->_source;
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
  }elseif(isset($USERS[$formdata['name']])){
    echo 'Username already taken';
  }else{
    if($formdata['password']!=$formdata['password2']){
      echo 'Passwords don\'t match';
    }else{
      $new_user=new stdClass();
      $new_user->name=$formdata['name'];
      $new_user->salt=make_salt();
      $new_user->pass=md5($formdata['password'].$new_user->salt);
      $new_user->admin=false;
      $new_user->filter=$formdata['filter'];
      $ch = curl_init();
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
      curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
      curl_setopt($ch, CURLOPT_POST, true);
      curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/'.$new_user->name);//TODO: _search etc are valid names...
      curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($new_user)); 
      $result=curl_exec($ch);//TODO: check it was sucessful
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
      $ch = curl_init();
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
      curl_setopt($ch, CURLOPT_POST, true);
      curl_setopt($ch, CURLOPT_URL, 'http://' . $KIBANA_CONFIG['elasticsearch_server'] . '/kibana/user/'.$formdata['name']);//TODO: _search etc are valid names...
      curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($USERS[$formdata['name']])); 
      $result=curl_exec($ch);//TODO: check it was sucessful
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
  echo '<form method="post" action="admin.php">New user:
        <input type="hidden" name="new" value="true"><br />
        Username:<input name="name"><br />
        Filter:<input name="filter" value="'.$u->filter.'"><br />
        New Password:<input name="password" type="password"><br />
        Confirm:<input name="password2" type="password"><br />
        <input type="submit" value="New User"></form>';

?>
