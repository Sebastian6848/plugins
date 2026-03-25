<?php

namespace OPNsense\NdpiAudit\Api;

use OPNsense\Base\ApiControllerBase;

class AuditController extends ApiControllerBase
{
    private const LOG_FILE = '/var/log/ndpi_audit.log';
    private const EXPORT_HEADERS = [
        'Content-Type: text/csv',
        'Content-Transfer-Encoding: binary',
        'Pragma: no-cache',
        'Expires: 0',
        'Content-Disposition: attachment; filename="appid-engine-records.csv"',
    ];

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

    private function requestString(string $name, string $default = ''): string
    {
        $value = $this->request->getPost($name, null, null);
        if ($value === null || $value === '') {
            $value = $this->request->getQuery($name, null, $default);
        }

        return is_scalar($value) ? trim((string)$value) : $default;
    }

    private function requestInt(string $name, int $default): int
    {
        $value = $this->request->getPost($name, 'int', null);
        if ($value === null || $value === '') {
            $value = $this->request->getQuery($name, 'int', $default);
        }

        return is_numeric($value) ? (int)$value : $default;
    }

    private function applySearchPhrase(array $records, string $searchPhrase, array $fields): array
    {
        if ($searchPhrase === '') {
            return $records;
        }

        $clauses = preg_split('/\s+/', $searchPhrase);
        return array_values(array_filter($records, function ($record) use ($clauses, $fields) {
            foreach ($clauses as $clause) {
                if ($clause === '') {
                    continue;
                }

                $matched = false;
                foreach ($fields as $field) {
                    if (stripos((string)($record[$field] ?? ''), $clause) !== false) {
                        $matched = true;
                        break;
                    }
                }

                if (!$matched) {
                    return false;
                }
            }

            return true;
        }));
    }

    private function collectLiveRecords(int $windowSeconds, int $limit): array
    {
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

        return array_values($recent);
    }

    private function toExportRows(array $records): array
    {
        return array_map(function ($record) {
            return [
                'timestamp' => $record['timestamp'] ?? '',
                'src_ip' => $record['src_ip'] ?? '',
                'src_port' => $record['src_port'] ?? '',
                'dst_ip' => $record['dst_ip'] ?? '',
                'dst_port' => $record['dst_port'] ?? '',
                'l4' => $record['protocol'] ?? '',
                'application' => $record['application'] ?? '',
                'category' => $record['category'] ?? '',
            ];
        }, $records);
    }

    public function liveAction()
    {
        $windowSeconds = max(5, min(3600, $this->requestInt('window', 90)));
        $limit = max(1, min(1000, $this->requestInt('limit', 200)));

        return ['rows' => $this->collectLiveRecords($windowSeconds, $limit)];
    }

    public function searchLiveAction()
    {
        $windowSeconds = max(5, min(3600, $this->requestInt('window', 120)));
        $limit = max(1, min(5000, $this->requestInt('limit', 2000)));
        $records = $this->collectLiveRecords($windowSeconds, $limit);

        return $this->searchRecordsetBase(
            $records,
            ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']
        );
    }

    public function searchAction()
    {
        $ip = $this->requestString('ip');
        $app = $this->requestString('app');
        $start = $this->requestString('start');
        $end = $this->requestString('end');
        $limit = max(1, min(5000, $this->requestInt('limit', 500)));

        $records = $this->filterRecords($this->loadRecords(max($limit * 5, 3000)), $ip, $app, $start, $end);
        $records = array_slice(array_reverse($records), 0, $limit);

        return ['rows' => $records, 'total' => count($records)];
    }

    public function searchHistoryAction()
    {
        $ip = $this->requestString('ip');
        $app = $this->requestString('app');
        $start = $this->requestString('start');
        $end = $this->requestString('end');
        $limit = max(1, min(10000, $this->requestInt('limit', 5000)));

        $records = $this->filterRecords($this->loadRecords(max($limit * 5, 4000)), $ip, $app, $start, $end);
        $records = array_slice(array_reverse($records), 0, $limit);

        return $this->searchRecordsetBase(
            $records,
            ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']
        );
    }

    public function exportHistoryAction()
    {
        $ip = $this->requestString('ip');
        $app = $this->requestString('app');
        $start = $this->requestString('start');
        $end = $this->requestString('end');
        $limit = max(1, min(10000, $this->requestInt('limit', 5000)));
        $searchPhrase = $this->requestString('searchPhrase');

        $records = $this->filterRecords($this->loadRecords(max($limit * 5, 4000)), $ip, $app, $start, $end);
        $records = array_slice(array_reverse($records), 0, $limit);
        $records = $this->applySearchPhrase(
            $records,
            $searchPhrase,
            ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']
        );

        $this->exportCsv($this->toExportRows($records), self::EXPORT_HEADERS);
        return $this->response;
    }

    public function exportLiveAction()
    {
        $windowSeconds = max(5, min(3600, $this->requestInt('window', 120)));
        $limit = max(1, min(5000, $this->requestInt('limit', 2000)));
        $searchPhrase = $this->requestString('searchPhrase');

        $records = $this->collectLiveRecords($windowSeconds, $limit);
        $records = $this->applySearchPhrase(
            $records,
            $searchPhrase,
            ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']
        );

        $this->exportCsv($this->toExportRows($records), self::EXPORT_HEADERS);
        return $this->response;
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
