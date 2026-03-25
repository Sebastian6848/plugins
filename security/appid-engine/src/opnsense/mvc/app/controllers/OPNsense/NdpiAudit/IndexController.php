<?php

namespace OPNsense\NdpiAudit;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/NdpiAudit/index');
        $this->view->generalForm = $this->getForm('general');
    }

    public function recordsAction()
    {
        $this->view->pick('OPNsense/NdpiAudit/records');
    }
}
