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

//Not strictly required; this page doesn't actually reveal any data, but it's nice for consistancy
if ($KIBANA_CONFIG['use_auth']) require_once 'auth.php';
?>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html>
<head><title>Kibana Stream</title>
<script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.min.js"></script>
<script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/safebase64.js"></script>
<script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.history.js"></script>
<script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/stream.js"></script>
<script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/json2.js"></script>
<script type="text/javascript">
      var APP = {
        path: <?php echo json_encode($KIBANA_CONFIG['app_path']) ?>
      };
    </script>
<link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>bootstrap/css/bootstrap-responsive.min.css">
<link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>css/style.css">
<link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>css/stream.css">
  <style type="text/css">
    body {
    padding-top: 20px;
    padding-bottom: 40px;
    }

  </style>

</head>

<body>

  <div class="navbar navbar-fixed-top">
    <div class="navbar-inner">
    <div class="container-fluid topbar">
        <img src='<?php echo $KIBANA_CONFIG['app_path'] ?>images/logo.png' class=pull-left>
        <span id=pause class=pull-left>                                         
          <button class="btn tiny btn-danger" style="margin-right: 20px;" id="pause_stream">Pause</button>
        </span>
        <span id=query class=pull-left></span>
        <span id=meta class=pull-right> </span>
    </div>
    </div>
  </div>

  <div class="container-fluid">
    <div class=row-fluid>
    <table id=tweets class='table table-condensed'></table>
    </div>
  </div>

  </body>



</html>
<?
?>
