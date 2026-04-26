<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification;

use OPNsense\Base\IndexController as BaseIndexController;

/**
 * Class IndexController
 *
 * Page controller for the Settings (configuration) page.
 */
class IndexController extends BaseIndexController
{
	/**
	 * Render the general settings page.
	 *
	 * Loads the AppIdentification model and passes current configuration
	 * values together with the form definition to the view.
	 *
	 * @return void
	 * @throws \Exception
	 */
	public function indexAction()
	{
		$this->view->generalForm = $this->getForm('general');
		$this->view->pick('OPNsense/AppIdentification/index');
	}
}
