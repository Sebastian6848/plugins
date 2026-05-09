<?php

/*
 * Minimal domain matching checks for os-app-identification.
 */

function normalize_domain(string $value): string
{
	$value = strtolower(trim($value));
	if ($value === '') {
		return '';
	}

	if (strpos($value, '://') !== false) {
		$host = parse_url($value, PHP_URL_HOST);
		$value = is_string($host) ? $host : $value;
	} elseif (strpos($value, '/') !== false) {
		$host = parse_url('http://' . $value, PHP_URL_HOST);
		$value = is_string($host) ? $host : $value;
	}

	if (preg_match('/^\[([^\]]+)\](?::\d+)?$/', $value, $matches)) {
		$value = $matches[1];
	} elseif (substr_count($value, ':') === 1) {
		$parts = explode(':', $value, 2);
		if (ctype_digit($parts[1])) {
			$value = $parts[0];
		}
	}

	return rtrim(trim($value), '.');
}

function ends_with_value(string $value, string $suffix): bool
{
	return $suffix === '' || substr($value, -strlen($suffix)) === $suffix;
}

function domain_rule_matches(string $host, string $ruleDomain): bool
{
	$host = normalize_domain($host);
	$rawRule = strtolower(trim($ruleDomain));
	if ($host === '' || $rawRule === '') {
		return false;
	}

	if (strpos($rawRule, '*.') === 0) {
		$base = normalize_domain(substr($rawRule, 2));
		return $base !== '' && $host !== $base && ends_with_value($host, '.' . $base);
	}

	if (strpos($rawRule, '.') === 0) {
		$base = normalize_domain(substr($rawRule, 1));
		return $base !== '' && ($host === $base || ends_with_value($host, '.' . $base));
	}

	$base = normalize_domain($rawRule);
	return $base !== '' && ($host === $base || ends_with_value($host, '.' . $base));
}

function domain_specificity(string $value): array
{
	$value = strtolower(trim($value));
	if (strpos($value, '*.') === 0) {
		$value = substr($value, 2);
	} elseif (strpos($value, '.') === 0) {
		$value = substr($value, 1);
	}

	$domain = normalize_domain($value);
	return [
		'labels' => $domain === '' ? 0 : substr_count($domain, '.') + 1,
		'length' => strlen($domain),
	];
}

function sort_rules(array $rules): array
{
	foreach ($rules as $index => &$rule) {
		$rule['_order'] = $index;
		$spec = domain_specificity($rule['domain']);
		$rule['_labels'] = $spec['labels'];
		$rule['_length'] = $spec['length'];
	}
	unset($rule);

	usort($rules, function ($left, $right) {
		$result = $right['_labels'] <=> $left['_labels'];
		if ($result !== 0) {
			return $result;
		}
		$result = $right['_length'] <=> $left['_length'];
		if ($result !== 0) {
			return $result;
		}
		return $left['_order'] <=> $right['_order'];
	});

	return $rules;
}

function identify_domain(string $host, array $rules): ?string
{
	foreach (sort_rules($rules) as $rule) {
		if (domain_rule_matches($host, $rule['domain'])) {
			return $rule['name'];
		}
	}
	return null;
}

$cases = [
	['google.com', 'le.com', false],
	['le.com', 'le.com', true],
	['www.le.com', 'le.com', true],
	['video.le.com', 'le.com', true],
	['example-le.com', 'le.com', false],
	['api.qq.com', '*.qq.com', true],
	['qq.com', '*.qq.com', false],
	['qq.com', '.qq.com', true],
];

foreach ($cases as $case) {
	[$host, $rule, $expected] = $case;
	$actual = domain_rule_matches($host, $rule);
	if ($actual !== $expected) {
		fwrite(STDERR, sprintf("FAIL: host=%s rule=%s expected=%s actual=%s\n", $host, $rule, $expected ? 'true' : 'false', $actual ? 'true' : 'false'));
		exit(1);
	}
}

$rules = [
	['domain' => 'le.com', 'name' => 'LeTV'],
	['domain' => 'google.com', 'name' => 'Google'],
	['domain' => 'mail.google.com', 'name' => 'Google Mail'],
];
if (identify_domain('mail.google.com', $rules) !== 'Google Mail') {
	fwrite(STDERR, "FAIL: mail.google.com did not prefer mail.google.com\n");
	exit(1);
}
if (identify_domain('www.google.com', $rules) !== 'Google') {
	fwrite(STDERR, "FAIL: www.google.com did not prefer google.com\n");
	exit(1);
}

$rules = [
	['domain' => 'qq.com', 'name' => 'QQ'],
	['domain' => 'video.qq.com', 'name' => 'QQ Video'],
	['domain' => 'api.video.qq.com', 'name' => 'QQ Video API'],
];
if (identify_domain('api.video.qq.com', $rules) !== 'QQ Video API') {
	fwrite(STDERR, "FAIL: api.video.qq.com did not prefer api.video.qq.com\n");
	exit(1);
}

echo "All domain matching tests passed.\n";
