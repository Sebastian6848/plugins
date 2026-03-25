<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

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

    private function loadLogs(int $limit = 5000): array
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

            $proto = $this->firstValue($record, ['proto', 'protocol']);
            $port = $this->firstValue($record, ['dstport', 'dest_port', 'port']);
            $rows[] = [
                'timestamp' => $this->firstValue($record, ['__timestamp', 'timestamp', 'time']),
                'source' => $this->firstValue($record, ['src', 'src_ip', 'srcip']),
                'destination' => $this->firstValue($record, ['dst', 'dest', 'dst_ip', 'dstip']),
                'protocol_port' => sprintf('%s/%s', $proto, $port),
                'action' => $this->firstValue($record, ['action', 'act', 'label', 'description']),
            ];
        }

        return array_reverse($rows);
    }

    public function searchAction()
    {
        $limit = max(200, min(20000, $this->requestInt('limit', 5000)));
        $records = $this->loadLogs($limit);

        return $this->searchRecordsetBase(
            $records,
            ['timestamp', 'source', 'destination', 'protocol_port', 'action']
        );
    }

    public function exportAction()
    {
        $limit = max(200, min(20000, $this->requestInt('limit', 5000)));
        $searchPhrase = $this->requestString('searchPhrase');

        $records = $this->loadLogs($limit);
        $records = $this->applySearchPhrase(
            $records,
            $searchPhrase,
            ['timestamp', 'source', 'destination', 'protocol_port', 'action']
        );

        $this->exportCsv($records, self::EXPORT_HEADERS);
        return $this->response;
    }
}
