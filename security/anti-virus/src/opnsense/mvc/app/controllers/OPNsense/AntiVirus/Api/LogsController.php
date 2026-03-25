<?php

namespace OPNsense\AntiVirus\Api;

use OPNsense\Base\ApiControllerBase;

class LogsController extends ApiControllerBase
{
    private const EVENTS_FILE = '/var/log/antivirus_events.log';
    private const STATS_FILE = '/var/run/antivirus/stats.json';

    private function requestInt(string $name, int $default): int
    {
        $value = $this->request->getPost($name, 'int', null);
        if ($value === null || $value === '') {
            $value = $this->request->getQuery($name, 'int', $default);
        }

        return is_numeric($value) ? (int)$value : $default;
    }

    private function loadTailEvents(int $maxLines): array
    {
        if (!is_readable(self::EVENTS_FILE)) {
            return [];
        }

        $file = new \SplFileObject(self::EVENTS_FILE, 'r');
        $file->seek(PHP_INT_MAX);
        $last = $file->key();
        $start = max(0, $last - $maxLines + 1);
        $rows = [];

        for ($lineNo = $start; $lineNo <= $last; $lineNo++) {
            $file->seek($lineNo);
            $line = trim((string)$file->current());
            if ($line === '') {
                continue;
            }

            $decoded = json_decode($line, true);
            if (!is_array($decoded)) {
                continue;
            }

            $rows[] = [
                'timestamp' => (string)($decoded['timestamp'] ?? ''),
                'sha256' => (string)($decoded['sha256'] ?? ''),
                'result' => (string)($decoded['result'] ?? ''),
                'signature' => (string)($decoded['signature'] ?? ''),
                'source_ip' => (string)($decoded['source_ip'] ?? ''),
                'file_path' => (string)($decoded['file_path'] ?? ''),
            ];
        }

        return array_reverse($rows);
    }

    public function searchAction()
    {
        $limit = max(100, min(10000, $this->requestInt('limit', 3000)));

        return $this->searchRecordsetBase(
            $this->loadTailEvents($limit),
            ['timestamp', 'sha256', 'result', 'signature', 'source_ip', 'file_path']
        );
    }

    public function statsAction()
    {
        if (!is_readable(self::STATS_FILE)) {
            return ['status' => 'ok', 'stats' => []];
        }

        $decoded = json_decode((string)file_get_contents(self::STATS_FILE), true);
        if (!is_array($decoded)) {
            $decoded = [];
        }

        return ['status' => 'ok', 'stats' => $decoded];
    }
}