<?php

namespace OPNsense\Antivirus\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class GeneralController extends ApiMutableModelControllerBase
{
    protected static $internalModelClass = '\OPNsense\Antivirus\Antivirus';
    protected static $internalModelName = 'antivirus';
}
