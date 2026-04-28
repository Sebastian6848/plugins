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

    private function respond(string $mode): array
    {
        $data = $this->loadLogs($mode);
        $rows = isset($data['rows']) && is_array($data['rows']) ? $data['rows'] : array();
        $searchPhrase = (string)$this->request->getPost('searchPhrase', null, '');
        $current = (int)$this->request->getPost('current', 'int', 1);
        $rowCount = (int)$this->request->getPost('rowCount', 'int', 25);

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
