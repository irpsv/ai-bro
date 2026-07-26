<?php

declare(strict_types=1);

$app = require __DIR__ . '/bootstrap.php';
/** @var \Blog\CommentService $commentService */
$commentService = $app['commentService'];
/** @var \Blog\PostRepository $posts */
$posts = $app['posts'];

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo 'Method not allowed';
    exit;
}

$action = isset($_POST['action']) ? (string) $_POST['action'] : 'create';

try {
    if ($action === 'create') {
        $postId = isset($_POST['post_id']) ? (int) $_POST['post_id'] : 0;
        $body = isset($_POST['body']) ? (string) $_POST['body'] : '';
        $commentId = $commentService->addComment($postId, $body);

        $post = $posts->findById($postId);
        $slug = $post['slug'] ?? '';
        header('Location: /post.php?slug=' . rawurlencode((string) $slug) . '#comment-' . $commentId);
        exit;
    }

    if ($action === 'delete') {
        $commentId = isset($_POST['comment_id']) ? (int) $_POST['comment_id'] : 0;
        $redirectSlug = isset($_POST['slug']) ? (string) $_POST['slug'] : '';
        $commentService->deleteComment($commentId);
        header('Location: /post.php?slug=' . rawurlencode($redirectSlug));
        exit;
    }

    http_response_code(400);
    echo 'Unknown action';
} catch (Throwable $e) {
    http_response_code(400);
    echo $e->getMessage();
}
