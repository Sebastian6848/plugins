<?php

namespace OPNsense\AntiVirus\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class HashesController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'antivirus';
    protected static $internalModelClass = 'OPNsense\\AntiVirus\\AntiVirus';

    public function searchItemAction()
    {
        return $this->searchBase('whitelist.entry', ['enabled', 'sha256', 'description'], 'sha256');
    }

    public function setItemAction($uuid)
    {
        return $this->setBase('entry', 'whitelist.entry', $uuid);
    }

    public function addItemAction()
    {
        return $this->addBase('entry', 'whitelist.entry');
    }

    public function getItemAction($uuid = null)
    {
        return $this->getBase('entry', 'whitelist.entry', $uuid);
    }

    public function delItemAction($uuid)
    {
        return $this->delBase('whitelist.entry', $uuid);
    }

    public function toggleItemAction($uuid, $enabled = null)
    {
        return $this->toggleBase('whitelist.entry', $uuid, $enabled);
    }
}