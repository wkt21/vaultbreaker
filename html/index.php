<?php
require __DIR__ . '/config.php';

// Public landing page. Lists the documentation pages that the "viewer" below
// renders through the ?file= parameter.
$pages = ['default.txt', 'about.txt', 'notes.txt'];
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>FileVault Secure Documents</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="wrap">
    <header>
        <h1>FileVault</h1>
        <p class="tag">Secure document storage for internal teams.</p>
    </header>
    <nav>
        <a href="index.php">Home</a>
        <a href="view.php?file=default.txt">Docs</a>
        <a href="login.php">Staff Login</a>
    </nav>
    <section class="card">
        <h2>Available documents</h2>
        <ul>
            <?php foreach ($pages as $p): ?>
                <li><a href="view.php?file=<?= htmlspecialchars($p) ?>"><?= htmlspecialchars($p) ?></a></li>
            <?php endforeach; ?>
        </ul>
        <p>Use the document viewer to read any file in our knowledge base.</p>
    </section>
</div>
</body>
</html>
