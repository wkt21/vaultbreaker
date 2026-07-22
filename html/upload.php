<?php
require __DIR__ . '/config.php';
session_start();

if (empty($_SESSION['auth'])) {
    header('Location: login.php');
    exit;
}

$msg = '';
if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
    $allowed_types = ['image/jpeg', 'image/png', 'image/gif'];

    // VULNERABILITY: the only validation is the client-controlled MIME type
    // ($_FILES['file']['type']). There is no extension allowlist and no magic-
    // byte check, so a PHP web shell renamed with Content-Type: image/jpeg
    // is accepted and later executed under /uploads/.
    if (in_array($_FILES['file']['type'], $allowed_types, true)) {
        $name = basename($_FILES['file']['name']);
        $dest = UPLOAD_DIR . $name;
        if (move_uploaded_file($_FILES['file']['tmp_name'], $dest)) {
            $msg = 'Upload successful. Access it at /uploads/' . htmlspecialchars($name);
        } else {
            $msg = 'Upload failed: could not move file.';
        }
    } else {
        $msg = 'Rejected: only image types are allowed.';
    }
}
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>FileVault - Upload</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="wrap">
    <header><h1>FileVault</h1><p class="tag">Upload result</p></header>
    <nav>
        <a href="admin.php">Console</a>
        <a href="logout.php">Logout</a>
    </nav>
    <section class="card">
        <h2>Upload status</h2>
        <p><?= htmlspecialchars($msg) ?></p>
        <p><a href="admin.php">Back to console</a></p>
    </section>
</div>
</body>
</html>
