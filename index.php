<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<?php
include 'config.php';
if ($use_auth) include 'auth.php';
?>

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


	<LINK REL=StyleSheet HREF="css/style.css" TYPE="text/css" MEDIA=screen>
	<LINK REL=StyleSheet HREF="css/jquery-ui-1.8.16.custom.css" TYPE="text/css" MEDIA=screen>
	<LINK REL=StyleSheet HREF="css/jquery.ui.datepicker.css" TYPE="text/css" MEDIA=screen>
</head>
<body>
<div id="header">
	<div id=meta></div>
	<div id=tips><span class="ui-icon ui-icon-lightbulb ui-state-default ui-corner-all" style="display: inline-block; vertical-align: middle;">tip</span> Speed up searches by keeping timeframes short</div>
	<div id=menu>
		<?php include 'menu.php';?>	
	</div>
</div>
<div id="top">
	<div id=searchdiv>
		<center>
                <form action="" method="post" id=queryform>
			<table><tr>
			<th>Timeframe</th><th>Search</th>
			</tr>
			<tr>
			<td width="1%">
			<select name="time" id=timeinput>
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
			<td><input type="text" name="search" id=queryinput width="97%"/>
			<input type="hidden" name="fields" id=fieldsinput /></td>
			<td width="1%"><input type="submit" class=submit value=Search /></td>
			<td width="1%"><input type="reset" class="submit" id=resetall value="Reset" /></td>
			</tr><tr><td></td><td><div id=fields></div></td></tr>
			</tr><tr><td></td><td><div id=analyze></div></td></tr>
			</table>
                </form>
		</center>
        </div>


</div>
<div id="content">

<div id="main">

<div id="graphheader"></div>
<div id="graph">
</div>

<div class=pagelinks></div>
<div id="logs">
<h2>Welcome to <strong>Kibana</strong>.</h2> Give me a minute, I'm fetching some interesting stuff to display here. Might be a minute. I'm working as hard as I can. STOP YELLING AT ME!
</div>
<div class=pagelinks></div>

</div>
</div>

<div id="footer">
<center>This is Kibana. Kibana is a log analysis tool. Kibana sits on top of <a href='http://logstash.net'>Logstash</a> and <a href='http://www.elasticsearch.org'>Elastic Search</a></center>
</div>

</body>
</html>
