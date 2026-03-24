<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'industrialwhitelist';
    protected static $internalModelClass = 'OPNsense\\IndustrialWhitelist\\IndustrialWhitelist';

    public function getAction()
    {
        return [
            'industrialwhitelist' => [
                'general' => $this->getModel()->general->getNodes()
            ]
        ];
    }
}
