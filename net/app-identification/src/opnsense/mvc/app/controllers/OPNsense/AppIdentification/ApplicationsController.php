<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification;

use OPNsense\Base\IndexController as BaseIndexController;

/**
 * Class ApplicationsController
 *
 * Page controller for the Applications page (L7 statistics and custom rules).
 */
class ApplicationsController extends BaseIndexController
{
	/**
	 * Render the applications page.
	 *
	 * Loads the dialogRule form definition for the custom rule edit dialog.
	 * Application data and category lists are fetched asynchronously by the
	 * frontend via the API controllers.
	 *
	 * @return void
	 * @throws \Exception
	 */
	public function indexAction()
	{
		$this->view->formDialogRule = $this->getForm('dialogRule');
		$this->view->pick('OPNsense/AppIdentification/applications');
	}
}
