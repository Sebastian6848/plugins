<?php

namespace OPNsense\Antivirus;

use OPNsense\Base\ControllerBase;

class AdvancedController extends ControllerBase
{
    public function indexAction()
    {
        $this->view->advancedForm = $this->getForm("advanced");
        $this->view->pick('OPNsense/Antivirus/advanced');
    }
}
