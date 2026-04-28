<?php

namespace OPNsense\Antivirus\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'general';
    protected static $internalModelClass = 'OPNsense\Antivirus\General';

    protected function setActionHook()
    {
        $enabled = (string)$this->getModel()->general->enabled === '1' ? 'YES' : 'NO';
        file_put_contents('/etc/rc.conf.d/antivirus', sprintf("antivirus_enable=\"%s\"\n", $enabled));
    }
}
