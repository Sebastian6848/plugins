<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification;

use OPNsense\Base\IndexController as BaseIndexController;

/**
 * Class FlowsController
 *
 * Page controller for the Active Flows page.
 * All flow data is loaded asynchronously via the API controllers;
 * this controller only renders the Volt template.
 */
class FlowsController extends BaseIndexController
{
	/**
	 * Render the active flows page.
	 *
	 * @return void
	 * @throws \Exception
	 */
	public function indexAction()
	{
		$this->view->pick('OPNsense/AppIdentification/flows');
	}
}
