<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification;

use OPNsense\Base\IndexController as BaseUIController;
use OPNsense\Core\Config;

/**
 * Class FlowsController
 *
 * Page controller for the Active Flows page.
 * All flow data is loaded asynchronously via the API controllers;
 * this controller only renders the Volt template.
 *
 * @access page-services-app-identification
 */
class FlowsController extends BaseUIController
{
	/**
	 * Render the active flows page.
	 *
	 * @access page-services-app-identification
	 *
	 * @return void
	 * @throws \Exception
	 */
	public function indexAction()
	{
		$interfaces = [];
		foreach (Config::getInstance()->object()->interfaces->children() as $key => $node) {
			$ifname = (string)$node->if;
			if ($ifname === '') {
				continue;
			}
			$interfaces[] = [
				'id' => $ifname,
				'label' => !empty((string)$node->descr) ? (string)$node->descr : $key,
			];
		}
		$this->view->interfaces = $interfaces;
		$this->view->pick('OPNsense/AppIdentification/flows');
	}
}
