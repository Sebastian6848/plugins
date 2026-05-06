<?php

namespace OPNsense\IndProto;

use OPNsense\Base\IndexController as BaseIndexController;

class LogsController extends BaseIndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/IndProto/logs');
    }
}
