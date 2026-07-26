<?php

declare(strict_types=1);

namespace Blog;

final class View
{
    public static function render(string $template, array $data = []): void
    {
        extract($data, EXTR_SKIP);
        $templateFile = dirname(__DIR__) . '/templates/' . $template . '.php';
        if (!is_file($templateFile)) {
            throw new \RuntimeException('Template not found: ' . $template);
        }

        require dirname(__DIR__) . '/templates/layout.php';
    }

    public static function e(?string $value): string
    {
        return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
}
