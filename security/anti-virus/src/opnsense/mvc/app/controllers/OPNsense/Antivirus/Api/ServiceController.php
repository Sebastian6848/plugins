<?php

namespace OPNsense\Antivirus\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    private function runCommand(string $command): array
    {
        $response = trim((new Backend())->configdRun($command));
        return ['status' => $response === '' ? 'ok' : $response];
    }

    public function startAction(): array
    {
        return $this->runCommand('antivirus start');
    }

    public function stopAction(): array
    {
        return $this->runCommand('antivirus stop');
    }

    public function restartAction(): array
    {
        return $this->runCommand('antivirus restart');
    }

    public function reloadAction(): array
    {
        return $this->runCommand('antivirus reload');
    }

    public function updateSigsAction(): array
    {
        return $this->runCommand('antivirus update_sigs');
    }

    public function statusAction(): array
    {
        $response = trim((new Backend())->configdRun('antivirus status'));
        $decoded = json_decode($response, true);

        if (is_array($decoded)) {
            return $decoded;
        }

        return [
            'clamd' => 'unknown',
            'cicap' => 'unknown',
            'squid_icap' => 'unknown',
            'sig_version' => '',
            'sig_updated' => '',
            'freshclam' => 'unknown',
            'raw' => $response,
        ];
    }
}
