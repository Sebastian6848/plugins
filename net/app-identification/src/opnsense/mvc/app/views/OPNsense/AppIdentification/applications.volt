{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<script>
	$(document).ready(function () {
		'use strict';

		let appChart = null;

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

		function humanBytes(bytes) {
			let value = Number(bytes || 0);
			const units = ['B', 'KB', 'MB', 'GB', 'TB'];
			let idx = 0;
			while (value >= 1024 && idx < units.length - 1) {
				value /= 1024;
				idx += 1;
			}
			return value.toFixed(2) + ' ' + units[idx];
		}

		function renderTopChart(rows) {
			const topRows = rows
				.slice()
				.sort(function (a, b) {
					return Number(b.bytes || 0) - Number(a.bytes || 0);
				})
				.slice(0, 10);

			const labels = topRows.map(function (row) {
				return row.name || '{{ lang._('Unknown') }}';
			});
			const data = topRows.map(function (row) {
				return Number(row.bytes || 0);
			});

			const colors = ['#2f7ed8', '#0d233a', '#8bbc21', '#910000', '#1aadce', '#492970', '#f28f43', '#77a1e5', '#c42525', '#a6c96a'];
			const ctx = document.getElementById('app-top10-chart').getContext('2d');

			if (appChart !== null) {
				appChart.destroy();
			}

			appChart = new Chart(ctx, {
				type: 'bar',
				data: {
					labels: labels,
					datasets: [{
						label: '{{ lang._('Total Traffic') }}',
						data: data,
						backgroundColor: colors.slice(0, labels.length),
						borderWidth: 0
					}]
				},
				options: {
					responsive: true,
					maintainAspectRatio: false,
					legend: {
						display: false
					},
					scales: {
						yAxes: [{
							ticks: {
								beginAtZero: true,
								callback: function (value) {
									return humanBytes(value);
								}
							}
						}]
					},
					tooltips: {
						callbacks: {
							label: function (tooltipItem) {
								return '{{ lang._('Traffic') }}: ' + humanBytes(tooltipItem.yLabel);
							}
						}
					}
				}
			});
		}

		function renderApplicationTable(rows) {
			const tbody = $('#app-list-body');
			tbody.empty();

			if (!Array.isArray(rows) || rows.length === 0) {
				tbody.append('<tr><td colspan="6">{{ lang._('No application data available') }}</td></tr>');
				return;
			}

			rows.sort(function (a, b) {
				return Number(b.bytes || 0) - Number(a.bytes || 0);
			});

			rows.forEach(function (row) {
				const tr = '<tr>' +
					'<td>' + esc(row.name || '') + '</td>' +
					'<td>' + esc(row.category || 'Uncategorized') + '</td>' +
					'<td>' + esc(row.flows || 0) + '</td>' +
					'<td>' + esc(humanBytes(row.bytes || 0)) + '</td>' +
					'<td>' + esc(humanBytes(row.up_bytes || 0)) + '</td>' +
					'<td>' + esc(humanBytes(row.down_bytes || 0)) + '</td>' +
					'</tr>';
				tbody.append(tr);
			});
		}

		function loadApplications() {
			ajaxCall('/api/appidentification/applications/list', {}, function (data) {
				if (!data || data.status === 'error') {
					showApiError('{{ lang._('加载应用数据失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to load application data') }}', loadApplications);
					return;
				}
				const rows = (data && Array.isArray(data.rows)) ? data.rows : [];
				renderTopChart(rows);
				renderApplicationTable(rows);
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
					loadApplications();
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
							loadApplications();
						});
					});
				}
			);
		});

		$('#reload-app-data').on('click', function () {
			loadApplications();
			loadRules();
		});

		$('#applyRulesAct').SimpleActionButton({
			onAction: function () {
				loadRules();
				loadApplications();
			}
		});

		loadApplications();
		loadRules();
	});
</script>

<div class="content-box">
	<div class="row">
		<div class="col-md-12">
			<h3>{{ lang._('Top 10 应用流量分布') }}</h3>
			<div style="height: 300px;">
				<canvas id="app-top10-chart"></canvas>
			</div>
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
			<h3>{{ lang._('应用列表') }}</h3>
			<table class="table table-condensed table-hover table-striped table-responsive">
				<thead>
				<tr>
					<th>{{ lang._('应用名称') }}</th>
					<th>{{ lang._('分类') }}</th>
					<th>{{ lang._('流数量') }}</th>
					<th>{{ lang._('总流量') }}</th>
					<th>{{ lang._('上行') }}</th>
					<th>{{ lang._('下行') }}</th>
				</tr>
				</thead>
				<tbody id="app-list-body"></tbody>
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
