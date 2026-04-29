<?php

/*
 * Copyright (C) 2026
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

namespace OPNsense\Antivirus\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class LogsController extends ApiControllerBase
{
    private function loadLogs(string $mode): array
    {
        $backend = new Backend();
        $response = json_decode($backend->configdRun("antivirus logs {$mode}"), true);
        if (is_array($response)) {
            return $response;
        }
        return array("rows" => array(), "total" => 0);
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

    private function requestParam(string $name, string $default = ''): string
    {
        $value = (string)$this->request->getPost($name, null, '');
        if ($value === '') {
            $value = (string)$this->request->getQuery($name, null, '');
        }
        return $value !== '' ? $value : $default;
    }

    private function severity(string $message): string
    {
        $payload = strtolower($message);
        if (strpos($payload, 'virus detected') !== false || strpos($payload, 'infected') !== false) {
            return 'alert';
        } elseif (strpos($payload, 'warn') !== false) {
            return 'warning';
        } elseif (strpos($payload, 'error') !== false || strpos($payload, 'failed') !== false) {
            return 'error';
        }
        return 'info';
    }

    private function sinceCutoff(string $since)
    {
        switch ($since) {
            case '1h':
                return strtotime('-1 hour');
            case 'today':
                return strtotime('today');
            case 'yesterday':
                return strtotime('yesterday');
            case '7d':
                return strtotime('-7 days');
            default:
                return null;
        }
    }

    private function applyFilters(array $rows, string $mode): array
    {
        $severity = strtolower($this->requestParam('severity'));
        $program = strtolower($this->requestParam('program'));
        $action = strtolower($this->requestParam('action'));
        $source = strtolower($this->requestParam('source'));
        $since = $this->requestParam('since', 'all');
        $cutoff = $this->sinceCutoff($since);
        $until = $since === 'yesterday' ? strtotime('today') : null;

        return array_values(array_filter($rows, function ($row) use ($mode, $severity, $program, $action, $source, $cutoff, $until) {
            if (!isset($row['severity'])) {
                $row['severity'] = $mode === 'blocked' ? 'alert' : $this->severity($row['message'] ?? '');
            }
            if ($severity !== '' && $severity !== 'all' && strtolower($row['severity']) !== $severity) {
                return false;
            }
            if ($program !== '' && $program !== 'all' && strpos(strtolower($row['program'] ?? ''), $program) === false) {
                return false;
            }
            if ($action !== '' && $action !== 'all' && strtolower($row['action'] ?? '') !== $action) {
                return false;
            }
            if ($source !== '' && $source !== 'all' && strtolower($row['source'] ?? '') !== $source) {
                return false;
            }
            if ($cutoff !== null && !empty($row['time'])) {
                $timestamp = strtotime($row['time']);
                if ($timestamp !== false && $timestamp < $cutoff) {
                    return false;
                }
                if ($until !== null && $timestamp !== false && $timestamp >= $until) {
                    return false;
                }
            }
            return true;
        }));
    }

    private function enrichRows(array $rows, string $mode): array
    {
        foreach ($rows as &$row) {
            if (!isset($row['severity'])) {
                $row['severity'] = $mode === 'blocked' ? 'alert' : $this->severity($row['message'] ?? '');
            }
        }
        return $rows;
    }

    private function respond(string $mode): array
    {
        $data = $this->loadLogs($mode);
        $rows = isset($data['rows']) && is_array($data['rows']) ? $data['rows'] : array();
        $searchPhrase = $this->requestParam('searchPhrase');
        $current = (int)$this->request->getPost('current', 'int', 1);
        if ($current < 1) {
            $current = (int)$this->request->getQuery('current', 'int', 1);
        }
        $rowCount = (int)$this->request->getPost('rowCount', 'int', 25);
        if ($rowCount === 25) {
            $queryRowCount = $this->request->getQuery('rowCount', 'int', null);
            if ($queryRowCount !== null) {
                $rowCount = (int)$queryRowCount;
            }
        }

        $rows = $this->enrichRows($rows, $mode);
        $rows = $this->applyFilters($rows, $mode);
        $rows = $this->applySearch($rows, trim($searchPhrase));
        $total = count($rows);

        if ($rowCount > 0) {
            $offset = max(0, ($current - 1) * $rowCount);
            $rows = array_slice($rows, $offset, $rowCount);
        }

        return array(
            "current" => $current,
            "rowCount" => $rowCount,
            "rows" => $rows,
            "total" => $total
        );
    }

    public function blockedAction()
    {
        return $this->respond('blocked');
    }

    public function rawAction()
    {
        return $this->respond('raw');
    }
}
