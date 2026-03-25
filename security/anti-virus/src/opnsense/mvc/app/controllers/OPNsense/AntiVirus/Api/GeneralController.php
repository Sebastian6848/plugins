<?php

namespace OPNsense\AntiVirus\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class GeneralController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'antivirus';
    protected static $internalModelClass = 'OPNsense\\AntiVirus\\AntiVirus';

    public function getAction()
    {
        return [
            'antivirus' => [
                'general' => $this->getModel()->general->getNodes()
            ]
        ];
    }
}