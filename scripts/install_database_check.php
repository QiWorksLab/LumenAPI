<?php
/**
 * LumenAPI deployment database preflight.
 * Exit 0: database exists (or was created) and is empty.
 * Exit 10: MySQL is not reachable/authentication failed (retryable during startup).
 * Exit 20: target database is not empty.
 * Exit 21: database is missing and could not be created.
 */
$host = (string) getenv('DB_HOST');
$port = (int) (getenv('DB_PORT') ?: 3306);
$name = (string) getenv('DB_NAME');
$user = (string) getenv('DB_USER');
$pass = (string) getenv('DB_PASS');
$create = (string) getenv('LUMEN_INSTALL_CREATE_DB') === '1';

if ($host === '' || $name === '' || $user === '' || !preg_match('/^[A-Za-z0-9_]+$/', $name)) {
    fwrite(STDERR, "DB_CONFIG_INVALID\n");
    exit(21);
}

$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_TIMEOUT => 5,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
];

try {
    $server = new PDO(sprintf('mysql:host=%s;port=%d;charset=utf8mb4', $host, $port), $user, $pass, $options);
} catch (Throwable $e) {
    fwrite(STDERR, "DB_CONNECT_FAILED\n");
    exit(10);
}

$exists = false;
try {
    $st = $server->prepare('SELECT 1 FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ? LIMIT 1');
    $st->execute([$name]);
    $exists = (bool) $st->fetchColumn();
} catch (Throwable $e) {
    fwrite(STDERR, "DB_DISCOVERY_FAILED\n");
    exit(10);
}

if (!$exists) {
    if (!$create) {
        fwrite(STDERR, "DB_NOT_FOUND\n");
        exit(21);
    }
    try {
        $quoted = '`' . str_replace('`', '``', $name) . '`';
        $server->exec("CREATE DATABASE {$quoted} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
        echo "DB_CREATED\n";
    } catch (Throwable $e) {
        fwrite(STDERR, "DB_CREATE_DENIED\n");
        exit(21);
    }
}

try {
    $db = new PDO(sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $host, $port, $name), $user, $pass, $options);
    $count = (int) $db->query('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()')->fetchColumn();
} catch (Throwable $e) {
    fwrite(STDERR, "DB_SELECT_FAILED\n");
    exit(10);
}

if ($count !== 0) {
    fwrite(STDERR, "DB_NOT_EMPTY tables={$count}\n");
    exit(20);
}

echo "DB_EMPTY\n";
