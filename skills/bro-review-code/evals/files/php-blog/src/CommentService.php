<?php

declare(strict_types=1);

namespace Blog;

use InvalidArgumentException;

final class CommentService
{
    public function __construct(
        private readonly CommentRepository $comments,
        private readonly PostRepository $posts,
        private readonly Auth $auth
    ) {
    }

    public function addComment(int $postId, string $body): int
    {
        $userId = $this->auth->requireLogin();
        $post = $this->posts->findById($postId);

        if ($post === null || $post['status'] !== 'published') {
            throw new InvalidArgumentException('Post not found or not published');
        }

        $trimmed = trim($body);
        if ($trimmed === '') {
            throw new InvalidArgumentException('Comment body is required');
        }

        if (mb_strlen($trimmed) > 5000) {
            throw new InvalidArgumentException('Comment is too long');
        }

        return $this->comments->create($postId, $userId, $trimmed);
    }

    public function deleteComment(int $commentId): void
    {
        $this->auth->requireLogin();
        $comment = $this->comments->findById($commentId);

        if ($comment === null) {
            throw new InvalidArgumentException('Comment not found');
        }

        $this->comments->deleteById($commentId);
    }

    public function commentsForPost(int $postId, ?string $search = null): array
    {
        return $this->comments->listForPost($postId, $search);
    }

    public function commentsWithProfiles(int $postId): array
    {
        $items = $this->comments->listForPost($postId);
        $enriched = [];

        foreach ($items as $item) {
            $full = $this->comments->findById((int) $item['id']);
            if ($full === null) {
                continue;
            }

            $enriched[] = array_merge($item, [
                'post_author_id' => $full['post_author_id'],
            ]);
        }

        return $enriched;
    }
}
