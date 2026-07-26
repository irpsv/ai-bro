<?php

declare(strict_types=1);

return [
    'db' => [
        'dsn' => getenv('BLOG_DSN') ?: 'mysql:host=127.0.0.1;dbname=blog;charset=utf8mb4',
        'user' => getenv('BLOG_DB_USER') ?: 'blog',
        'pass' => getenv('BLOG_DB_PASS') ?: 'blog',
    ],
    'app' => [
        'base_url' => getenv('BLOG_BASE_URL') ?: 'http://localhost:8080',
        'session_name' => 'blog_session',
    ],
];
