<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html lang="en">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>Kibana</title>
    <script type="text/javascript" src="js/jquery-1.6.2.min.js"></script>
    <script type="text/javascript" src="js/jquery.history.js"></script>
	<script type="text/javascript" src="js/jquery.flot.min.js"></script>
	<script type="text/javascript" src="js/jquery.flot.selection.min.js"></script>
    <script type="text/javascript" src="js/ajax.js"></script>
	<script type="text/javascript" src="js/base64.js"></script>
	<script type="text/javascript" src="js/jquery-ui-1.8.16.custom.min.js"></script>
	<script type="text/javascript" src="js/jquery.ui.datepicker.js"></script>
	<script type="text/javascript" src="js/jquery-ui-timepicker-addon.js"></script>
    <script type="text/javascript" src="js/jquery.ui.accordion.js"></script>
    <link rel="stylesheet" href="css/bootstrap.min.css">
    <LINK REL=StyleSheet HREF="css/style.css" TYPE="text/css" MEDIA=screen>
	<LINK REL=StyleSheet HREF="css/jquery-ui-1.8.16.custom.css" TYPE="text/css" MEDIA=screen>
	<LINK REL=StyleSheet HREF="css/jquery.ui.datepicker.css" TYPE="text/css" MEDIA=screen>
    <style type="text/css">
      body {
        padding-top: 60px;
      }
    
    </style>

</head>


<body>

    <div class="topbar">
      <div class="topbar-inner">
        <div class="container-fluid">
            <form class="pull-left" id='searchform' action="">
              <table class=formatting><tr> 
              <td width='1%'><center><img src='images/logo.png'></center></td>
              <td width='1%'>
              <select name="time" id=timeinput class=small>
                <option value="15 minutes">Last 15m</option>
                <option value="60 minutes">Last 60m</option>
                <option value="4 hours">Last 4h</option>
                <option value="12 hours">Last 12h</option>
                <option value="24 hours">Last 24h</option>
                <option value="7 days">Last 7d</option>
                <option value="100 years">All Time</option>
                <option value="custom">Custom</option>
              </select>
              </td>
              <td width='85%'><input type="text" placeholder="Search" id=queryinput><input type="hidden" id=fieldsinput></td>
              <td width='1%'><button class="btn primary" type=submit>Search</button></td>
              <td width='1%'><button class="btn danger" type="reset" id=resetall>Reset</button></td>
              <td id=meta width='15%'></td>
            </tr></table>
            </form>
            </tr></table>
        </div>
      </div>
    </div>

    <div class="container-fluid">
      <div class="sidebar" id=sidebar>
        <div class="well">
        <div id=fields></div>
        <div id=analyze></div>
        </div>
      </div>
      <div class="content" id=main>
        <span id=sbctl class="label"><a href="javascript:void(0)">&#8810;</a></span>
        <div>
            <p id=graphheader></p>
            <div id=graph style='height: 100px;'>
                <div class=hero-unit><h1><img src=images/kibana_banner.png></h1><br><br>
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

  </body>



</html>
