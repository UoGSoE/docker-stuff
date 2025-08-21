#!/usr/bin/env php
<?php
declare(strict_types=1);

/**
 * Options:
 *   --env-var=NAME      Read local env text from environment variable NAME (default: PROD_DOTENV).
 *   --file=PATH         Read local env from a file instead (overrides --env-var). Default fallback: .env
 *   --show-extra        Also list keys you have locally that aren't in the official example (advisory).
 */

error_reporting(E_ALL);

$opts = [
    'env-var::',  // optional value
    'file::',     // optional value
    'show-extra', // flag
];
$args = getopt('', $opts);
$envVar = $args['env-var'] ?? 'PROD_DOTENV';
$fileOpt = $args['file'] ?? null;
$showExtra = array_key_exists('show-extra', $args);

/* ---------- Helpers ---------- */

function readJson(string $path): ?array {
    if (!is_file($path)) return null;
    $raw = file_get_contents($path);
    if ($raw === false) return null;
    $data = json_decode($raw, true);
    return is_array($data) ? $data : null;
}

function detectLaravelMajor(): ?int {
    // 1) composer.lock exact version
    $lock = readJson('composer.lock');
    if ($lock && isset($lock['packages']) && is_array($lock['packages'])) {
        foreach ($lock['packages'] as $pkg) {
            if (($pkg['name'] ?? null) === 'laravel/framework') {
                $v = (string)($pkg['version'] ?? '');
                if (preg_match('/(\d+)\./', $v, $m)) {
                    return (int)$m[1];
                }
            }
        }
    }

    // 2) composer.json constraint
    $comp = readJson('composer.json');
    if ($comp && isset($comp['require']['laravel/framework'])) {
        $constraint = (string)$comp['require']['laravel/framework'];
        // prefer numbers before . or * (e.g. 12.*, ^11.0)
        if (preg_match_all('/(?<!\d)(\d{1,2})(?=[\.\*])/', $constraint, $m) && $m[1]) {
            return max(array_map('intval', $m[1]));
        }
        // fallback: any standalone number
        if (preg_match_all('/(?<!\d)(\d{1,2})(?!\d)/', $constraint, $m2) && $m2[1]) {
            return max(array_map('intval', $m2[1]));
        }
    }
    return null;
}

function tryFetch(string $url): ?string {
    // Prefer curl if available; fallback to file_get_contents with stream context.
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 20,
            CURLOPT_USERAGENT => 'env-checker/1.0',
        ]);
        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($body !== false && $code >= 200 && $code < 300) return $body;
        return null;
    } else {
        $ctx = stream_context_create([
            'http' => [
                'method' => 'GET',
                'header' => "User-Agent: env-checker/1.0\r\n",
                'timeout' => 20
            ],
            'ssl' => ['verify_peer' => true, 'verify_peer_name' => true]
        ]);
        $body = @file_get_contents($url, false, $ctx);
        if ($body !== false) return $body;
        return null;
    }
}

function fetchLaravelEnvExample(?int $major): string {
    $candidates = [];
    if ($major !== null) {
        $candidates[] = "https://raw.githubusercontent.com/laravel/laravel/{$major}.x/.env.example";
    }
    // Fallbacks in case major is unknown or branch naming changes
    $candidates[] = "https://raw.githubusercontent.com/laravel/laravel/main/.env.example";
    $candidates[] = "https://raw.githubusercontent.com/laravel/laravel/master/.env.example";

    foreach ($candidates as $url) {
        $body = tryFetch($url);
        if ($body !== null) return $body;
    }
    fwrite(STDERR, "ERROR: Failed to fetch Laravel .env.example from GitHub (tried: ".implode(', ', $candidates).")\n");
    exit(2);
}

function extractKeys(string $envText): array {
    $keys = [];
    $lines = preg_split('/\R/', $envText);
    $re = '/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/';
    foreach ($lines as $line) {
        $t = trim($line);
        if ($t === '' || str_starts_with($t, '#')) continue;
        if (preg_match($re, $t, $m)) {
            $keys[$m[1]] = true;
        }
    }
    return array_keys($keys);
}

function getLocalEnvText(?string $fileOpt, string $envVar): string {
    if ($fileOpt) {
        if (!is_file($fileOpt)) {
            fwrite(STDERR, "ERROR: --file provided but not found: {$fileOpt}\n");
            exit(3);
        }
        $txt = file_get_contents($fileOpt);
        if ($txt === false) {
            fwrite(STDERR, "ERROR: Could not read file: {$fileOpt}\n");
            exit(3);
        }
        return $txt;
    }

    $fromVar = getenv($envVar);
    if ($fromVar !== false && $fromVar !== '') {
        return $fromVar;
    }

    if (is_file('.env')) {
        $txt = file_get_contents('.env');
        if ($txt !== false) return $txt;
    }

    fwrite(STDERR, "ERROR: No env provided. Set \${$envVar}, or use --file=PATH, or ensure .env exists.\n");
    exit(3);
}

/* ---------- Main ---------- */

$major = detectLaravelMajor();
$official = fetchLaravelEnvExample($major);
$local = getLocalEnvText($fileOpt, $envVar);

$upstreamKeys = extractKeys($official);
$localKeys    = extractKeys($local);

$upstreamSet = array_fill_keys($upstreamKeys, true);
$localSet    = array_fill_keys($localKeys, true);

// Missing = in upstream but not local
$missing = array_values(array_diff(array_keys($upstreamSet), array_keys($localSet)));
sort($missing);

echo "Detected Laravel major: ".($major !== null ? $major : 'unknown (using fallback branch)').PHP_EOL;
echo "Upstream keys: ".count($upstreamKeys)." | Local keys: ".count($localKeys).PHP_EOL.PHP_EOL;

if (!empty($missing)) {
    echo "Missing keys (present in official .env.example, not in your local env):".PHP_EOL;
    foreach ($missing as $k) echo "  - {$k}".PHP_EOL;
}

if ($showExtra) {
    $extra = array_values(array_diff(array_keys($localSet), array_keys($upstreamSet)));
    sort($extra);
    echo PHP_EOL."Extra local keys (not in official .env.example):".PHP_EOL;
    if ($extra) {
        foreach ($extra as $k) echo "  - {$k}".PHP_EOL;
    } else {
        echo "  (none)".PHP_EOL;
    }
}

if (!empty($missing)) {
    exit(1); // fail job
}

echo "✅ No missing keys. Your env has all keys from the official .env.example.".PHP_EOL;

