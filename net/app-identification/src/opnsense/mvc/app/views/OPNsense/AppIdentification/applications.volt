{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<script>
	$(document).ready(function () {
		'use strict';

		let l7Chart = null;

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

		function loadAppList(data) {
			const tbody = $('#app-list-body');
			tbody.empty();

			if (!data || !Array.isArray(data.labels) || data.labels.length === 0) {
				tbody.append('<tr><td colspan="3" class="text-center text-muted">{{ lang._('暂无数据') }}</td></tr>');
				return;
			}

			const series = Array.isArray(data.series) ? data.series : [];
			const total = series.reduce(function (sum, value) {
				return sum + Number(value || 0);
			}, 0);
			let rows = '';

			data.labels.forEach(function (label, idx) {
				const bytes = Number(series[idx] || 0);
				const percent = total > 0 ? (bytes / total * 100).toFixed(1) : '0.0';
				rows += '<tr>' +
					'<td>' + esc(label) + '</td>' +
					'<td>' + esc(bytesToSize(bytes)) + '</td>' +
					'<td>' + esc(percent + '%') + '</td>' +
					'</tr>';
			});

			tbody.html(rows);
		}

		function renderL7Chart(data) {
			if (l7Chart !== null && typeof l7Chart.destroy === 'function') {
				l7Chart.destroy();
				l7Chart = null;
			}

			if (!data || !Array.isArray(data.labels) || data.labels.length === 0) {
				$('#l7-chart').html('<p class="text-muted text-center">{{ lang._('暂无应用流量数据') }}</p>');
				return;
			}

			$('#l7-chart').html('');

			if (typeof ApexCharts === 'undefined') {
				if (typeof Chart === 'undefined') {
					$('#l7-chart').html('<p class="text-muted text-center">{{ lang._('图表组件未加载，无法显示图表') }}</p>');
					return;
				}

				$('#l7-chart').html('<canvas id="l7-chart-canvas" style="height:300px;"></canvas>');
				l7Chart = new Chart(document.getElementById('l7-chart-canvas').getContext('2d'), {
					type: 'doughnut',
					data: {
						labels: data.labels || [],
						datasets: [{
							data: data.series || [],
							backgroundColor: data.colors || undefined,
							borderWidth: 0
						}]
					},
					options: {
						responsive: true,
						maintainAspectRatio: false,
						plugins: {
							legend: {
								position: 'bottom'
							},
							tooltip: {
								callbacks: {
									label: function (context) {
										return context.label + ': ' + bytesToSize(context.parsed);
									}
								}
							}
						}
					}
				});
				return;
			}

			const options = {
				chart: {
					type: 'donut',
					height: 300
				},
				series: data.series || [],
				labels: data.labels || [],
				colors: data.colors || undefined,
				tooltip: {
					y: {
						formatter: function (val) {
							return bytesToSize(val);
						}
					}
				},
				legend: {
					position: 'bottom'
				},
				dataLabels: {
					formatter: function (val, opts) {
						return opts.w.globals.labels[opts.seriesIndex] + ': ' + val.toFixed(1) + '%';
					}
				}
			};

			l7Chart = new ApexCharts(document.querySelector('#l7-chart'), options);
			l7Chart.render();
		}

		function loadL7Chart() {
			ajaxCall('/api/appidentification/applications/getL7Stats', {}, function (response) {
				if (!response || response.status === 'error') {
					showApiError('{{ lang._('加载应用数据失败') }}', (response && response.message) ? response.message : '{{ lang._('Unable to load application data') }}', loadL7Chart);
					return;
				}

				const data = response.data || {};
				if (!data.labels) {
					$('#l7-chart').html('<p class="text-muted text-center">{{ lang._('暂无应用流量数据') }}</p>');
					loadAppList(data);
					return;
				}

				renderL7Chart(data);
				loadAppList(data);
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
					loadL7Chart();
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
							loadL7Chart();
						});
					});
				}
			);
		});

		$('#reload-app-data').on('click', function () {
			loadL7Chart();
			loadRules();
		});

		$('#applyRulesAct').SimpleActionButton({
			onAction: function () {
				loadRules();
				loadL7Chart();
			}
		});

		loadL7Chart();
		loadRules();

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
			<h3>{{ lang._('Top 10 应用流量分布') }}</h3>
			<div id="l7-chart" style="min-height:300px;"></div>
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
					<th>{{ lang._('总流量') }}</th>
					<th>{{ lang._('占比') }}</th>
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
