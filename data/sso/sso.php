<?php
class SSO {
    public function getConfig() {
            $config = array();
            $configFile = dirname(dirname(dirname(__FILE__))).'/config/config.json';
            if (file_exists($configFile)) {
                $configData = file_get_contents($configFile);
                if (empty($configData)) {
                    $this->over("Could not read config file");
                }
                $config = json_decode($configData,true);
            }
            if (empty($config)) {
                $this->over("Failed to get config file.");
            } else if (!array_key_exists('database',$config) || !array_key_exists('development',$config['database'])) {
                $this->over("No DB connection info defined.");
            }
            $config = $config['database']['development'];
            if (empty($config)) {
                $this->over("Failed to get DB info in config file.");
            }
            return $config;
    }
    public function getDatabase() {
        $config = $this->getConfig();
        $mysqli = new mysqli($config['host'],$config['username'],$config['password'],$config['database']);
        /* check connection */
        if ($mysqli->connect_errno) {
            $this->over(sprintf("Connect failed: %s\n", $mysqli->connect_error));
        }
        return $mysqli;
    }


    public function login($username,$host) {
        $loggedIn = false;
		try {
			$mysqli = $this->getDatabase();
		    if (!$mysqli) return false;

			$kagUser = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$username)));
			$kagUser = htmlspecialchars($kagUser,ENT_COMPAT,'UTF-8');
			$hostname = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$host)));
			$hostname = htmlspecialchars($hostname,ENT_COMPAT,'UTF-8');

			$result = $mysqli->query('SELECT * FROM `users` WHERE `kag_user` = "'.$kagUser.'"');
			$found = false;
			if ($result) {
				$row = mysqli_fetch_assoc($result);
				if (!empty($row) && !empty($row['id'])) {
					$found = true;
				}
			}
            $end = strftime('%Y-%m-%d %H:%M:%S',(time() + 3600));
			if (!$found) {
				$mysqli->query('INSERT INTO `users` (`authname`,`nick`,`kag_user`,`host`,`temp`,`temp_end_at`) VALUES ("'.$kagUser.'","'.$kagUser.'","'.$kagUser.'","'.$hostname.'",1,"'.$end.'")');
				$loggedIn = true;
			} else {
				if ($mysqli->query('UPDATE `users` SET `authname` = "'.$kagUser.'", `nick` = "'.$kagUser.'", `host` = "'.$hostname.'", `temp` = 1, `temp_end_at` = "'.$end.'" WHERE `kag_user` = "'.$kagUser.'"') == true) {
			    	$loggedIn = true;
				}
			}
        	$mysqli->close();
		} catch (Exception $e) {
		    $this->over($e->getMessage());
		}
		return $loggedIn;
    }

    public function link($username,$ircName) {
        $loggedIn = false;
        try {
		    $mysqli = $this->getDatabase();
		    if (!$mysqli) return false;

			$username = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$username)));
			$username = htmlspecialchars($username,ENT_COMPAT,'UTF-8');
			$ircName = mysqli_real_escape_string($mysqli,strip_tags(str_replace(";","",$ircName)));
			$ircName = htmlspecialchars($ircName,ENT_COMPAT,'UTF-8');

			$result = $mysqli->query('SELECT * FROM `users` WHERE `authname` = "'.$ircName.'"');
			$found = false;
			if ($result) {
				$row = mysqli_fetch_assoc($result);
				if (!empty($row) && !empty($row['id'])) {
					$found = true;
				}
			}
			if (!$found) {
				$mysqli->query('INSERT INTO `users` (`authname`,`nick`,`kag_user`) VALUES ("'.$ircName.'","'.$ircName.'","'.$username.'")');
				$loggedIn = true;
			} else {
				if ($mysqli->query('UPDATE `users` SET `kag_user` = "'.$username.'" WHERE `authname` = "'.$ircName.'"') == true) {
			    	$loggedIn = true;
				}
			}
        	$mysqli->close();
		} catch (Exception $e) {
		    $this->over($e->getMessage());
		}
		return $loggedIn;
    }

    public function over($msg = '') {
        if (!empty($msg)) echo $msg;
        @session_write_close();
        exit();
    }
    public function redirectLink($name) {
        $_SESSION['kag.gather.ircname'] = $name;
        $url = 'https://sso.kag2d.com/?sso_provider=http://stats.gather.kag2d.nl/sso/&ircname='.$name;
        header("Location: ".$url);
        $this->over();
    }
    public function redirectLogin($host) {
        $_SESSION['kag.gather.temp_host'] = $host;
        $url = 'https://sso.kag2d.com/?sso_provider=http://stats.gather.kag2d.nl/sso/';
        header("Location: ".$url);
        $this->over();
    }
}