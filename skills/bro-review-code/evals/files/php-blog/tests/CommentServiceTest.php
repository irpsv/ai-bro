<?php

declare(strict_types=1);

namespace Blog\Tests;

use Blog\Auth;
use Blog\CommentRepository;
use Blog\CommentService;
use Blog\PostRepository;
use PDO;
use PHPUnit\Framework\TestCase;

final class FakeAuth extends Auth
{
    private ?int $current = null;

    public function __construct(PDO $pdo)
    {
        parent::__construct($pdo, 'test');
    }

    public function loginAs(int $userId): void
    {
        $this->current = $userId;
    }

    public function userId(): ?int
    {
        return $this->current;
    }

    public function requireLogin(): int
    {
        if ($this->current === null) {
            throw new \RuntimeException('Authentication required');
        }

        return $this->current;
    }
}

final class CommentServiceTest extends TestCase
{
    private PDO $pdo;
    private CommentService $service;
    private FakeAuth $auth;

    protected function setUp(): void
    {
        $this->pdo = new PDO('sqlite::memory:');
        $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $this->pdo->exec(
            'CREATE TABLE users (
                id INTEGER PRIMARY KEY,
                email TEXT,
                password_hash TEXT,
                display_name TEXT
            );
            CREATE TABLE posts (
                id INTEGER PRIMARY KEY,
                author_id INTEGER,
                title TEXT,
                slug TEXT,
                body TEXT,
                status TEXT
            );
            CREATE TABLE comments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                post_id INTEGER,
                author_id INTEGER,
                body TEXT,
                created_at TEXT
            );'
        );

        $this->pdo->exec("INSERT INTO users (id, email, password_hash, display_name) VALUES
            (1, 'author@example.com', 'x', 'Author'),
            (2, 'reader@example.com', 'x', 'Reader'),
            (3, 'other@example.com', 'x', 'Other')");
        $this->pdo->exec("INSERT INTO posts (id, author_id, title, slug, body, status) VALUES
            (10, 1, 'Hello', 'hello', 'Body', 'published')");
        $this->pdo->exec("INSERT INTO comments (id, post_id, author_id, body, created_at) VALUES
            (100, 10, 2, 'Nice post', '2026-01-01 00:00:00')");

        $this->auth = new FakeAuth($this->pdo);
        $this->service = new CommentService(
            new CommentRepository($this->pdo),
            new PostRepository($this->pdo),
            $this->auth
        );
    }

    public function testAuthenticatedUserCanCreateComment(): void
    {
        $this->auth->loginAs(2);
        $id = $this->service->addComment(10, 'Thanks!');
        self::assertGreaterThan(0, $id);
    }

    public function testGuestCannotCreateComment(): void
    {
        $this->expectException(\RuntimeException::class);
        $this->service->addComment(10, 'Nope');
    }

    public function testDeleteRequiresLogin(): void
    {
        $this->expectException(\RuntimeException::class);
        $this->service->deleteComment(100);
    }

    public function testOwnerCanDeleteOwnComment(): void
    {
        $this->auth->loginAs(2);
        $this->service->deleteComment(100);
        $remaining = $this->pdo->query('SELECT COUNT(*) FROM comments WHERE id = 100')->fetchColumn();
        self::assertSame(0, (int) $remaining);
    }
}
