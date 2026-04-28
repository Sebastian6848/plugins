<?php

namespace OPNsense\Antivirus;

use OPNsense\Base\ControllerBase;

class LogController extends ControllerBase
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/Antivirus/log');
    }
}
