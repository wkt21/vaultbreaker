<?php
require __DIR__ . '/config.php';

// ------------------------------------------------------------------
// Document viewer.
// Reads a filename from ?file= and "renders" it.
//
// VULNERABILITY: Local File Inclusion (LFI).
//   - The '..' filter blocks relative directory traversal.
//   - But absolute paths and PHP stream wrappers are NOT blocked, and the
//     parameter is passed straight to include() with no jail check.
//
// Intended techniques:
//   view.php?file=/etc/passwd
//   view.php?file=/var/www/flag1.txt
//   view.php?file=php://filter/convert.base64-encode/resource=config.php
// ------------------------------------------------------------------

$file = isset($_GET['file']) ? $_GET['file'] : 'default.txt';

if (strpos($file, '..') !== false) {
    http_response_code(403);
    exit('Invalid request.');
}

// Resolve a friendly name to a page on disk; otherwise include the raw path.
$localPath = __DIR__ . '/pages/' . basename($file);
$content = '';
if (is_file($localPath)) {
    $content = file_get_contents($localPath);
} else {
    // BUG: arbitrary include of an attacker-controlled path.
    ob_start();
    include($file);
    $content = ob_get_clean();
}
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>FileVault - Viewer</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="wrap">
    <header><h1>FileVault</h1><p class="tag">Document viewer</p></header>
    <nav>
        <a href="index.php">Home</a>
        <a href="view.php?file=default.txt">Docs</a>
        <a href="login.php">Staff Login</a>
    </nav>
    <section class="card">
        <h2>Now viewing: <?= htmlspecialchars($file) ?></h2>
        <pre class="doc"><?= htmlspecialchars($content) ?></pre>
    </section>
</div>
</body>
</html>
