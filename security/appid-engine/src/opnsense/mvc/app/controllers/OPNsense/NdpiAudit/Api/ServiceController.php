<?php

namespace OPNsense\NdpiAudit\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\\OPNsense\\NdpiAudit\\General';
    protected static $internalServiceTemplate = 'OPNsense/NdpiAudit';
    protected static $internalServiceEnabled = 'enabled';
    protected static $internalServiceName = 'ndpiaudit';

    public function reconfigureAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed'];
        }

        $backend = new Backend();

        $tpl = trim($backend->configdRun('template reload OPNsense/NdpiAudit'));
        $filter = trim($backend->configdRun('filter reload'));
        $anchor = trim($backend->configdRun('ndpiaudit mirror_reload'));
        $restart = trim($backend->configdRun('ndpiaudit restart'));

        return [
            'status' => 'ok',
            'message' => implode("\n", [$tpl, $filter, $anchor, $restart]),
        ];
    }
}
