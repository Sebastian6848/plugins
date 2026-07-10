<?php

namespace OPNsense\IndProto\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\IndProto\Backend\BackendFacade;

class LogController extends ApiControllerBase
{
    private function requestParam(string $name, string $default = ''): string
    {
        $value = (string)$this->request->getPost($name, null, '');
        if ($value === '') {
            $value = (string)$this->request->getQuery($name, null, '');
        }
        return $value !== '' ? $value : $default;
    }

    private function safeValue(string $value, string $default = '-'): string
    {
        $value = trim($value);
        if ($value === '' || strtolower($value) === 'all') {
            return $default;
        }
        return preg_match('/^[0-9A-Za-z_.:\/+-]+$/', $value) ? $value : $default;
    }

    private function applySearch(array $rows, string $searchPhrase): array
    {
        if ($searchPhrase === '') {
            return $rows;
        }

        $clauses = preg_split('/\s+/', $searchPhrase);
        return array_values(array_filter($rows, function ($row) use ($clauses) {
            $payload = strtolower(json_encode($row));
            foreach ($clauses as $clause) {
                if ($clause !== '' && strpos($payload, strtolower($clause)) === false) {
                    return false;
                }
            }
            return true;
        }));
    }

    public function searchLogAction()
    {
        $current = (int)$this->request->getPost('current', 'int', 1);
        $rowCount = (int)$this->request->getPost('rowCount', 'int', 25);
        $limit = (int)$this->requestParam('limit', '200');
        if ($limit < 1) {
            $limit = 200;
        } elseif ($limit > 1000) {
            $limit = 1000;
        }

        $proto = $this->safeValue($this->requestParam('proto'));
        $srcIp = $this->safeValue($this->requestParam('src_ip'));
        $dstIp = $this->safeValue($this->requestParam('dst_ip'));
        $startTime = $this->safeValue($this->requestParam('start_time'));
        $endTime = $this->safeValue($this->requestParam('end_time'));

        $backend = new BackendFacade();
        $response = $backend->raw("log", ["--proto", $proto, "--src_ip", $srcIp, "--dst_ip", $dstIp, "--start_time", $startTime, "--end_time", $endTime, "--limit", (string)$limit]);
        $rows = json_decode($response, true);
        if (!is_array($rows)) {
            $rows = array();
        }

        $rows = $this->applySearch($rows, trim($this->requestParam('searchPhrase')));
        $total = count($rows);
        if ($rowCount > 0) {
            $offset = max(0, ($current - 1) * $rowCount);
            $rows = array_slice($rows, $offset, $rowCount);
        }

        return array(
            "current" => $current,
            "rowCount" => $rowCount,
            "rows" => $rows,
            "total" => $total,
        );
    }
}
