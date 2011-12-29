<?

// Your elastic search server
$elasticsearch_server = "elasticsearch1:9200";

// The record type as defined in your logstash configuration.
// Seperate multiple types with a comma, no spaces.
$type = 'syslog';

// When using analyze, use this many of the most recent
// results for user's query
$analyze_limit = 20000;

// Show this many results in analyze mode
$analyze_show = 25;

// Authentication
$use_auth = false;
$auth_username = "admin";
$auth_password = "password";


