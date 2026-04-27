{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<script>
	$(document).ready(function () {
		'use strict';

		function showApiError(title, message, retryFn) {
			const buttons = [{
				label: '{{ lang._('Close') }}',
				action: function (dialog) {
					dialog.close();
				}
			}];

			if (typeof retryFn === 'function') {
				buttons.unshift({
					label: '{{ lang._('Retry') }}',
					cssClass: 'btn-primary',
					action: function (dialog) {
						dialog.close();
						retryFn();
					}
				});
			}

			BootstrapDialog.show({
				type: BootstrapDialog.TYPE_DANGER,
				title: title,
				message: esc(message || '{{ lang._('Unknown error') }}'),
				buttons: buttons
			});
		}

		function esc(value) {
			return $('<div/>').text(value === null || value === undefined ? '' : String(value)).html();
		}

		function bytesToSize(bytes) {
			let value = Number(bytes || 0);
			const units = ['B', 'KB', 'MB', 'GB', 'TB'];
			let idx = 0;
			if (value === 0) {
				return '0 B';
			}
			while (value >= 1024 && idx < units.length - 1) {
				value /= 1024;
				idx += 1;
			}
			return value.toFixed(2) + ' ' + units[idx];
		}

		function normalizeColor(color) {
			const value = String(color || '').replace(/cc$/i, '');
			return /^#[0-9a-f]{3,8}$/i.test(value) ? value : '#337ab7';
		}

		function renderL7StatsTable(data) {
			const tbody = $('#l7-stats-body');

			if (!data || !Array.isArray(data.labels) || data.labels.length === 0) {
				tbody.html('<tr><td colspan="4" class="text-center text-muted">{{ lang._('暂无应用流量数据') }}</td></tr>');
				return;
			}

			const labels = data.labels || [];
			const series = Array.isArray(data.series) ? data.series : [];
			const colors = Array.isArray(data.colors) ? data.colors : [];
			const total = series.reduce(function (sum, value) {
				return sum + Number(value || 0);
			}, 0);
			const maxVal = Number(series[0] || 1);
			let rows = '';

			labels.slice(0, 10).forEach(function (label, idx) {
				const bytes = Number(series[idx] || 0);
				const percent = total > 0 ? (bytes / total * 100).toFixed(1) : '0.0';
				const barW = maxVal > 0 ? (bytes / maxVal * 100).toFixed(1) : '0.0';
				const color = normalizeColor(colors[idx]);

				rows += '<tr>' +
					'<td>' + esc(label) + '</td>' +
					'<td>' + esc(bytesToSize(bytes)) + '</td>' +
					'<td>' + esc(percent + '%') + '</td>' +
					'<td style="width:200px;">' +
					'<div style="background:' + color + ';width:' + barW + '%;height:14px;border-radius:3px;min-width:2px;"></div>' +
					'</td>' +
					'</tr>';
			});

			tbody.html(rows);
		}

		function loadL7Stats() {
			ajaxCall('/api/appidentification/applications/getL7Stats', {}, function (response) {
				if (!response || response.status === 'error') {
					$('#l7-stats-body').html('<tr><td colspan="4" class="text-center text-muted">{{ lang._('暂无应用流量数据') }}</td></tr>');
					showApiError('{{ lang._('加载应用数据失败') }}', (response && response.message) ? response.message : '{{ lang._('Unable to load application data') }}', loadL7Stats);
					return;
				}

				const data = response.data || {};
				if (!data.labels) {
					renderL7StatsTable(data);
					return;
				}

				renderL7StatsTable(data);
			});
		}

		function renderHostRole(host) {
			const asClient = Number(host.as_client || 0);
			const asServer = Number(host.as_server || 0);
			if (asClient > 0 && asServer > 0) {
				return '<span class="label label-info">{{ lang._('双向') }}</span>';
			}
			if (asClient > 0) {
				return '<span class="label label-primary">{{ lang._('客户端') }}</span>';
			}
			return '<span class="label label-success">{{ lang._('服务器') }}</span>';
		}

		function loadTopHosts() {
			ajaxCall('/api/appidentification/applications/getTopHosts', {}, function (response) {
				if (!response || response.status !== 'ok' || !Array.isArray(response.data) || response.data.length === 0) {
					$('#top-hosts-body').html('<tr><td colspan="5" class="text-center text-muted">{{ lang._('暂无主机数据') }}</td></tr>');
					return;
				}

				let rows = '';
				response.data.forEach(function (host) {
					const ip = host.ip || '';
					const name = host.name && host.name !== ip ? host.name : '-';
					rows += '<tr>' +
						'<td><code>' + esc(ip) + '</code></td>' +
						'<td>' + esc(name) + '</td>' +
						'<td>' + esc(host.flows || 0) + '</td>' +
						'<td>' + esc(host.bytes_fmt || bytesToSize(host.bytes || 0)) + '</td>' +
						'<td>' + renderHostRole(host) + '</td>' +
						'</tr>';
				});

				$('#top-hosts-body').html(rows);
			});
		}

		function renderRuleTable(rows) {
			const tbody = $('#custom-rule-body');
			tbody.empty();

			if (!Array.isArray(rows) || rows.length === 0) {
				tbody.append('<tr><td colspan="4">{{ lang._('No custom rules configured') }}</td></tr>');
				return;
			}

			rows.forEach(function (row) {
				const parts = String(row.rule || '').split(/\t|:/, 2);
				const host = parts[0] || row.rule || '';
				const appName = parts[1] || '';

				const actionButtons =
					'<button type="button" class="btn btn-xs btn-default" data-action="edit" data-index="' + esc(row.index) + '"><span class="fa fa-pencil"></span></button> ' +
					'<button type="button" class="btn btn-xs btn-default" data-action="delete" data-index="' + esc(row.index) + '"><span class="fa fa-trash"></span></button>';

				tbody.append(
					'<tr>' +
					'<td>' + esc(host) + '</td>' +
					'<td>' + esc(appName) + '</td>' +
					'<td><code>' + esc(row.rule || '') + '</code></td>' +
					'<td>' + actionButtons + '</td>' +
					'</tr>'
				);
			});
		}

		function loadRules() {
			ajaxCall('/api/appidentification/applications/customRules', {}, function (data) {
				if (!data || data.status === 'error') {
					showApiError('{{ lang._('加载自定义规则失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to load custom rules') }}', loadRules);
					return;
				}
				renderRuleTable((data && Array.isArray(data.rows)) ? data.rows : []);
			});
		}

		function applyRulesAfterSave(onDone, onFail) {
			BootstrapDialog.show({
				type: BootstrapDialog.TYPE_INFO,
				title: '{{ lang._('Processing') }}',
				message: '{{ lang._('规则已保存，正在应用...') }}',
				closable: false,
				draggable: false,
				onshown: function (dialogRef) {
					ajaxCall('/api/appidentification/applications/applyRules', {}, function (data) {
						dialogRef.close();
						if (!data || data.status === 'error') {
							if (typeof onFail === 'function') {
								onFail();
							}
							showApiError('{{ lang._('应用规则失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to apply custom rules') }}', function () {
								applyRulesAfterSave(onDone, onFail);
							});
							return;
						}

						BootstrapDialog.show({
							type: BootstrapDialog.TYPE_PRIMARY,
							title: '{{ lang._('Success') }}',
							message: '{{ lang._('规则已生效') }}',
							buttons: [{
								label: '{{ lang._('Close') }}',
								action: function (d) {
									d.close();
								}
							}]
						});

						if (typeof onDone === 'function') {
							onDone();
						}
					});
				}
			});
		}

		function openRuleDialog(index) {
			let endpoint = '/api/appidentification/applications/getCustomRule';
			if (typeof index === 'number' && index >= 0) {
				endpoint += '/' + index;
			}

			mapDataToFormUI({'frm_DialogRule': endpoint}).done(function () {
				clearFormValidation('frm_DialogRule');
				$('.selectpicker').selectpicker('refresh');
				$('#DialogRule').modal({backdrop: 'static', keyboard: false});
			});
		}

		$('#btn_DialogRule_save').off('click').on('click', function () {
			const $saveButton = $('#btn_DialogRule_save');
			saveFormToEndpoint('/api/appidentification/applications/saveCustomRuleForm', 'frm_DialogRule', function () {
				$saveButton.prop('disabled', true);
				applyRulesAfterSave(function () {
					$saveButton.prop('disabled', false);
					$('#DialogRule').modal('hide');
					loadRules();
					loadL7Stats();
					loadTopHosts();
				}, function () {
					$saveButton.prop('disabled', false);
				});
			}, true, function () {
				$saveButton.prop('disabled', false);
				showApiError('{{ lang._('保存规则失败') }}', '{{ lang._('Unable to save custom rule') }}');
			});
		});

		$('#add-custom-rule').on('click', function () {
			openRuleDialog(-1);
		});

		$('#custom-rule-body').on('click', 'button[data-action=edit]', function () {
			const index = Number($(this).data('index'));
			openRuleDialog(index);
		});

		$('#custom-rule-body').on('click', 'button[data-action=delete]', function () {
			const index = Number($(this).data('index'));
			stdDialogConfirm(
				'{{ lang._('Confirmation Required') }}',
				'{{ lang._('Delete this custom rule?') }}',
				'{{ lang._('Yes') }}',
				'{{ lang._('Cancel') }}',
				function () {
					ajaxCall('/api/appidentification/applications/saveCustomRule', {
						action: 'delete',
						index: index
					}, function (data) {
						if (!data || data.status === 'error') {
							showApiError('{{ lang._('删除规则失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to delete custom rule') }}');
							return;
						}
						applyRulesAfterSave(function () {
							loadRules();
							loadL7Stats();
							loadTopHosts();
						});
					});
				}
			);
		});

		$('#reload-app-data').on('click', function () {
			loadL7Stats();
			loadTopHosts();
			loadRules();
		});

		$('#applyRulesAct').SimpleActionButton({
			onAction: function () {
				loadRules();
				loadL7Stats();
				loadTopHosts();
			}
		});

		loadL7Stats();
		loadTopHosts();
		loadRules();
		setInterval(function () {
			loadL7Stats();
			loadTopHosts();
		}, 30000);

		$(document).ajaxError(function (event, xhr, settings) {
			if (settings && settings.url && settings.url.indexOf('/api/appidentification/') === 0) {
				const msg = xhr.responseJSON ? xhr.responseJSON.message : '{{ lang._('网络请求失败') }}';
				showApiError('{{ lang._('加载失败') }}', msg);
			}
		});
	});
</script>

<div class="content-box">
	<div class="row">
		<div class="col-md-12">
			<h4>{{ lang._('Top 10 应用流量分布') }}</h4>
			<table class="table table-striped table-condensed">
				<thead>
				<tr>
					<th>{{ lang._('应用名称') }}</th>
					<th>{{ lang._('总流量') }}</th>
					<th>{{ lang._('占比') }}</th>
					<th>{{ lang._('流量条') }}</th>
				</tr>
				</thead>
				<tbody id="l7-stats-body">
				<tr>
					<td colspan="4" class="text-center text-muted">{{ lang._('加载中...') }}</td>
				</tr>
				</tbody>
			</table>
		</div>
	</div>

	<hr/>

	<div class="row">
		<div class="col-md-12">
			<div class="pull-right" style="margin-bottom: 8px;">
				<button id="reload-app-data" type="button" class="btn btn-default btn-xs">
					<span class="fa fa-refresh"></span> {{ lang._('Refresh') }}
				</button>
			</div>
			<h4>{{ lang._('Top 10 主机流量排行') }}</h4>
			<table class="table table-condensed table-hover table-striped table-responsive">
				<thead>
				<tr>
					<th>{{ lang._('IP 地址') }}</th>
					<th>{{ lang._('主机名') }}</th>
					<th>{{ lang._('活跃流') }}</th>
					<th>{{ lang._('总流量') }}</th>
					<th>{{ lang._('角色') }}</th>
				</tr>
				</thead>
				<tbody id="top-hosts-body">
				<tr>
					<td colspan="5" class="text-center text-muted">{{ lang._('加载中...') }}</td>
				</tr>
				</tbody>
			</table>
		</div>
	</div>

	<hr/>

	<div class="row">
		<div class="col-md-12">
			<div class="pull-right" style="margin-bottom: 8px;">
				<button id="add-custom-rule" type="button" class="btn btn-xs btn-primary">
					<span class="fa fa-plus"></span> {{ lang._('添加规则') }}
				</button>
			</div>
			<h3>{{ lang._('自定义规则') }}</h3>
			<table class="table table-condensed table-hover table-striped table-responsive">
				<thead>
				<tr>
					<th>{{ lang._('Host') }}</th>
					<th>{{ lang._('Application Name') }}</th>
					<th>{{ lang._('Raw Rule') }}</th>
					<th style="width: 110px;">{{ lang._('操作') }}</th>
				</tr>
				</thead>
				<tbody id="custom-rule-body"></tbody>
			</table>
		</div>
	</div>
</div>

<section class="page-content-main">
	<div class="content-box">
		<div class="col-md-12">
			<button class="btn btn-primary" id="applyRulesAct"
					data-endpoint="/api/appidentification/applications/applyRules"
					data-label="{{ lang._('应用规则') }}"
					data-error-title="{{ lang._('Error applying rules') }}"
					type="button"></button>
			<small class="text-muted" style="display:block; margin-top: 8px;">{{ lang._('通常情况下保存规则后会自动应用，此按钮用于手动重试。') }}</small>
			<br/><br/>
		</div>
	</div>
</section>

{{ partial("layout_partials/base_dialog",['fields':formDialogRule,'id':'DialogRule','label':lang._('Edit Custom Rule')]) }}
