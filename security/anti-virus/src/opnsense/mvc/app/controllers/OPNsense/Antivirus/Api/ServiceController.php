<?php

/*
 * Copyright (C) 2026
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

namespace OPNsense\Antivirus\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Antivirus\Backend\BackendFacade;

/**
 * Class ServiceController
 * @package OPNsense\Antivirus
 */
class ServiceController extends ApiControllerBase
{
    private function backend(): BackendFacade
    {
        return new BackendFacade();
    }

    public function startAction()
    {
        if ($this->request->isPost()) {
            return $this->backend()->run("start");
        }
        return array("status" => "error");
    }

    public function stopAction()
    {
        if ($this->request->isPost()) {
            return $this->backend()->run("stop");
        }
        return array("status" => "error");
    }

    public function restartAction()
    {
        if ($this->request->isPost()) {
            return $this->backend()->run("restart");
        }
        return array("status" => "error");
    }

    public function startServiceAction($service = '')
    {
        if ($this->request->isPost() && in_array($service, array('clamd', 'cicap', 'freshclam', 'squid_icap'))) {
            return $this->backend()->run("start_service", [$service]);
        }
        return array("status" => "error");
    }

    public function reconfigureAction()
    {
        if ($this->request->isPost()) {
            return $this->backend()->run("reload");
        }
        return array("status" => "error");
    }

    public function statusAction()
    {
        $response = $this->backend()->run("status");
        if ($response != null) {
            $response['status'] = (
                ($response['clamd'] ?? '') == 'running' &&
                ($response['cicap'] ?? '') == 'running' &&
                ($response['squid_icap'] ?? '') == 'active'
            ) ? 'running' : 'stopped';
            $response['widget'] = array(
                'caption_start' => gettext('Start Antivirus'),
                'caption_restart' => gettext('Restart Antivirus'),
                'caption_stop' => gettext('Stop Antivirus')
            );
            return $response;
        }
        return array("status" => "stopped", "clamd" => "stopped", "cicap" => "stopped");
    }

    /**
     * load the initial signatures
     * @return array
     */
    public function freshclamAction()
    {
        if ($this->request->isPost()) {
            return $this->backend()->run('freshclam', [$this->request->hasPost('action') ? 'go' : '']);
        } else {
            return array('status' => 'error');
        }
    }

    /**
     * get ClamAV and signature versions
     */
    public function versionAction()
    {
        $infos = array(
            "clamav" => array("Version"),
            "main" => array("main.cvd", "main.cld"),
            "daily" => array("daily.cvd", "daily.cld"),
            "bytecode" => array("bytecode.cvd", "bytecode.cld"),
            "signatures" => array("Total number of signatures")
        );
        $result = array();
        $response = $this->backend()->run("version");
        if ($response != null) {
            foreach ($response as $key => $value) {
                foreach ($infos as $info_key => $info) {
                    if (in_array($key, $info)) {
                        $result[$info_key] = $value;
                    }
                }
            }
            return array("version" => $result);
        } else {
            return array();
        }
    }
}
