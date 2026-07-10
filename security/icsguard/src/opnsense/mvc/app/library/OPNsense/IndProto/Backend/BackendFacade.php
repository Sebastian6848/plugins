<?php

namespace OPNsense\IndProto\Backend;

use OPNsense\Core\Backend;

class BackendFacade
{
    public function run(string $action, array $args = []): array
    {
        $command = 'indproto ' . $action;
        foreach ($args as $arg) {
            $command .= ' ' . escapeshellarg((string)$arg);
        }
        $response = trim((new Backend())->configdRun($command));
        $decoded = json_decode($response, true);
        if (is_array($decoded)) {
            return $decoded;
        }
        return ['status' => 'ok', 'message' => $response, 'raw' => $response];
    }

    public function raw(string $action, array $args = []): string
    {
        $command = 'indproto ' . $action;
        foreach ($args as $arg) {
            $command .= ' ' . escapeshellarg((string)$arg);
        }
        return (new Backend())->configdRun($command);
    }
}
