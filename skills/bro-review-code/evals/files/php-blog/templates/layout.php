<?php

declare(strict_types=1);

/** @var string $pageTitle */
/** @var string $content */
/** @var \Blog\Auth $auth */

use Blog\View;

?><!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= View::e($pageTitle ?? 'Блог') ?></title>
    <link rel="stylesheet" href="/assets/styles.css">
</head>
<body>
<header class="site-header">
    <a class="logo" href="/index.php">Demo Blog</a>
    <nav>
        <?php if ($auth->userId() !== null): ?>
            <span class="user"><?= View::e($auth->displayName()) ?></span>
        <?php else: ?>
            <a href="/login.php">Войти</a>
        <?php endif; ?>
    </nav>
</header>
<main class="container">
    <?php require __DIR__ . '/' . $template . '.php'; ?>
</main>
</body>
</html>
