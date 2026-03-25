<?php

namespace OPNsense\AntiVirus;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/AntiVirus/index');
        $this->view->formBasic = $this->getForm('basic');
        $this->view->formTuning = $this->getForm('tuning');
        $this->view->formDialogHash = $this->getForm('dialogHash');
        $this->view->formGridHash = $this->getFormGrid('dialogHash');
    }

    public function recordsAction()
    {
        $this->view->pick('OPNsense/AntiVirus/records');
    }
}