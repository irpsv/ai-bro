<?php

declare(strict_types=1);

use Blog\View;

/** @var string|null $error */
?>
<section class="login">
    <h1>Вход</h1>
    <?php if ($error !== null): ?>
        <p class="error"><?= View::e($error) ?></p>
    <?php endif; ?>
    <form method="post" action="/login.php">
        <label>
            Email
            <input type="email" name="email" required autocomplete="username">
        </label>
        <label>
            Пароль
            <input type="password" name="password" required autocomplete="current-password">
        </label>
        <button type="submit">Войти</button>
    </form>
</section>
