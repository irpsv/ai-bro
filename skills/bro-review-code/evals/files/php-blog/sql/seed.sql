INSERT INTO users (id, email, password_hash, display_name) VALUES
(1, 'alice@example.com', '$2y$10$examplehashalicexxxxxxxxxxx', 'Alice'),
(2, 'bob@example.com', '$2y$10$examplehashbobxxxxxxxxxxxxx', 'Bob'),
(3, 'carol@example.com', '$2y$10$examplehashcarolxxxxxxxxxxx', 'Carol');

INSERT INTO posts (id, author_id, title, slug, body, status, published_at) VALUES
(1, 1, 'Welcome to the demo blog', 'welcome', 'First published post about building a small PHP blog.', 'published', '2026-01-10 10:00:00'),
(2, 1, 'Draft notes', 'draft-notes', 'This should stay invisible.', 'draft', NULL),
(3, 2, 'Comments feature design', 'comments-design', 'We need create, list, search and delete flows for comments.', 'published', '2026-02-01 12:30:00');

INSERT INTO comments (id, post_id, author_id, body, created_at) VALUES
(1, 1, 2, 'Congrats on the launch!', '2026-01-10 11:00:00'),
(2, 1, 3, 'Looking forward to more posts.', '2026-01-10 12:00:00'),
(3, 3, 1, 'Please keep XSS out of comment bodies.', '2026-02-01 13:00:00'),
(4, 3, 3, '<script>alert(1)</script> curious about sanitization', '2026-02-01 14:00:00');
