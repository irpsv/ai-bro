<?php

declare(strict_types=1);

use Blog\View;

$app = require __DIR__ . '/bootstrap.php';
/** @var \Blog\PostRepository $posts */
$posts = $app['posts'];

View::render('index', [
    'pageTitle' => 'Блог',
    'posts' => $posts->listPublished(20, 0),
    'auth' => $app['auth'],
]);
