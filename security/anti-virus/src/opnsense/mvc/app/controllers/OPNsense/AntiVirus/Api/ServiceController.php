<?php

namespace OPNsense\AntiVirus\Api;

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
        if (!$this->request->isPost()) {
            return ['status' => 'failed'];
        }

        $backend = new Backend();
        $tpl = trim($backend->configdRun('template reload OPNsense/AntiVirus'));
        if ($this->hasError($tpl)) {
            return ['status' => 'failed', 'message' => $tpl];
        }

        $idsReload = trim($backend->configdRun('ids reload'));
        $restart = trim($backend->configdRun('antivirus restart'));

        return [
            'status' => 'ok',
            'message' => implode("\n", [$tpl, $idsReload, $restart]),
        ];
    }

    public function blockIpAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed'];
        }

        $ip = trim((string)$this->request->getPost('ip', null, ''));
        $ttl = (int)$this->request->getPost('ttl', 'int', 3600);
        if ($ip === '') {
            return ['status' => 'failed', 'message' => 'missing ip'];
        }

        $backend = new Backend();
        $result = trim($backend->configdpRun('antivirus block_ip', [$ip, (string)max(60, $ttl)]));

        return ['status' => 'ok', 'message' => $result];
    }
}