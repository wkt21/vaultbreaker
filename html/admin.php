<?php
require __DIR__ . '/config.php';
session_start();

if (empty($_SESSION['auth'])) {
    header('Location: login.php');
    exit;
}

// Flag 2 is provisioned only in the runtime environment; it is never written
// to a source file the LFI can disclose. Displayed solely to authenticated
// administrators as proof of credential compromise. Apache SetEnv populates
// both getenv() and $_SERVER under mod_php; check both for robustness.
$flag2 = getenv('VAULT_FLAG2') ?: ($_SERVER['VAULT_FLAG2'] ?? 'FLAG2_UNAVAILABLE');
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>FileVault - Admin Console</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="wrap">
    <header><h1>FileVault</h1><p class="tag">Administrative console</p></header>
    <nav>
        <a href="index.php">Home</a>
        <a href="admin.php">Console</a>
        <a href="logout.php">Logout</a>
    </nav>
    <section class="card">
        <h2>Welcome, <?= htmlspecialchars($_SESSION['user'] ?? 'admin') ?></h2>
        <p>Credential compromise verified.</p>
        <div class="flag">Flag 2: <?= htmlspecialchars($flag2) ?></div>
    </section>
    <section class="card">
        <h2>Secure file upload</h2>
        <p>Upload supporting documents. Accepted types: JPEG, PNG, GIF.</p>
        <form method="post" action="upload.php" enctype="multipart/form-data">
            <input type="file" name="file">
            <button type="submit">Upload</button>
        </form>
        <p class="hint">Recent uploads are served from <code>/uploads/</code>.</p>
    </section>
</div>
</body>
</html>
