<?php

namespace OPNsense\IndProto;

use OPNsense\Base\IndexController as BaseIndexController;

class IndexController extends BaseIndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/IndProto/index');
        $this->view->formGeneral = $this->getForm("general");
        $this->view->formDialogRule = $this->getForm("dialogRule");
        $this->view->formGridRule = $this->getFormGrid("dialogRule");
    }

    public function logsAction()
    {
        $this->view->pick('OPNsense/IndProto/logs');
    }
}
