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
function redirectToSsoQuest($host) {
	$_SESSION['kag.gather.temp_host'] = $host;
	$url = 'https://sso.kag2d.com/?sso_provider=http://stats.gather.kag2d.nl/sso/';
	header("Location: ".$url);
	over();
}
function get_config() {
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
	    return $config;
}
function get_db() {
	$config = get_config();
	$mysqli = new mysqli($config['host'],$config['username'],$config['password'],$config['database']);
	/* check connection */
	if ($mysqli->connect_errno) {
	    over(sprintf("Connect failed: %s\n", $mysqli->connect_error));
	}
	return $mysqli;
}

$loggedIn = false;
session_start();
if (!empty($_REQUEST['stage'])) {
	if (empty($_SESSION['kag.gather.ircname']) && empty($_SESSION['kag.gather.temp_host'])) {
		over('Please enable sessions in your browser and try again from the start.');
		
	} elseif (!empty($_SESSION['kag.gather.temp_host'])) {
		try {
			$mysqli = get_db();
			$kag_user = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$_REQUEST['uname'])));
			$kag_user = htmlspecialchars($kag_user,ENT_COMPAT,'UTF-8');
			$hostname = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$_SESSION['kag.gather.temp_host'])));
			$hostname = htmlspecialchars($hostname,ENT_COMPAT,'UTF-8');

			$result = $mysqli->query('SELECT * FROM `users` WHERE `kag_user` = "'.$kag_user.'"');
			$found = false;
			if ($result) {
				$row = mysqli_fetch_assoc($result);
				if (!empty($row) && !empty($row['id'])) {
					$found = true;
				}
			}
			if (!$found) {
			    $end = strftime('%Y-%m-%d %H:%M:%S',(time() + 3600));
				$mysqli->query('INSERT INTO `users` (`authname`,`nick`,`kag_user`,`host`,`temp`,`temp_end_at`) VALUES ("'.$uname.'","'.$uname.'","'.$uname.'","'.$hostname.'",1,"'.$end.'")');
				$loggedIn = true;
			} else {
				if ($mysqli->query('UPDATE `users` SET `kag_user` = "'.$uname.'" WHERE `authname` = "'.$ircname.'"') == true) {
			    	$loggedIn = true;
				}
			}
        	$mysqli->close();
		}
		unset($_SESSION['kag.gather.temp_host']);
	} elseif ($_REQUEST['stage'] == 'loginSuccess') {   
	    try {
		    $mysqli = get_db();
		    			
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
} elseif (!empty($_REQUEST['t'])) {
	redirectToSsoQuest($_REQUEST['t']);
}

if ($loggedIn) {
	echo '<h3>Successfully connected your KAG Account to KAG Gather!</h3>';
}

