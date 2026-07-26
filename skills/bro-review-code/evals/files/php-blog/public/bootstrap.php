<?php

declare(strict_types=1);

use Blog\Auth;
use Blog\CommentRepository;
use Blog\CommentService;
use Blog\Database;
use Blog\PostRepository;

$config = require dirname(__DIR__) . '/config/config.php';

spl_autoload_register(static function (string $class): void {
    $prefix = 'Blog\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relative = substr($class, strlen($prefix));
    $path = dirname(__DIR__) . '/src/' . str_replace('\\', '/', $relative) . '.php';
    if (is_file($path)) {
        require $path;
    }
});

$pdo = Database::connection($config['db']);
$auth = new Auth($pdo, $config['app']['session_name']);
$posts = new PostRepository($pdo);
$comments = new CommentRepository($pdo);
$commentService = new CommentService($comments, $posts, $auth);

$auth->startSession();

return [
    'config' => $config,
    'pdo' => $pdo,
    'auth' => $auth,
    'posts' => $posts,
    'comments' => $comments,
    'commentService' => $commentService,
];
