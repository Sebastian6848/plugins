<?php

namespace OPNsense\Antivirus\Api;

use OPNsense\Base\ApiControllerBase;

class LogController extends ApiControllerBase
{
    private const DB_PATH = '/var/db/antivirus/events.db';

    private const EXPORT_HEADERS = [
        'Content-Type: text/csv',
        'Content-Transfer-Encoding: binary',
        'Pragma: no-cache',
        'Expires: 0',
        'Content-Disposition: attachment; filename="antivirus-detections.csv"',
    ];

    private function db(): ?\SQLite3
    {
        if (!file_exists(self::DB_PATH)) {
            return null;
        }

        $db = new \SQLite3(self::DB_PATH, SQLITE3_OPEN_READONLY);
        $db->busyTimeout(1000);
        return $db;
    }

    private function requestValue(string $name, $default = '')
    {
        $value = $this->request->getPost($name, null, null);
        if ($value === null || $value === '') {
            $value = $this->request->getQuery($name, null, $default);
        }

        return is_scalar($value) ? trim((string)$value) : $default;
    }

    private function requestInt(string $name, int $default): int
    {
        $value = $this->requestValue($name, (string)$default);
        return is_numeric($value) ? (int)$value : $default;
    }

    private function timestampFromDate(string $date, bool $endOfDay = false): ?int
    {
        if ($date === '') {
            return null;
        }

        $timestamp = strtotime($date . ($endOfDay && preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) ? ' 23:59:59' : ''));
        return $timestamp === false ? null : (int)$timestamp;
    }

    private function filters(string $filterIp, string $filterSig, string $dateFrom, string $dateTo): array
    {
        $where = [];
        $params = [];

        if ($filterIp !== '') {
            $where[] = 'src_ip LIKE :filter_ip';
            $params[':filter_ip'] = '%' . $filterIp . '%';
        }
        if ($filterSig !== '') {
            $where[] = 'signature LIKE :filter_sig';
            $params[':filter_sig'] = '%' . $filterSig . '%';
        }

        $fromTs = $this->timestampFromDate($dateFrom);
        if ($fromTs !== null) {
            $where[] = 'ts >= :date_from';
            $params[':date_from'] = $fromTs;
        }

        $toTs = $this->timestampFromDate($dateTo, true);
        if ($toTs !== null) {
            $where[] = 'ts <= :date_to';
            $params[':date_to'] = $toTs;
        }

        return [$where, $params];
    }

    private function bindParams(\SQLite3Stmt $stmt, array $params): void
    {
        foreach ($params as $name => $value) {
            $stmt->bindValue($name, $value, is_int($value) ? SQLITE3_INTEGER : SQLITE3_TEXT);
        }
    }

    private function rowFromResult(array $row): array
    {
        $timestamp = isset($row['ts']) ? (int)$row['ts'] : 0;
        return [
            'ts' => $timestamp > 0 ? gmdate('c', $timestamp) : '',
            'src_ip' => (string)($row['src_ip'] ?? ''),
            'url' => (string)($row['url'] ?? ''),
            'signature' => (string)($row['signature'] ?? ''),
            'action' => (string)($row['action'] ?? 'blocked'),
        ];
    }

    private function queryRows(\SQLite3 $db, string $sql, array $params = []): array
    {
        $stmt = $db->prepare($sql);
        if ($stmt === false) {
            return [];
        }

        $this->bindParams($stmt, $params);
        $result = $stmt->execute();
        $rows = [];
        while ($result !== false && ($row = $result->fetchArray(SQLITE3_ASSOC)) !== false) {
            $rows[] = $row;
        }

        return $rows;
    }

    public function searchAction(
        $offset = null,
        $limit = null,
        $filter_ip = null,
        $filter_sig = null,
        $date_from = null,
        $date_to = null
    ): array {
        $db = $this->db();
        if ($db === null) {
            return ['total' => 0, 'rows' => []];
        }

        $limit = $limit === null ? $this->requestInt('limit', $this->requestInt('rowCount', 50)) : (int)$limit;
        $limit = max(1, min(500, $limit));
        $offset = $offset === null ? $this->requestInt('offset', 0) : (int)$offset;
        if ($offset === 0 && $this->requestInt('current', 1) > 1) {
            $offset = ($this->requestInt('current', 1) - 1) * $limit;
        }

        $filterIp = $filter_ip === null ? $this->requestValue('filter_ip') : (string)$filter_ip;
        $filterSig = $filter_sig === null ? $this->requestValue('filter_sig') : (string)$filter_sig;
        $dateFrom = $date_from === null ? $this->requestValue('date_from') : (string)$date_from;
        $dateTo = $date_to === null ? $this->requestValue('date_to') : (string)$date_to;

        [$where, $params] = $this->filters($filterIp, $filterSig, $dateFrom, $dateTo);
        $whereSql = count($where) > 0 ? ' WHERE ' . implode(' AND ', $where) : '';

        $totalRows = $this->queryRows($db, 'SELECT COUNT(*) AS total FROM detections' . $whereSql, $params);
        $total = isset($totalRows[0]['total']) ? (int)$totalRows[0]['total'] : 0;

        $params[':limit'] = $limit;
        $params[':offset'] = max(0, $offset);
        $rows = $this->queryRows(
            $db,
            'SELECT ts, src_ip, url, signature, action FROM detections' . $whereSql .
            ' ORDER BY ts DESC LIMIT :limit OFFSET :offset',
            $params
        );

        return [
            'total' => $total,
            'rowCount' => count($rows),
            'current' => (int)floor(max(0, $offset) / $limit) + 1,
            'rows' => array_map([$this, 'rowFromResult'], $rows),
        ];
    }

    public function statsAction(): array
    {
        $db = $this->db();
        if ($db === null) {
            return ['last24h' => 0, 'trend7d' => [], 'top_ips' => [], 'top_sigs' => []];
        }

        $now = time();
        $last24h = $this->queryRows(
            $db,
            'SELECT COUNT(*) AS total FROM detections WHERE ts >= :since',
            [':since' => $now - 86400]
        );

        $trendRows = $this->queryRows(
            $db,
            "SELECT date(ts, 'unixepoch') AS date, COUNT(*) AS count FROM detections " .
            "WHERE ts >= :since GROUP BY date(ts, 'unixepoch') ORDER BY date ASC",
            [':since' => $now - 6 * 86400]
        );
        $trendByDate = [];
        foreach ($trendRows as $row) {
            $trendByDate[(string)$row['date']] = (int)$row['count'];
        }

        $trend7d = [];
        for ($day = 6; $day >= 0; $day--) {
            $date = gmdate('Y-m-d', $now - $day * 86400);
            $trend7d[] = ['date' => $date, 'count' => $trendByDate[$date] ?? 0];
        }

        $topIps = $this->queryRows(
            $db,
            "SELECT src_ip AS ip, COUNT(*) AS count FROM detections " .
            "WHERE src_ip IS NOT NULL AND src_ip != '' GROUP BY src_ip ORDER BY count DESC LIMIT 10"
        );
        $topSigs = $this->queryRows(
            $db,
            "SELECT signature AS sig, COUNT(*) AS count FROM detections " .
            "WHERE signature IS NOT NULL AND signature != '' GROUP BY signature ORDER BY count DESC LIMIT 10"
        );

        return [
            'last24h' => isset($last24h[0]['total']) ? (int)$last24h[0]['total'] : 0,
            'trend7d' => $trend7d,
            'top_ips' => array_map(function ($row) {
                return ['ip' => (string)$row['ip'], 'count' => (int)$row['count']];
            }, $topIps),
            'top_sigs' => array_map(function ($row) {
                return ['sig' => (string)$row['sig'], 'count' => (int)$row['count']];
            }, $topSigs),
        ];
    }

    public function exportAction()
    {
        $rows = $this->searchAction(0, 10000)['rows'];
        $this->exportCsv($rows, self::EXPORT_HEADERS);
        return $this->response;
    }
}
