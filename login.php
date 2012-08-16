<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>Kibana</title>
<script type="text/javascript" src="js/lib/jquery.min.js"></script>
<script type="text/javascript" src="js/lib/jquery.history.js"></script>
<script type="text/javascript" src="js/lib/jquery-ui-1.8.16.custom.min.js"></script>

<LINK REL=StyleSheet HREF="css/style.css" TYPE="text/css" MEDIA=screen>
<LINK REL=StyleSheet HREF="css/jquery-ui-1.8.16.custom.css" TYPE="text/css" MEDIA=screen>

<script type="text/javascript">

$(document).ready(function () {
		$('input[type=text],input[type=password]').clearDefault();
		});
(function($){
 $.fn.clearDefault = function(){
 return this.each(function(){
	 var default_value = $(this).val();
	 $(this).focus(function(){
		 if ($(this).val() == default_value) $(this).val("");
		 });
	 $(this).blur(function(){
		 if ($(this).val() == "") $(this).val(default_value);
		 });
	 });
 };
 })(jQuery);

</script>

</head>
<body>
<div id="login">
<br><br><br>
<center>
<form action="index.php" method="post">
<table id=logintable>
<tr><td><input type="text" name="auth_username" value="username" /></td></tr>
<tr><td><input type="password" name="auth_password" value="password" /></td></tr>
<tr><td align=right><input type="submit" class=submit value=Login /></td></tr>
</table>
</form>
</center>
</div>

</body>
</html>
