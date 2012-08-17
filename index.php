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

if ($KIBANA_CONFIG['use_auth']) require_once 'auth.php';

?>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <title>Kibana</title>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/excanvas.min.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.min.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.history.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.flot.min.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.flot.selection.min.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.smartresize.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/iso8601.min.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/safebase64.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery-ui-1.8.16.custom.min.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.ui.datepicker.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery-ui-timepicker-addon.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/jquery.ui.accordion.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/lib/json2.js"></script>
  <script type="text/javascript">
      var APP = {
        path: <?php echo json_encode($KIBANA_CONFIG['app_path']) ?>
      };
    </script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>js/ajax.js"></script>

  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>bootstrap/js/bootstrap.js"></script>
  <script type="text/javascript" src="<?php echo $KIBANA_CONFIG['app_path'] ?>bootstrap/js/bootstrap-dropdown.js"></script>
  <link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>bootstrap/css/bootstrap.min.css">
  <link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>bootstrap/css/bootstrap-responsive.min.css">
  <link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>css/style.css">
  <link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>css/jquery-ui-1.8.16.custom.css">
  <link rel="stylesheet" href="<?php echo $KIBANA_CONFIG['app_path'] ?>css/jquery.ui.datepicker.css">
  <style type="text/css">
    body {
    padding-top: 80px;
    padding-bottom: 40px;
    }

  </style>
  <link href="<?php echo $KIBANA_CONFIG['app_path'] ?>favicon.ico" rel="shortcut icon" type="image/x-icon" />

</head>


<body>

  <div class="navbar navbar-fixed-top">
    <div class="navbar-inner">
    <div class="container-fluid">
      <form id='searchform' class="form-search form-horizontal" action="">
        <table class=formatting><tr>
        <td width='1%'><center><img src='<?php echo $KIBANA_CONFIG['app_path'] ?>images/logo.png'></center>
        </td>
        <td width='1%'>
        <select name="time" id=timeinput class="span2">
        <option value="15 minutes">Last 15m</option>
        <option value="60 minutes">Last 60m</option>
        <option value="4 hours">Last 4h</option>
        <option value="12 hours">Last 12h</option>
        <option value="24 hours">Last 24h</option>
        <option value="48 hours">Last 48h</option>
        <option value="7 days">Last 7d</option>
        <option value="all">All Time</option>
        <option value="custom">Custom</option>
        </select>
        </td>
        <td width='85%'><input type="text" placeholder="Search" id=queryinput><input type="hidden" id=fieldsinput></td>
        <td width='1%'><button class="btn btn-primary" type=submit>Search</button></td>
        <td width='1%'><button class="btn btn-danger" type="reset" id=resetall>Reset</button></td>
        <td><div id=meta></div></td>
      </tr></table>
      </form>
      <?php if($KIBANA_CONFIG['use_auth'] && $USER->admin && $_SESSION['auth'] == 1)echo'<a href="admin.php">Admin</a>';?>
      <?php if($KIBANA_CONFIG['use_auth'] && ! $KIBANA_CONFIG['external_auth'] && $_SESSION['auth'] == 1)echo'<a href="auth.php?logout">Logout</a>';?>
      
    </div>
    </div>
  </div>

  <div class="container-fluid">
    <div class=row-fluid>

    <div class="span2" id=sidebar>
      <div class="sidebar">
      <div class="well">
        <div id=fields></div>
        <div id=analyze></div>
      </div>
      </div>
    </div>

    <div class="content span10" id=main>
      <div>
      <span id=sbctl class="ui-icon ui-icon-triangle-1-w ui-state-default jlink"></span>
      <span id=feedlinks></span>
      <p id=graphheader></p>
      <div id=graph style='height: 100px;'>
        <div class=hero-unit>
        <h1><img src=<?php echo $KIBANA_CONFIG['app_path'] ?>images/kibana_banner.png></h1>
        <br><br>
        <p><strong>Welcome to Kibana.</strong> Give me a few moments, I'm fetching some interesting data to display. It might be a minute, there could be lots of data in here. Consider the thousands, millions or billions of events I might be looking through, to find just the right ones for you. It's nothing, really. You're welcome.
        </p>
        </div>
      </div>
      <div id=legend></div>
      </div>
      <br>
      <div class='pagelinks'></div>
      <div id=logs class=zebra-stripped></div>
      <div class='pagelinks'></div>
    </div>
    </div>
  </div>

  </body>



</html>
