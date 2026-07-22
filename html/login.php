<?php
require __DIR__ . '/config.php';
session_start();

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = (string)($_POST['username'] ?? '');
    $password = (string)($_POST['password'] ?? '');

    try {
        $db = new PDO('sqlite:' . DB_PATH);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $stmt = $db->prepare('SELECT password_hash FROM users WHERE username = ?');
        $stmt->execute([$username]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        // Verify a SHA-256 hash of the supplied password.
        if ($row && hash('sha256', $password) === $row['password_hash']) {
            session_regenerate_id(true);
            $_SESSION['auth'] = true;
            $_SESSION['user'] = $username;
            header('Location: admin.php');
            exit;
        }
    } catch (Throwable $e) {
        // Fail closed -- do not leak the reason.
    }
    $error = 'Invalid credentials.';
}
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>FileVault - Staff Login</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="wrap">
    <header><h1>FileVault</h1><p class="tag">Staff authentication</p></header>
    <nav>
        <a href="index.php">Home</a>
        <a href="view.php?file=default.txt">Docs</a>
        <a href="login.php">Staff Login</a>
    </nav>
    <section class="card">
        <h2>Staff login</h2>
        <?php if ($error): ?><p class="err"><?= htmlspecialchars($error) ?></p><?php endif; ?>
        <form method="post" action="login.php">
            <label>Username<br><input type="text" name="username" autofocus></label><br><br>
            <label>Password<br><input type="password" name="password"></label><br><br>
            <button type="submit">Sign in</button>
        </form>
    </section>
</div>
</body>
</html>
