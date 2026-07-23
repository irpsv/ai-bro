<?php

declare(strict_types=1);

$app = require __DIR__ . '/bootstrap.php';
/** @var \Blog\Auth $auth */
$auth = $app['auth'];
$auth->logout();
header('Location: /index.php');
exit;
