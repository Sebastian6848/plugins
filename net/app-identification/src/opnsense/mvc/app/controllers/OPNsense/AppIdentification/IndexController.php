<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification;

use OPNsense\Base\IndexController as BaseUIController;

/**
 * Class IndexController
 *
 * Page controller for the Settings (configuration) page.
 *
 * @access page-services-app-identification
 */
class IndexController extends BaseUIController
{
	/**
	 * @var AppIdentification
	 */
	private $model;

	/**
	 * Initialize model.
	 */
	public function initialize()
	{
		parent::initialize();
		$this->model = new AppIdentification();
	}

	/**
	 * Render the general settings page.
	 *
	 * Loads the AppIdentification model and passes current configuration
	 * values together with the form definition to the view.
	 *
	 * @access page-services-app-identification
	 *
	 * @return void
	 * @throws \Exception
	 */
	public function indexAction()
	{
		$this->view->currentConfig = $this->model->getNodes();
		$this->view->generalForm = $this->getForm('general');
		$this->view->pick('OPNsense/AppIdentification/index');
	}
}
