<?php

namespace OPNsense\Antivirus\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\OPNsense\Antivirus\Antivirus';
    protected static $internalServiceTemplate = 'OPNsense/Antivirus';
    protected static $internalServiceEnabled = 'enabled';
    protected static $internalServiceName = 'antivirus';

    private function runAction($action)
    {
        $backend = new Backend();
        $response = $backend->configdRun("antivirus " . $action);
        $decoded = json_decode($response, true);
        return is_array($decoded) ? $decoded : array("response" => $response);
    }

    public function applyAction()
    {
        return $this->runAction("apply");
    }

    public function repairAction()
    {
        return $this->runAction("repair");
    }

    public function statusAction()
    {
        return $this->runAction("status");
    }

    public function eicarTestAction()
    {
        return $this->runAction("eicar_test");
    }

    public function eicar_testAction()
    {
        return $this->eicarTestAction();
    }

    public function updateDbAction()
    {
        return $this->runAction("update_db");
    }

    public function update_dbAction()
    {
        return $this->updateDbAction();
    }

    public function parseLogsAction()
    {
        return $this->runAction("parse_logs");
    }

    public function parse_logsAction()
    {
        return $this->parseLogsAction();
    }

    public function dashboardAction()
    {
        return $this->runAction("dashboard");
    }

    public function logsAction()
    {
        return $this->runAction("logs");
    }
}
