<?php

namespace OPNsense\Antivirus;

class GeneralController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->generalForm = $this->getForm("general");
        $this->view->advancedForm = $this->getForm("advanced");
        $this->view->pick('OPNsense/Antivirus/general');
    }
}
