<?php
error_reporting(E_ALL); ini_set('display_errors',true);
function over($msg = '') {
	if (!empty($msg)) echo $msg;
	@session_write_close();
	exit();
}
function redirectToSso($name) {
	$_SESSION['kag.gather.ircname'] = $name;
	$url = 'https://sso.kag2d.com/?sso_provider=http://stats.gather.kag2d.nl/sso/&ircname='.$name;
	header("Location: ".$url);
	over();
}
$loggedIn = false;
session_start();
if (!empty($_REQUEST['stage'])) {
	if (empty($_SESSION['kag.gather.ircname'])) {
		redirectToSso($_REQUEST['i']);
	} elseif ($_REQUEST['stage'] == 'loginSuccess') {
		$config = array();
	    $configFile = dirname(dirname(dirname(__FILE__))).'/config/config.json';
	    if (file_exists($configFile)) {
	    	$configData = file_get_contents($configFile);
	    	if (empty($configData)) {
	    	    over("Could not read config file");
	    	}
	    	$config = json_decode($configData,true);
	    }
	    if (empty($config)) {
	        over("Failed to get config file.");
		} else if (!array_key_exists('database',$config) || !array_key_exists('development',$config['database'])) {
			over("No DB connection info defined.");
	    }
	    $config = $config['database']['development'];
	    if (empty($config)) {
	        over("Failed to get DB info in config file.");
	    }
	    
	    try {
		    $mysqli = new mysqli($config['host'],$config['username'],$config['password'],$config['database']);
			/* check connection */
			if ($mysqli->connect_errno) {
			    over(sprintf("Connect failed: %s\n", $mysqli->connect_error));
			}
			
			$uname = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$_REQUEST['uname'])));
			$uname = htmlspecialchars($uname,ENT_COMPAT,'UTF-8');
			$ircname = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$_SESSION['kag.gather.ircname'])));
			$ircname = htmlspecialchars($ircname,ENT_COMPAT,'UTF-8');

			$result = $mysqli->query('SELECT * FROM `users` WHERE `authname` = "'.$ircname.'"');
			$found = false;
			if ($result) {
				$row = mysqli_fetch_assoc($result);
				if (!empty($row) && !empty($row['id'])) {
					$found = true;
				}
			}
			if (!$found) {
				$mysqli->query('INSERT INTO `users` (`authname`,`nick`,`kag_user`) VALUES ("'.$ircname.'","'.$ircname.'","'.$uname.'")');
				$loggedIn = true;
			} else {
				if ($mysqli->query('UPDATE `users` SET `kag_user` = "'.$uname.'" WHERE `authname` = "'.$ircname.'"') == true) {
			    	$loggedIn = true;
				}
			}
        	$mysqli->close();
		} catch (Exception $e) {
		    over($e->getMessage());
		}
	} else {
		$message = 'Invalid username/password. Please try again.';
	}
} elseif (!empty($_REQUEST['i'])) {
	redirectToSso($_REQUEST['i']);
}

if ($loggedIn) {
	echo '<h3>Successfully connected your KAG Account to KAG Gather!</h3>';
}

