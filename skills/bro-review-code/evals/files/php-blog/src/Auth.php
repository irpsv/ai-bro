<?php

declare(strict_types=1);

namespace Blog;

use PDO;

class Auth
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly string $sessionName
    ) {
    }

    public function startSession(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) {
            return;
        }

        session_name($this->sessionName);
        session_start();
    }

    public function attempt(string $email, string $password): bool
    {
        $stmt = $this->pdo->prepare('SELECT id, password_hash, display_name FROM users WHERE email = ? LIMIT 1');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password_hash'])) {
            return false;
        }

        $this->startSession();
        session_regenerate_id(true);
        $_SESSION['user_id'] = (int) $user['id'];
        $_SESSION['display_name'] = $user['display_name'];

        return true;
    }

    public function logout(): void
    {
        $this->startSession();
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'], (bool) $params['secure'], (bool) $params['httponly']);
        }
        session_destroy();
    }

    public function userId(): ?int
    {
        $this->startSession();
        return isset($_SESSION['user_id']) ? (int) $_SESSION['user_id'] : null;
    }

    public function displayName(): ?string
    {
        $this->startSession();
        return $_SESSION['display_name'] ?? null;
    }

    public function requireLogin(): int
    {
        $userId = $this->userId();
        if ($userId === null) {
            http_response_code(401);
            throw new \RuntimeException('Authentication required');
        }

        return $userId;
    }

    public function csrfToken(): string
    {
        $this->startSession();
        if (empty($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }

        return $_SESSION['csrf_token'];
    }

    public function validateCsrf(?string $token): bool
    {
        $this->startSession();
        $expected = $_SESSION['csrf_token'] ?? '';
        return is_string($token) && $expected !== '' && hash_equals($expected, $token);
    }
}
