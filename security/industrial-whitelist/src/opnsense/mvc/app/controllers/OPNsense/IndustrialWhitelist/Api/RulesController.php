<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

class RulesController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'industrialwhitelist';
    protected static $internalModelClass = 'OPNsense\\IndustrialWhitelist\\IndustrialWhitelist';

    public function searchItemAction()
    {
        return $this->searchBase('rules.rule', ['enabled', 'source', 'destination', 'protocol', 'AllowedFunctionCodes', 'StrictDPI', 'description', 'sequence'], 'sequence');
    }

    public function setItemAction($uuid)
    {
        return $this->setBase('rule', 'rules.rule', $uuid);
    }

    public function addItemAction()
    {
        return $this->addBase('rule', 'rules.rule');
    }

    public function getItemAction($uuid = null)
    {
        return $this->getBase('rule', 'rules.rule', $uuid);
    }

    public function delItemAction($uuid)
    {
        return $this->delBase('rules.rule', $uuid);
    }

    public function toggleItemAction($uuid, $enabled = null)
    {
        return $this->toggleBase('rules.rule', $uuid, $enabled);
    }

    public function setSequenceAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed'];
        }

        $uuids = $this->request->getPost('uuids');
        if (!is_array($uuids)) {
            return ['status' => 'failed'];
        }

        $model = $this->getModel();
        $sequence = 1;
        foreach ($uuids as $uuid) {
            $node = $model->getNodeByReference('rules.rule.' . $uuid);
            if ($node !== null) {
                $node->sequence = (string)$sequence;
                $sequence++;
            }
        }

        $model->serializeToConfig();
        Config::getInstance()->save();

        return ['status' => 'ok'];
    }
}
