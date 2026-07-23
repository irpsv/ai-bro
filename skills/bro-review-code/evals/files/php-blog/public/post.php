<?php

declare(strict_types=1);

use Blog\View;

$app = require __DIR__ . '/bootstrap.php';
/** @var \Blog\PostRepository $posts */
$posts = $app['posts'];
/** @var \Blog\CommentService $commentService */
$commentService = $app['commentService'];
/** @var \Blog\Auth $auth */
$auth = $app['auth'];

$slug = isset($_GET['slug']) ? (string) $_GET['slug'] : '';
$search = isset($_GET['q']) ? (string) $_GET['q'] : null;

if ($slug === '') {
    http_response_code(400);
    echo 'Missing slug';
    exit;
}

$post = $posts->findPublishedBySlug($slug);
if ($post === null) {
    http_response_code(404);
    echo 'Post not found';
    exit;
}

$comments = $commentService->commentsWithProfiles((int) $post['id']);
if ($search !== null && $search !== '') {
    $comments = $commentService->commentsForPost((int) $post['id'], $search);
}

View::render('post', [
    'pageTitle' => $post['title'],
    'post' => $post,
    'comments' => $comments,
    'search' => $search,
    'auth' => $auth,
    'csrfToken' => $auth->csrfToken(),
]);
