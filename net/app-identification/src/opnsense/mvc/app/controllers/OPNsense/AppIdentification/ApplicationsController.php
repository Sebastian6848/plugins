<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification;

use OPNsense\AppIdentification\Api\ApplicationsController as ApplicationsApiController;
use OPNsense\Base\IndexController as BaseUIController;

/**
 * Class ApplicationsController
 *
 * Page controller for the Applications page (L7 statistics).
 *
 * @access page-services-app-identification
 */
class ApplicationsController extends BaseUIController
{
	/**
	 * @var ApplicationsApiController
	 */
	private $api;

	/**
	 * Initialize page dependencies.
	 *
	 * @access page-services-app-identification
	 */
	public function initialize()
	{
		parent::initialize();
		$this->api = new ApplicationsApiController();
	}

	/**
	 * Render the applications page.
	 *
	 * Application data and category lists are fetched asynchronously by the
	 * frontend via the API controllers.
	 *
	 * @access page-services-app-identification
	 *
	 * @return void
	 * @throws \Exception
	 */
	public function indexAction()
	{
		$categories = $this->api->categoriesAction();
		$this->view->categories = $categories['rows'] ?? [];
		$this->view->pick('OPNsense/AppIdentification/applications');
	}
}
