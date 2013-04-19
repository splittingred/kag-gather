<?php
error_reporting(E_ALL); ini_set('display_errors',true);
require dirname(__FILE__).'/sso.php';
$sso = new SSO();

$loggedIn = false;
session_start();
if (!empty($_REQUEST['stage']) && $_REQUEST['stage'] == 'loginSuccess') {
	if (empty($_SESSION['kag.gather.ircname']) && empty($_SESSION['kag.gather.temp_host'])) {
		$sso->over('Please enable sessions in your browser and try again from the start.');
		
	} elseif (!empty($_SESSION['kag.gather.temp_host'])) {

	    $sso->login($_REQUEST['uname'],$_SESSION['kag.gather.temp_host']);
		unset($_SESSION['kag.gather.temp_host']);

	} elseif (!empty($_SESSION['kag.gather.ircname'])) {

	    $sso->link($_REQUEST['uname'],$_SESSION['kag.gather.ircname']);
		unset($_SESSION['kag.gather.ircname']);

	} else {
		$message = 'Invalid username/password. Please try again.';
	}
} elseif (!empty($_REQUEST['i'])) {
	$sso->redirectLink($_REQUEST['i']);
} elseif (!empty($_REQUEST['t'])) {
	$sso->redirectLogin($_REQUEST['t']);
}

if ($loggedIn) {
	echo '<h3>Successfully connected your KAG Account to KAG Gather!</h3>';
}
@session_write_close();
