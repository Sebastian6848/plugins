<?php

namespace OPNsense\Antivirus;

use OPNsense\Base\ControllerBase;

class GeneralController extends ControllerBase
{
    public function indexAction()
    {
        $this->view->generalForm = $this->getForm("general");
        $this->view->pick('OPNsense/Antivirus/general');
    }

    public function advancedAction()
    {
        $this->view->advancedForm = $this->getForm("advanced");
        $this->view->pick('OPNsense/Antivirus/advanced');
    }

    public function dashboardAction()
    {
        $this->view->pick('OPNsense/Antivirus/dashboard');
    }

    public function logAction()
    {
        $this->view->pick('OPNsense/Antivirus/log');
    }
}
