<?php

namespace OPNsense\IndProto\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

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
                return $this->save();
            }
        }
        return array("result" => "failed");
    }
}
