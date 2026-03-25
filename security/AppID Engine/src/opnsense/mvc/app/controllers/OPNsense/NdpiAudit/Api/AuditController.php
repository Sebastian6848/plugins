<?php

namespace OPNsense\NdpiAudit\Api;

use OPNsense\Base\ApiControllerBase;

class AuditController extends ApiControllerBase
{
    private const LOG_FILE = '/var/log/ndpi_audit.log';

    private function readTailLines(int $maxLines): array
    {
        if (!is_readable(self::LOG_FILE)) {
            return [];
        }

        $file = new \SplFileObject(self::LOG_FILE, 'r');
        $file->seek(PHP_INT_MAX);
        $last = $file->key();
        $start = max(0, $last - $maxLines + 1);
        $lines = [];

        for ($lineNo = $start; $lineNo <= $last; $lineNo++) {
            $file->seek($lineNo);
            $line = trim((string)$file->current());
            if ($line !== '') {
                $lines[] = $line;
            }
        }

        return $lines;
    }

    private function firstValue(array $record, array $keys, string $default = ''): string
    {
        foreach ($keys as $key) {
            if (isset($record[$key]) && $record[$key] !== '') {
                return (string)$record[$key];
            }
        }
        return $default;
    }

    private function normalizeRecord(array $record): array
    {
        $timestamp = $this->firstValue($record, ['timestamp', '__timestamp', 'time', 'ts']);
        $srcIp = $this->firstValue($record, ['src_ip', 'src', 'sip']);
        $srcPort = $this->firstValue($record, ['src_port', 'sport']);
        $dstIp = $this->firstValue($record, ['dst_ip', 'dst', 'dip']);
        $dstPort = $this->firstValue($record, ['dst_port', 'dport']);
        $l4Proto = strtolower($this->firstValue($record, ['l4_proto', 'proto', 'protocol'], '-'));
        $appName = $this->firstValue($record, ['app', 'application', 'ndpi_proto', 'protocol_name'], 'unknown');
        $category = $this->firstValue($record, ['category', 'app_category', 'ndpi_category'], 'unknown');

        return [
            'timestamp' => $timestamp,
            'src_ip' => $srcIp,
            'src_port' => $srcPort,
            'dst_ip' => $dstIp,
            'dst_port' => $dstPort,
            'protocol' => $l4Proto,
            'application' => $appName,
            'category' => $category,
            'five_tuple' => sprintf('%s:%s-%s:%s-%s', $srcIp, $srcPort, $dstIp, $dstPort, $l4Proto),
            'raw' => $record,
        ];
    }

    private function loadRecords(int $maxLines = 3000): array
    {
        $records = [];
        foreach ($this->readTailLines($maxLines) as $line) {
            $decoded = json_decode($line, true);
            if (is_array($decoded)) {
                $records[] = $this->normalizeRecord($decoded);
            }
        }
        return $records;
    }

    private function filterRecords(array $records, string $ip, string $app, string $start, string $end): array
    {
        $startTs = !empty($start) ? strtotime($start) : null;
        $endTs = !empty($end) ? strtotime($end) : null;

        return array_values(array_filter($records, function ($record) use ($ip, $app, $startTs, $endTs) {
            if (!empty($ip)) {
                $haystack = $record['src_ip'] . ' ' . $record['dst_ip'];
                if (stripos($haystack, $ip) === false) {
                    return false;
                }
            }

            if (!empty($app) && stripos($record['application'], $app) === false) {
                return false;
            }

            if ($startTs !== null || $endTs !== null) {
                $ts = strtotime($record['timestamp']);
                if ($ts === false) {
                    return false;
                }
                if ($startTs !== null && $ts < $startTs) {
                    return false;
                }
                if ($endTs !== null && $ts > $endTs) {
                    return false;
                }
            }

            return true;
        }));
    }

    public function liveAction()
    {
        $windowSeconds = max(5, min(3600, (int)$this->request->getQuery('window', 'int', 90)));
        $limit = max(1, min(1000, (int)$this->request->getQuery('limit', 'int', 200)));
        $now = time();

        $recent = [];
        foreach (array_reverse($this->loadRecords(3000)) as $record) {
            $ts = strtotime($record['timestamp']);
            if ($ts === false || ($now - $ts) > $windowSeconds) {
                continue;
            }
            if (!isset($recent[$record['five_tuple']])) {
                $recent[$record['five_tuple']] = $record;
            }
            if (count($recent) >= $limit) {
                break;
            }
        }

        return ['rows' => array_values($recent)];
    }

    public function searchAction()
    {
        $ip = trim((string)$this->request->getQuery('ip', null, ''));
        $app = trim((string)$this->request->getQuery('app', null, ''));
        $start = trim((string)$this->request->getQuery('start', null, ''));
        $end = trim((string)$this->request->getQuery('end', null, ''));
        $limit = max(1, min(5000, (int)$this->request->getQuery('limit', 'int', 500)));

        $records = $this->filterRecords($this->loadRecords(max($limit * 5, 3000)), $ip, $app, $start, $end);
        $records = array_slice(array_reverse($records), 0, $limit);

        return ['rows' => $records, 'total' => count($records)];
    }

    public function statsAction()
    {
        $ip = trim((string)$this->request->getQuery('ip', null, ''));
        $app = trim((string)$this->request->getQuery('app', null, ''));
        $start = trim((string)$this->request->getQuery('start', null, ''));
        $end = trim((string)$this->request->getQuery('end', null, ''));

        $records = $this->filterRecords($this->loadRecords(8000), $ip, $app, $start, $end);

        $counter = [];
        foreach ($records as $record) {
            $category = $record['category'] ?: 'unknown';
            if (!isset($counter[$category])) {
                $counter[$category] = 0;
            }
            $counter[$category]++;
        }

        arsort($counter);
        $rows = [];
        $total = max(1, array_sum($counter));
        foreach ($counter as $category => $count) {
            $rows[] = [
                'category' => $category,
                'count' => $count,
                'percentage' => round(($count * 100) / $total, 2),
            ];
        }

        return ['rows' => $rows, 'total' => array_sum($counter)];
    }
}
