<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

/**
 * Class RuleController
 *
 * CRUD endpoints for custom application identification rules.
 */
class RuleController extends ApiMutableModelControllerBase
{
	protected static $internalModelName = 'appidentification';
	protected static $internalModelClass = '\OPNsense\AppIdentification\AppIdentification';

	public function searchRulesAction()
	{
		return $this->searchBase('rules.rule', ['enabled', 'description', 'match_type', 'match_value', 'app_label']);
	}

	public function getRuleAction($uuid = null)
	{
		return $this->getBase('rule', 'rules.rule', $uuid);
	}

	public function addRuleAction()
	{
		return $this->addBase('rule', 'rules.rule');
	}

	public function setRuleAction($uuid)
	{
		return $this->setBase('rule', 'rules.rule', $uuid);
	}

	public function delRuleAction($uuid)
	{
		return $this->delBase('rules.rule', $uuid);
	}

	public function toggleRuleAction($uuid)
	{
		return $this->toggleBase('rules.rule', $uuid);
	}

	public function listAction(): array
	{
		$model = $this->getModel();
		$rules = [];

		foreach ($model->rules->rule->iterateItems() as $uuid => $rule) {
			if ((string)$rule->enabled !== '1') {
				continue;
			}

			$rules[] = [
				'uuid' => (string)$uuid,
				'enabled' => (string)$rule->enabled,
				'description' => (string)$rule->description,
				'match_type' => (string)$rule->match_type,
				'match_value' => (string)$rule->match_value,
				'app_label' => (string)$rule->app_label
			];
		}

		return ['rules' => $rules];
	}
}
