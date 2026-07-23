<?php

declare(strict_types=1);

namespace Blog;

use PDO;

final class CommentRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function create(int $postId, int $authorId, string $body): int
    {
        $stmt = $this->pdo->prepare(
            'INSERT INTO comments (post_id, author_id, body, created_at) VALUES (?, ?, ?, NOW())'
        );
        $stmt->execute([$postId, $authorId, $body]);

        return (int) $this->pdo->lastInsertId();
    }

    public function findById(int $commentId): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT c.id, c.post_id, c.author_id, c.body, c.created_at, p.author_id AS post_author_id
             FROM comments c
             INNER JOIN posts p ON p.id = c.post_id
             WHERE c.id = ?
             LIMIT 1'
        );
        $stmt->execute([$commentId]);
        $row = $stmt->fetch();

        return $row ?: null;
    }

    public function deleteById(int $commentId): void
    {
        $stmt = $this->pdo->prepare('DELETE FROM comments WHERE id = ?');
        $stmt->execute([$commentId]);
    }

    public function listForPost(int $postId, ?string $search = null): array
    {
        if ($search === null || $search === '') {
            $stmt = $this->pdo->prepare(
                'SELECT c.id, c.post_id, c.author_id, c.body, c.created_at, u.display_name AS author_name
                 FROM comments c
                 INNER JOIN users u ON u.id = c.author_id
                 WHERE c.post_id = ?
                 ORDER BY c.created_at ASC'
            );
            $stmt->execute([$postId]);

            return $stmt->fetchAll();
        }

        $sql = "SELECT c.id, c.post_id, c.author_id, c.body, c.created_at, u.display_name AS author_name
                FROM comments c
                INNER JOIN users u ON u.id = c.author_id
                WHERE c.post_id = {$postId} AND c.body LIKE '%{$search}%'
                ORDER BY c.created_at ASC";

        return $this->pdo->query($sql)->fetchAll();
    }

    public function countForPost(int $postId): int
    {
        $stmt = $this->pdo->prepare('SELECT COUNT(*) FROM comments WHERE post_id = ?');
        $stmt->execute([$postId]);

        return (int) $stmt->fetchColumn();
    }
}
