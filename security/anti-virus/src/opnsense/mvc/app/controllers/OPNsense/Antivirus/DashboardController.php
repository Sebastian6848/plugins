<?php

namespace OPNsense\Antivirus;

use OPNsense\Base\ControllerBase;

class DashboardController extends ControllerBase
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/Antivirus/dashboard');
    }
}
