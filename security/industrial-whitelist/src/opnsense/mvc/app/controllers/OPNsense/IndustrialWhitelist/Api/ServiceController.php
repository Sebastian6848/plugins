<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    public function reconfigureAction()
    {
        $backend = new Backend();
        $result = trim($backend->configdRun('filter reload'));

        if (stripos($result, 'error') !== false) {
            return ['status' => 'failed', 'message' => $result];
        }

        return ['status' => 'ok', 'message' => $result];
    }
}
