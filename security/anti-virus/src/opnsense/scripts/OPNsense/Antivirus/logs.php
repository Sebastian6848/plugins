#!/usr/local/bin/php
<?php

$mode = $argv[1] ?? 'blocked';
$logfiles = [
    '/var/log/system/latest.log' => 'syslog',
    '/var/log/c-icap/server.log' => 'c-icap',
    '/var/log/c-icap/access.log' => 'c-icap'
];
$limit = 5000;

function format_log_time($timestamp)
{
    return $timestamp !== false ? date('Y-m-d H:i:s', $timestamp) : '';
}

function parse_log_line($line, $source, $logfile = null)
{
    if ($source === 'syslog' && preg_match('/^<\d+>1\s+(\S+)\s+\S+\s+(\S+)\s+\S+\s+\S+\s+(?:\[.*?\]\s+)?(.*)$/', $line, $matches)) {
        return [
            'time' => str_replace('T', ' ', preg_replace('/\+.*$/', '', $matches[1])),
            'program' => $matches[2],
            'message' => trim($matches[3]),
            'raw' => trim($line)
        ];
    }

    if (preg_match('/\[(\d{1,2}\/[A-Za-z]{3}\/\d{4}:\d{2}:\d{2}:\d{2}\s+[+-]\d{4})\]/', $line, $matches)) {
        $time = \DateTime::createFromFormat('d/M/Y:H:i:s O', $matches[1]);
        return [
            'time' => $time !== false ? $time->format('Y-m-d H:i:s') : '',
            'program' => $source,
            'message' => trim($line),
            'raw' => trim($line)
        ];
    }

    if (preg_match('/^\[?(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})\]?\s+(.*)$/', $line, $matches)) {
        return [
            'time' => str_replace('T', ' ', $matches[1]),
            'program' => $source,
            'message' => trim($matches[2]),
            'raw' => trim($line)
        ];
    }

    if (preg_match('/^([A-Za-z]{3}\s+[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})[:,]?\s*(.*)$/', $line, $matches)) {
        return [
            'time' => format_log_time(strtotime($matches[1])),
            'program' => $source,
            'message' => trim($matches[2]),
            'raw' => trim($line)
        ];
    }

    if (preg_match('/^([A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(.*)$/', $line, $matches)) {
        return [
            'time' => format_log_time(strtotime($matches[1] . ' ' . date('Y'))),
            'program' => $source,
            'message' => trim($matches[2]),
            'raw' => trim($line)
        ];
    }

    return [
        'time' => $logfile !== null && is_readable($logfile) ? format_log_time(filemtime($logfile)) : '',
        'program' => $source,
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
        'uuid' => sha1($entry['raw']),
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
$seen = [];
foreach ($logfiles as $logfile => $source) {
    if (is_readable($logfile)) {
        $lines = file($logfile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (is_array($lines)) {
            foreach (array_slice($lines, -$limit) as $line) {
                $entry = parse_log_line($line, $source, $logfile);
                $payload = strtolower($entry['program'] . ' ' . $entry['message']);

                if ($mode === 'blocked') {
                    $blocked = parse_blocked_event($entry);
                    if ($blocked !== null && !isset($seen[$blocked['uuid']])) {
                        $seen[$blocked['uuid']] = true;
                        $rows[] = $blocked;
                    }
                } elseif (
                    strpos($payload, 'antivirus-c-icap') !== false ||
                    strpos($payload, 'c-icap') !== false ||
                    strpos($payload, 'clamd') !== false ||
                    strpos($payload, 'freshclam') !== false ||
                    strpos($payload, 'virus detected') !== false ||
                    strpos($payload, 'failed to scan web object') !== false ||
                    strpos($payload, 'clamd_scan') !== false ||
                    strpos($payload, 'avscan') !== false ||
                    strpos($payload, 'eicar') !== false
                ) {
                    $uuid = sha1($entry['raw']);
                    if (!isset($seen[$uuid])) {
                        $seen[$uuid] = true;
                        $rows[] = [
                            'uuid' => $uuid,
                            'time' => $entry['time'],
                            'program' => $entry['program'],
                            'message' => $entry['message']
                        ];
                    }
                }
            }
        }
    }
}

$rows = array_reverse($rows);
echo json_encode(['rows' => $rows, 'total' => count($rows)]);
