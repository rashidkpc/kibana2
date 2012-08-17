<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>Kibana</title>
<script type="text/javascript" src="js/lib/jquery.min.js"></script>
<script type="text/javascript" src="js/lib/jquery.validate.js"></script>

<!-- Validate all the forms, -->
  <script>
  $(document).ready(function(){
    $('form').each(function () { 
        $(this).validate(); 
    });
  });
  </script>
 </head>
<body>
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

if(!empty($_POST)){
  //TODO: All sorts of injection could go on here...
  $formdata=array();
  //Allow only alphanumeric characters or underscores; strip underscores to prevent ES injection
  $formdata['name']=trim(preg_replace("/[^a-zA-Z0-9_]/","",$_POST['name']),'_');
  //TODO: how on earth can I properly sanitise filters while not intefering with them?
  $formdata['filter']=$_POST['filter'];
  //TODO: sanitise passwords
  $formdata['password']=$_POST['password'];
  $formdata['password2']=$_POST['password2'];
}


if(isset($_POST['new'])){
  if(empty($formdata['name'])){
    echo 'required attribute name not specified';
  }elseif(!$KIBANA_CONFIG['external_auth'] && empty($formdata['password'])){
    echo 'required attribute password not specified';
  }elseif(isset($USERS[$formdata['name']])){
    echo 'Username already taken';
  }else{
    if($formdata['password']!=$formdata['password2']){
      echo 'Passwords don\'t match';
    }else{
      $USERS[$formdata['name']]=new stdClass();
      $USERS[$formdata['name']]->name=$formdata['name'];
      $USERS[$formdata['name']]->salt=make_salt();
      $USERS[$formdata['name']]->pass=md5($formdata['password'].$USERS[$formdata['name']]->salt);
      $USERS[$formdata['name']]->admin=false;
      $USERS[$formdata['name']]->filter=$formdata['filter'];
      if (! create_user($USERS[$formdata['name']])) echo 'Error creating user';

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
        Filter:<input name="filter" value="'.str_replace('"','&quot;',$u->filter).'"><br />';
  if (!$KIBANA_CONFIG['external_auth']){
    echo 'New Password:<input name="password" id="'.$u->name.'_password" type="password"><br />
          Confirm:<input name="password2" type="password" equalTo="#'.$u->name.'_password"><br />';
  }
  echo'<input type="submit" value="Update"></form>';
}
  //TODO: select admins from this interface
  //TODO: _ttl field could make temporary users easy, might be useful?
  //TODO: ability to delete users
  //TODO: sort users
  //TODO: allow users to set their own passwords
  echo '<form id="newUserForm" method="post" action="admin.php">New user:
        <input type="hidden" name="new" value="true" ><br />
        Username:<input name="name" class="required"><br />
        Filter:<input name="filter" value="'.$u->filter.'"><br />';
    if (!$KIBANA_CONFIG['external_auth']){
      echo 'New Password:<input name="password" id="new_password" type="password" class="required"><br />
            Confirm:<input name="password2" type="password" equalTo="#new_password"><br />';
    }
    echo '<input type="submit" value="New User"></form>';

?>
</body>
</html>
