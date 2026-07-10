#!/usr/local/bin/php
<?php

require_once('/usr/local/opnsense/mvc/app/library/OPNsense/AppIdentification/Backend/BackendCore.php');

if (($argv[1] ?? '') === '--request') {
    $json = base64_decode((string)($argv[2] ?? ''), true);
    $request = json_decode((string)$json, true);
    if (!is_array($request)) {
        $request = ['action' => 'invalid'];
    }
} elseif (($argv[1] ?? '') === '--legacy-generate') {
    $request = [
        'action' => 'generate',
        'config' => [
            'enabled' => $argv[2] ?? '0',
            'interfaces' => $argv[3] ?? '',
            'http_port' => $argv[4] ?? '3000',
            'https_port' => $argv[5] ?? '',
            'dns_mode' => $argv[6] ?? '0',
            'certificate' => $argv[7] ?? '',
            'max_flows' => $argv[8] ?? '200000',
            'max_hosts' => $argv[9] ?? '100000',
            'local_networks' => $argv[10] ?? '',
            'extra_options' => $argv[11] ?? '',
        ],
    ];
} elseif (($argv[1] ?? '') === '--legacy-write') {
    $payload = json_decode((string)($argv[2] ?? ''), true);
    $rules = [];
    if (is_array($payload) && isset($payload['rules']) && is_array($payload['rules'])) {
        $rules = $payload['rules'];
    } elseif (is_array($payload) && isset($payload['data']) && is_array($payload['data'])) {
        $rules = $payload['data'];
    } elseif (is_array($payload)) {
        $rules = $payload;
    }
    $request = [
        'action' => 'write_rules',
        'rules' => $rules,
    ];
} else {
    $request = ['action' => $argv[1] ?? 'status'];
}

$result = (new OPNsense\AppIdentification\Backend\BackendCore())->dispatch($request);
echo json_encode($result, JSON_UNESCAPED_SLASHES) . PHP_EOL;
exit(($result['status'] ?? '') === 'error' ? 1 : 0);
