<?php
$card=$_REQUEST['card'];
$logFile="log";
$fh=fopen($logFile, 'a+');
$timestamp=date("Y-m-d H:i:s");
$entry="$card $timestamp\n";
fwrite($fh, $entry);
fclose($fh);
?>