#!/usr/local/bin/php
<?php

$mode = $argv[1] ?? 'blocked';
$logfile = '/var/log/system/latest.log';
$limit = 5000;

function parse_syslog_line($line)
{
    if (preg_match('/^<\d+>1\s+(\S+)\s+\S+\s+(\S+)\s+\S+\s+\S+\s+(?:\[.*?\]\s+)?(.*)$/', $line, $matches)) {
        return [
            'time' => str_replace('T', ' ', preg_replace('/\+.*$/', '', $matches[1])),
            'program' => $matches[2],
            'message' => trim($matches[3]),
            'raw' => trim($line)
        ];
    }

    return [
        'time' => '',
        'program' => '',
        'message' => trim($line),
        'raw' => trim($line)
    ];
}

function parse_blocked_event($entry)
{
    $message = $entry['message'];
    if (stripos($message, 'VIRUS DETECTED:') === false) {
        return null;
    }

    $threat = '-';
    $client = '-';
    $user = '-';
    $url = '-';

    if (preg_match('/VIRUS DETECTED:\s*(.*?)\s*,\s*http client ip:/i', $message, $matches)) {
        $threat = trim($matches[1]);
    }
    if (preg_match('/http client ip:\s*(.*?)\s*,\s*http user:/i', $message, $matches)) {
        $client = trim($matches[1]);
    }
    if (preg_match('/http user:\s*(.*?)\s*,\s*http url:/i', $message, $matches)) {
        $user = trim($matches[1]);
    }
    if (preg_match('/http url:\s*(.*?)\s*$/i', $message, $matches)) {
        $url = trim($matches[1]);
    }

    return [
        'time' => $entry['time'],
        'client' => $client,
        'user' => $user,
        'threat' => $threat,
        'url' => $url,
        'action' => 'blocked',
        'source' => 'c-icap',
        'raw' => $entry['raw']
    ];
}

$rows = [];
if (is_readable($logfile)) {
    $lines = file($logfile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (is_array($lines)) {
        foreach (array_slice($lines, -$limit) as $line) {
            $entry = parse_syslog_line($line);
            $payload = strtolower($entry['program'] . ' ' . $entry['message']);

            if ($mode === 'blocked') {
                $blocked = parse_blocked_event($entry);
                if ($blocked !== null) {
                    $rows[] = $blocked;
                }
            } elseif (
                strpos($payload, 'antivirus-c-icap') !== false ||
                strpos($payload, 'virus detected') !== false ||
                strpos($payload, 'failed to scan web object') !== false ||
                strpos($payload, 'clamd_scan') !== false ||
                strpos($payload, 'avscan') !== false ||
                strpos($payload, 'eicar') !== false
            ) {
                $rows[] = [
                    'time' => $entry['time'],
                    'program' => $entry['program'],
                    'message' => $entry['message']
                ];
            }
        }
    }
}

$rows = array_reverse($rows);
echo json_encode(['rows' => $rows, 'total' => count($rows)]);
