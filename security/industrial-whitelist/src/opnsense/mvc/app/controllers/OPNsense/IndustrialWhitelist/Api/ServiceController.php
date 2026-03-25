<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    private function hasError($output)
    {
        return stripos($output, 'error') !== false || stripos($output, 'failed') !== false;
    }

    public function reconfigureAction()
    {
        $backend = new Backend();
        $suricataCompile = trim($backend->configdRun('industrialwhitelist generate'));
        if ($this->hasError($suricataCompile)) {
            return ['status' => 'failed', 'message' => $suricataCompile];
        }

        $filterReload = trim($backend->configdRun('filter reload'));
        if ($this->hasError($filterReload)) {
            return ['status' => 'failed', 'message' => $filterReload];
        }

        $idsReload = trim($backend->configdRun('ids reload'));
        if ($this->hasError($idsReload)) {
            return [
                'status' => 'ok',
                'message' => implode("\n", [
                    $suricataCompile,
                    $filterReload,
                    'warning: IDS reload returned error, verify Intrusion Detection is enabled.',
                    $idsReload,
                ]),
            ];
        }

        return ['status' => 'ok', 'message' => implode("\n", [$suricataCompile, $filterReload, $idsReload])];
    }
}
