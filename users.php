<?php
//passwords are stored as md5( password . salt ) TODO: automatic salt selection and user friendly creation
$users=array(
  'admin'=>array(
    'pass'=>'3bf7255f35d7afc521ca3ce11e04a7d9',
    'filter'=>'',
    'salt'=>'this is a salt for one user',
    'admin'=>true
  ),
  'cron'=>array(
    'pass'=>'46f86b1ae435a9715cdfc1d1d49f386d',
    'filter'=>'cron',
    'salt'=>'while this one is for another',
    'admin'=>false
  )
);
