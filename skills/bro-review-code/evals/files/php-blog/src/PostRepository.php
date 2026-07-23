<?php

declare(strict_types=1);

namespace Blog;

use PDO;

final class PostRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function findPublishedBySlug(string $slug): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT p.id, p.author_id, p.title, p.slug, p.body, p.published_at, u.display_name AS author_name
             FROM posts p
             INNER JOIN users u ON u.id = p.author_id
             WHERE p.slug = ? AND p.status = \'published\'
             LIMIT 1'
        );
        $stmt->execute([$slug]);
        $row = $stmt->fetch();

        return $row ?: null;
    }

    public function listPublished(int $limit = 20, int $offset = 0): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT p.id, p.title, p.slug, p.published_at, u.display_name AS author_name
             FROM posts p
             INNER JOIN users u ON u.id = p.author_id
             WHERE p.status = \'published\'
             ORDER BY p.published_at DESC
             LIMIT ? OFFSET ?'
        );
        $stmt->bindValue(1, $limit, PDO::PARAM_INT);
        $stmt->bindValue(2, $offset, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll();
    }

    public function findById(int $postId): ?array
    {
        $stmt = $this->pdo->prepare('SELECT id, author_id, title, slug, status FROM posts WHERE id = ? LIMIT 1');
        $stmt->execute([$postId]);
        $row = $stmt->fetch();

        return $row ?: null;
    }
}
