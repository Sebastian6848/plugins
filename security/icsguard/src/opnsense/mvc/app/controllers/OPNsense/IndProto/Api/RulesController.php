<?php

namespace OPNsense\IndProto\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Backend;

class RulesController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'indproto';
    protected static $internalModelClass = '\OPNsense\IndProto\IndProto';

    public function searchRuleAction()
    {
        return $this->searchBase(
            "rules.rule",
            array("description", "protocol", "src_ip", "dst_ip", "action", "access"),
            "description"
        );
    }

    public function getRuleAction($uuid = null)
    {
        return $this->getBase("rule", "rules.rule", $uuid);
    }

    public function addRuleAction()
    {
        return $this->addBase("rule", "rules.rule");
    }

    public function setRuleAction($uuid)
    {
        return $this->setBase("rule", "rules.rule", $uuid);
    }

    public function delRuleAction($uuid)
    {
        return $this->delBase("rules.rule", $uuid);
    }

    public function toggleRuleAction($uuid, $enabled = null)
    {
        return $this->toggleBase("rules.rule", $uuid, $enabled);
    }

    public function applyAction()
    {
        if (!$this->request->isPost()) {
            return array("status" => "error", "message" => "POST required");
        }

        $save_result = $this->save();
        if (isset($save_result["result"]) && $save_result["result"] !== "saved") {
            return array("status" => "error", "message" => "Unable to save configuration");
        }

        $backend = new Backend();
        $reload = trim($backend->configdRun("indproto reload"));
        $restart = trim($backend->configdRun("indproto restart_suricata"));

        return array(
            "status" => "ok",
            "reload" => $reload,
            "restart" => $restart,
        );
    }
}
