<?php

declare(strict_types=1);

use Blog\View;

/** @var array<int, array<string, mixed>> $posts */
?>
<section class="post-list">
    <h1>Последние посты</h1>
    <?php if ($posts === []): ?>
        <p>Пока нет опубликованных постов.</p>
    <?php endif; ?>
    <?php foreach ($posts as $post): ?>
        <article class="post-card">
            <h2><a href="/post.php?slug=<?= View::e($post['slug']) ?>"><?= View::e($post['title']) ?></a></h2>
            <p class="meta">
                <?= View::e($post['author_name']) ?>
                ·
                <?= View::e((string) $post['published_at']) ?>
            </p>
        </article>
    <?php endforeach; ?>
</section>
