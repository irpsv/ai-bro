<?php

declare(strict_types=1);

use Blog\View;

$app = require __DIR__ . '/bootstrap.php';
/** @var \Blog\Auth $auth */
$auth = $app['auth'];

$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = isset($_POST['email']) ? trim((string) $_POST['email']) : '';
    $password = isset($_POST['password']) ? (string) $_POST['password'] : '';

    if ($auth->attempt($email, $password)) {
        header('Location: /index.php');
        exit;
    }

    $error = 'Неверный email или пароль';
}

View::render('login', [
    'pageTitle' => 'Вход',
    'auth' => $auth,
    'error' => $error,
]);
