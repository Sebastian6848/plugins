<?php

namespace OPNsense\IndProto\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\IndProto\Backend\BackendFacade;

class GeneralController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'indproto';
    protected static $internalModelClass = '\OPNsense\IndProto\IndProto';

    public function getAction()
    {
        return array(
            static::$internalModelName => array(
                "general" => $this->getModel()->general->getNodes(),
            ),
        );
    }

    public function setAction()
    {
        if ($this->request->isPost() && $this->request->hasPost(static::$internalModelName)) {
            $data = $this->request->getPost(static::$internalModelName);
            if (isset($data["general"])) {
                $this->getModel()->general->setNodes($data["general"]);
                $save_result = $this->save();
                if (isset($save_result["result"]) && $save_result["result"] !== "saved") {
                    return $save_result;
                }

                $backend = new BackendFacade();
                $reload = $backend->run("reload");
                $service = ((string)$this->getModel()->general->enabled === "1")
                    ? $backend->run("start")
                    : $backend->run("stop");

                return array(
                    "result" => "saved",
                    "status" => (($reload["status"] ?? "") === "error" || ($service["status"] ?? "") === "error") ? "error" : "ok",
                    "reload" => $reload,
                    "service" => $service,
                );
            }
        }
        return array("result" => "failed");
    }
}
