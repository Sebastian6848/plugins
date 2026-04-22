<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;

class LogsController extends ApiControllerBase
{
    private const EXPORT_HEADERS = [
        'Content-Type: text/csv',
        'Content-Transfer-Encoding: binary',
        'Pragma: no-cache',
        'Expires: 0',
        'Content-Disposition: attachment; filename="industrial-whitelist-logs.csv"',
    ];

    private function firstValue(array $record, array $keys, string $default = '-'): string
    {
        foreach ($keys as $key) {
            if (isset($record[$key]) && $record[$key] !== '') {
                return (string)$record[$key];
            }
        }

        return $default;
    }

    private function extractRevision(string $text): string
    {
        if (preg_match('/rev:([A-Za-z0-9\-]+)/', $text, $matches)) {
            return $matches[1];
        }

        return '';
    }

    private function toEpoch(string $timestamp): int
    {
        $epoch = strtotime($timestamp);
        return $epoch === false ? 0 : (int)$epoch;
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

    private function loadPfLogs(int $limit = 5000, string $revisionFilter = ''): array
    {
        $response = (new Backend())->configdpRun('filter read log', [$limit]);
        $records = json_decode((string)$response, true);
        if (!is_array($records)) {
            return [];
        }

        $rows = [];
        foreach ($records as $record) {
            if (!is_array($record)) {
                continue;
            }

            $payload = strtolower(json_encode($record));
            if (strpos($payload, 'industrialwhitelist') === false) {
                continue;
            }

            $rawText = json_encode($record);
            $revision = $this->extractRevision((string)$rawText);
            if ($revisionFilter !== '' && $revision !== $revisionFilter) {
                continue;
            }

            $proto = $this->firstValue($record, ['proto', 'protocol']);
            $port = $this->firstValue($record, ['dstport', 'dest_port', 'port']);
            $rows[] = [
                'timestamp' => $this->firstValue($record, ['__timestamp', 'timestamp', 'time']),
                'engine' => 'pf',
                'source' => $this->firstValue($record, ['src', 'src_ip', 'srcip']),
                'destination' => $this->firstValue($record, ['dst', 'dest', 'dst_ip', 'dstip']),
                'protocol_port' => sprintf('%s/%s', $proto, $port),
                'revision' => $revision !== '' ? $revision : '-',
                'action' => $this->firstValue($record, ['action', 'act', 'label', 'description']),
                'message' => $this->firstValue($record, ['label', 'description', 'descr', 'tracker']),
            ];
        }

        return $rows;
    }

    private function loadSuricataLogs(int $limit = 5000, string $revisionFilter = ''): array
    {
        $response = (new Backend())->configdpRun('ids query alerts', [$limit, 0, '', null]);
        $data = json_decode((string)$response, true);
        $records = is_array($data) && isset($data['rows']) && is_array($data['rows']) ? $data['rows'] : [];

        $rows = [];
        foreach ($records as $record) {
            if (!is_array($record)) {
                continue;
            }

            $alertText = (string)($record['alert'] ?? '');
            if (stripos($alertText, 'IndustrialWhitelist') === false) {
                continue;
            }

            $revision = $this->extractRevision($alertText);
            if ($revisionFilter !== '' && $revision !== $revisionFilter) {
                continue;
            }

            $proto = (string)($record['proto'] ?? $record['app_proto'] ?? '-');
            $port = (string)($record['dest_port'] ?? '-');
            $rows[] = [
                'timestamp' => (string)($record['timestamp'] ?? '-'),
                'engine' => 'suricata',
                'source' => (string)($record['src_ip'] ?? '-'),
                'destination' => (string)($record['dest_ip'] ?? '-'),
                'protocol_port' => sprintf('%s/%s', $proto, $port),
                'revision' => $revision !== '' ? $revision : '-',
                'action' => (string)($record['alert_action'] ?? 'alert'),
                'message' => $alertText !== '' ? $alertText : '-',
            ];
        }

        return $rows;
    }

    private function loadLogs(int $limit = 5000, string $revisionFilter = ''): array
    {
        $rows = array_merge(
            $this->loadPfLogs($limit, $revisionFilter),
            $this->loadSuricataLogs($limit, $revisionFilter)
        );

        usort($rows, function ($left, $right) {
            return $this->toEpoch((string)($right['timestamp'] ?? '')) <=> $this->toEpoch((string)($left['timestamp'] ?? ''));
        });

        return $rows;
    }

    public function searchAction()
    {
        $limit = max(200, min(20000, $this->requestInt('limit', 5000)));
        $revision = $this->requestString('revision');
        $records = $this->loadLogs($limit, $revision);

        return $this->searchRecordsetBase(
            $records,
            ['timestamp', 'engine', 'source', 'destination', 'protocol_port', 'revision', 'action', 'message']
        );
    }

    public function exportAction()
    {
        $limit = max(200, min(20000, $this->requestInt('limit', 5000)));
        $searchPhrase = $this->requestString('searchPhrase');
        $revision = $this->requestString('revision');

        $records = $this->loadLogs($limit, $revision);
        $records = $this->applySearchPhrase(
            $records,
            $searchPhrase,
            ['timestamp', 'engine', 'source', 'destination', 'protocol_port', 'revision', 'action', 'message']
        );

        $this->exportCsv($records, self::EXPORT_HEADERS);
        return $this->response;
    }

    public function statusAction()
    {
        $config = Config::getInstance()->object();
        $general = $config['OPNsense']['IndustrialWhitelist']['general'] ?? [];

        $idsStatusOutput = trim((new Backend())->configdRun('ids status'));
        return [
            'revision' => (string)($general['last_apply_revision'] ?? ''),
            'timestamp' => (string)($general['last_apply_timestamp'] ?? ''),
            'ids_status' => $idsStatusOutput,
            'ids_running' => stripos($idsStatusOutput, 'running') !== false,
        ];
    }
}
