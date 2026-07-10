<?php

namespace OPNsense\Antivirus\Backend;

use OPNsense\Core\Backend;

class BackendFacade
{
    public function run(string $action, array $args = []): array
    {
        $command = 'antivirus ' . $action;
        foreach ($args as $arg) {
            $command .= ' ' . escapeshellarg((string)$arg);
        }
        $response = trim((new Backend())->configdRun($command));
        $decoded = json_decode($response, true);
        if (is_array($decoded)) {
            return $decoded;
        }
        return ['status' => $response !== '' ? $response : 'error', 'message' => $response];
    }
}
