<?php

namespace OPNsense\IndustrialWhitelist;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/IndustrialWhitelist/index');
        $this->view->formSettings = $this->getForm('settings');
        $this->view->formDialogRule = $this->getForm('dialogRule');
        $this->view->formGridRule = $this->getFormGrid('dialogRule');
    }

    public function logsAction()
    {
        $this->view->pick('OPNsense/IndustrialWhitelist/logs');
    }
}
