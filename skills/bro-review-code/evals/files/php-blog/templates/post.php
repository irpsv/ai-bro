<?php

declare(strict_types=1);

use Blog\View;

/** @var array<string, mixed> $post */
/** @var array<int, array<string, mixed>> $comments */
/** @var \Blog\Auth $auth */
/** @var string $csrfToken */
/** @var string|null $search */
?>
<article class="post">
    <h1><?= View::e($post['title']) ?></h1>
    <p class="meta">
        <?= View::e($post['author_name']) ?>
        ·
        <?= View::e((string) $post['published_at']) ?>
    </p>
    <div class="body">
        <?= nl2br(View::e($post['body'])) ?>
    </div>
</article>

<section class="comments" id="comments">
    <h2>Комментарии (<?= count($comments) ?>)</h2>

    <form method="get" action="/post.php" class="comment-search">
        <input type="hidden" name="slug" value="<?= View::e($post['slug']) ?>">
        <label>
            Поиск по комментариям
            <input type="search" name="q" value="<?= View::e($search) ?>" placeholder="фрагмент текста">
        </label>
        <button type="submit">Найти</button>
    </form>

    <?php foreach ($comments as $comment): ?>
        <div class="comment" id="comment-<?= (int) $comment['id'] ?>">
            <div class="comment-meta">
                <strong><?= View::e($comment['author_name'] ?? 'user') ?></strong>
                <time><?= View::e((string) $comment['created_at']) ?></time>
            </div>
            <div class="comment-body"><?= $comment['body'] ?></div>

            <?php if ($auth->userId() !== null): ?>
                <form method="post" action="/comment.php" class="comment-delete">
                    <input type="hidden" name="action" value="delete">
                    <input type="hidden" name="comment_id" value="<?= (int) $comment['id'] ?>">
                    <input type="hidden" name="slug" value="<?= View::e($post['slug']) ?>">
                    <input type="hidden" name="csrf_token" value="<?= View::e($csrfToken) ?>">
                    <button type="submit">Удалить</button>
                </form>
            <?php endif; ?>
        </div>
    <?php endforeach; ?>

    <?php if ($auth->userId() !== null): ?>
        <form method="post" action="/comment.php" class="comment-form">
            <input type="hidden" name="action" value="create">
            <input type="hidden" name="post_id" value="<?= (int) $post['id'] ?>">
            <input type="hidden" name="csrf_token" value="<?= View::e($csrfToken) ?>">
            <label>
                Ваш комментарий
                <textarea name="body" rows="4" required maxlength="5000"></textarea>
            </label>
            <button type="submit">Отправить</button>
        </form>
    <?php else: ?>
        <p><a href="/login.php">Войдите</a>, чтобы оставить комментарий.</p>
    <?php endif; ?>
</section>
