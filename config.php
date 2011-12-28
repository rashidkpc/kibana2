<?

// Your elastic search server
$elasticsearch_server = "elasticsearch1:9200";

// The record type as defined in your logstash configuration.
// Seperate multiple types with a comma, no spaces.
$type = 'syslog';

// Authentication
$use_auth = true;
$auth_username = "admin";
$auth_password = "password";


