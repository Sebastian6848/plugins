{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
	<li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
	<li><a data-toggle="tab" href="#rules">{{ lang._('应用规则') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
	<div id="general" class="tab-pane fade in active">
		<div class="content-box" style="padding-bottom: 1.5em;">
			{{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
			<div class="col-md-12">
				<hr />
				<button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
				<button class="btn btn-default" id="testAct" type="button"><span class="fa fa-plug"></span> {{ lang._('Test Connection') }} <i id="testAct_progress"></i></button>
				<button class="btn btn-default" id="restartAct" type="button"><span class="fa fa-refresh"></span> {{ lang._('Restart ntopng') }} <i id="restartAct_progress"></i></button>
			</div>
		</div>
	</div>
	<div id="rules" class="tab-pane fade">
		<div class="content-box" style="padding-bottom: 1.5em;">
			<div class="row" style="margin-bottom: 10px;">
				<div class="col-md-6">
					<button id="grid-rules-add" type="button" class="btn btn-success btn-sm">
						<span class="fa fa-plus"></span> {{ lang._('新增规则') }}
					</button>
					<button id="rules-import-open" type="button" class="btn btn-primary btn-sm">
						<span class="fa fa-upload"></span> {{ lang._('批量导入') }}
					</button>
					<div class="btn-group">
						<button type="button" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">
							<span class="fa fa-download"></span> {{ lang._('下载模板') }} <span class="caret"></span>
						</button>
						<ul class="dropdown-menu">
							<li><a href="/api/appidentification/rule/template/csv">{{ lang._('CSV 模板') }}</a></li>
							<li><a href="/api/appidentification/rule/template/json">{{ lang._('JSON 模板') }}</a></li>
						</ul>
					</div>
					<div class="btn-group">
						<button type="button" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">
							<span class="fa fa-share-square-o"></span> {{ lang._('导出规则') }} <span class="caret"></span>
						</button>
						<ul class="dropdown-menu">
							<li><a href="/api/appidentification/rule/export/csv">{{ lang._('导出为 CSV') }}</a></li>
							<li><a href="/api/appidentification/rule/export/json">{{ lang._('导出为 JSON') }}</a></li>
						</ul>
					</div>
				</div>
				<div class="col-md-6 text-right">
					<span id="rules-count" class="text-muted">{{ lang._('加载中...') }}</span>
				</div>
			</div>
			<table id="grid-custom-rules" class="table table-condensed table-hover table-striped table-responsive" data-editDialog="DialogRule">
				<thead>
				<tr>
					<th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">{{ lang._('启用') }}</th>
					<th data-column-id="description" data-type="string">{{ lang._('描述') }}</th>
					<th data-column-id="match_type" data-type="string">{{ lang._('匹配类型') }}</th>
					<th data-column-id="match_value" data-type="string">{{ lang._('匹配值') }}</th>
					<th data-column-id="app_label" data-type="string">{{ lang._('应用标签') }}</th>
					<th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
					<th data-column-id="commands" data-width="7em" data-formatter="commands" data-sortable="false">{{ lang._('操作') }}</th>
				</tr>
				</thead>
				<tbody></tbody>
				<tfoot>
				<tr>
					<td></td>
					<td>
						<button data-action="add" type="button" class="btn btn-xs btn-default">
							<span class="fa fa-plus"></span>
						</button>
					</td>
				</tr>
				</tfoot>
			</table>
		</div>
	</div>
</div>

{{ partial("layout_partials/base_dialog",['fields':formDialogRule,'id':'DialogRule','label':lang._('Edit Custom Rule')]) }}

<script>
$(document).ready(function() {
	function esc(value) {
		return $('<div/>').text(value === null || value === undefined ? '' : String(value)).html();
	}

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

	function toggleAuthFields() {
		$('#general\\.auth_username').closest('.form-group').show();
		$('#general\\.auth_password').closest('.form-group').show();
		$('#general\\.auth_token').closest('.form-group').show();
		$('#general\\.auth_cookie').closest('.form-group').hide();
	}

	const dataGetMap = {'frm_general_settings': '/api/appidentification/general/get'};
	mapDataToFormUI(dataGetMap).done(function() {
		formatTokenizersUI();
		$('.selectpicker').selectpicker('refresh');
		toggleAuthFields();
	});

	$('#general\\.auth_mode').on('change', function () {
		toggleAuthFields();
	});

	$('#saveAct').click(function() {
		$('#saveAct_progress').addClass('fa fa-spinner fa-pulse');
		saveFormToEndpoint('/api/appidentification/general/set', 'frm_general_settings', function() {
			$('#saveAct_progress').removeClass('fa fa-spinner fa-pulse');
		}, true, function() {
			$('#saveAct_progress').removeClass('fa fa-spinner fa-pulse');
			showApiError('{{ lang._('保存配置失败') }}', '{{ lang._('Unable to save ntopng configuration') }}');
		});
	});

	$('#restartAct').click(function() {
		$('#restartAct_progress').addClass('fa fa-spinner fa-pulse');
		ajaxCall('/api/appidentification/general/ntopngrestart', {}, function() {
			$('#restartAct_progress').removeClass('fa fa-spinner fa-pulse');
		}, function(data) {
			$('#restartAct_progress').removeClass('fa fa-spinner fa-pulse');
			if (!data || data.status === 'error') {
				showApiError('{{ lang._('重启 ntopng 失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to restart ntopng') }}', function () {
					$('#restartAct').click();
				});
			}
		});
	});

	$('#testAct').click(function() {
		$('#testAct_progress').addClass('fa fa-spinner fa-pulse');
		$.ajax({
			url: '/api/appidentification/general/status',
			method: 'GET',
			dataType: 'json',
			success: function(data) {
				$('#testAct_progress').removeClass('fa fa-spinner fa-pulse');
				if (!data || data.status === 'error') {
					showApiError('{{ lang._('连接测试失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to connect to ntopng') }}');
					return;
				}
				BootstrapDialog.show({
					type: BootstrapDialog.TYPE_PRIMARY,
					title: '{{ lang._('Success') }}',
					message: $('<div/>').text(data.message || '{{ lang._('连接成功') }}').html(),
					buttons: [{label: '{{ lang._('Close') }}', action: function(d){ d.close(); }}]
				});
			},
			error: function(xhr) {
				$('#testAct_progress').removeClass('fa fa-spinner fa-pulse');
				const msg = xhr.responseJSON ? xhr.responseJSON.message : '{{ lang._('网络请求失败') }}';
				showApiError('{{ lang._('连接测试失败') }}', msg);
			}
		});
	});

	function activateHashTab() {
		const hash = window.location.hash || '#general';
		const tab = $('#maintabs a[href="' + hash + '"]');
		if (tab.length > 0) {
			tab.tab('show');
		}
	}

	$('#maintabs a[data-toggle="tab"]').on('shown.bs.tab', function (event) {
		window.location.hash = $(event.target).attr('href');
	});
	activateHashTab();

	function refreshRuleStats() {
		ajaxCall('/api/appidentification/rule/stats', {}, function (data) {
			if (!data || data.status === 'error') {
				$('#rules-count').text('{{ lang._('规则数量加载失败') }}');
				return;
			}
			let text = '{{ lang._('共') }} ' + esc(data.total || 0) + ' {{ lang._('条规则，启用') }} ' + esc(data.enabled || 0) + ' {{ lang._('条') }}';
			if (Number(data.total || 0) > 1000) {
				text += ' ({{ lang._('数量较多，页面可能变慢') }})';
			}
			$('#rules-count').html(text);
		});
	}

	function reloadRules() {
		$('#grid-custom-rules').bootgrid('reload');
		refreshRuleStats();
	}

	const savedRuleRowCount = Number(window.localStorage.getItem('appidentification.rules.rowCount') || 25);
	const ruleRowCounts = [savedRuleRowCount, 10, 25, 50, 100].filter(function (value, index, list) {
		return value > 0 && list.indexOf(value) === index;
	});

	$('#grid-custom-rules').UIBootgrid({
		search: '/api/appidentification/rule/searchRules',
		get: '/api/appidentification/rule/getRule/',
		set: '/api/appidentification/rule/setRule/',
		add: '/api/appidentification/rule/addRule/',
		del: '/api/appidentification/rule/delRule/',
		toggle: '/api/appidentification/rule/toggleRule/',
		options: {
			selection: false,
			multiSelect: false,
			rowCount: ruleRowCounts
		}
	}).on('loaded.rs.jquery.bootgrid', function () {
		const count = $('#grid-custom-rules').bootgrid('getRowCount');
		if (count) {
			window.localStorage.setItem('appidentification.rules.rowCount', count);
		}
		refreshRuleStats();
	});

	$('#grid-rules-add').on('click', function () {
		$('#grid-custom-rules button[data-action="add"]').first().click();
	});

	function parseImportPreview(format, text) {
		const errors = [];
		let rows = [];
		if ($.trim(text) === '') {
			return {rows: [], errors: ['{{ lang._('请输入或上传规则数据') }}']};
		}
		if (format === 'json') {
			try {
				const parsed = JSON.parse(text.replace(/^\uFEFF/, ''));
				if (!Array.isArray(parsed)) {
					return {rows: [], errors: ['{{ lang._('JSON 顶层必须是数组') }}']};
				}
				rows = parsed;
			} catch (err) {
				return {rows: [], errors: [err.message]};
			}
		} else {
			const lines = text.replace(/^\uFEFF/, '').split(/\r?\n/).filter(function (line) { return $.trim(line) !== ''; });
			if (lines.length < 2) {
				return {rows: [], errors: ['{{ lang._('CSV 至少需要表头和一行数据') }}']};
			}
			function splitCsv(line) {
				const out = [];
				let cur = '';
				let quoted = false;
				for (let i = 0; i < line.length; i++) {
					const ch = line.charAt(i);
					if (ch === '"' && quoted && line.charAt(i + 1) === '"') {
						cur += '"';
						i++;
					} else if (ch === '"') {
						quoted = !quoted;
					} else if (ch === ',' && !quoted) {
						out.push(cur);
						cur = '';
					} else {
						cur += ch;
					}
				}
				out.push(cur);
				return out;
			}
			const header = splitCsv(lines[0]).map(function (field) { return $.trim(field); });
			lines.slice(1).forEach(function (line, idx) {
				const values = splitCsv(line);
				if (values.length !== header.length) {
					errors.push('{{ lang._('第') }} ' + (idx + 2) + ' {{ lang._('行列数不匹配') }}');
					return;
				}
				const row = {};
				header.forEach(function (field, pos) {
					row[field] = values[pos];
				});
				rows.push(row);
			});
		}
		rows.forEach(function (row, idx) {
			['match_type', 'match_value', 'app_label'].forEach(function (field) {
				if (!row || !row[field]) {
					errors.push('{{ lang._('第') }} ' + (idx + 1) + ' {{ lang._('条缺少') }} ' + field);
				}
			});
		});
		return {rows: rows, errors: errors};
	}

	function renderImportPreview(container) {
		const format = container.find('input[name="import_format"]:checked').val();
		const text = container.find('#rules-import-payload').val();
		const result = parseImportPreview(format, text);
		const submit = container.closest('.modal-content').find('.btn-primary');
		if (result.errors.length > 0) {
			container.find('#rules-import-preview').html('<div class="alert alert-danger">' + result.errors.slice(0, 8).map(esc).join('<br>') + '</div>');
			submit.prop('disabled', true);
			return;
		}
		let html = '<div class="alert alert-success">{{ lang._('解析成功，共') }} ' + esc(result.rows.length) + ' {{ lang._('条') }}</div>';
		html += '<table class="table table-condensed"><thead><tr><th>match_type</th><th>match_value</th><th>app_label</th></tr></thead><tbody>';
		result.rows.slice(0, 5).forEach(function (row) {
			html += '<tr><td>' + esc(row.match_type) + '</td><td>' + esc(row.match_value) + '</td><td>' + esc(row.app_label) + '</td></tr>';
		});
		html += '</tbody></table>';
		container.find('#rules-import-preview').html(html);
		submit.prop('disabled', result.rows.length === 0);
	}

	function submitImport(dialog, container) {
		const formData = new FormData();
		formData.append('format', container.find('input[name="import_format"]:checked').val());
		formData.append('mode', container.find('input[name="import_mode"]:checked').val());
		formData.append('payload', container.find('#rules-import-payload').val());
		const file = container.find('#rules-import-file')[0].files[0];
		if (file) {
			formData.append('file', file);
		}
		container.find('#rules-import-errors').removeClass('alert alert-danger').empty();
		container.find('#rules-import-progress').show();
		$.ajax({
			url: '/api/appidentification/rule/import',
			method: 'POST',
			data: formData,
			processData: false,
			contentType: false,
			global: false,
			dataType: 'json',
			success: function (data) {
				container.find('#rules-import-progress').hide();
				if (!data || data.status !== 'ok') {
					const errors = data && data.errors ? data.errors : [data && data.message ? data.message : '{{ lang._('导入失败') }}'];
					container.find('#rules-import-errors').addClass('alert alert-danger').html(errors.map(esc).join('<br>'));
					return;
				}
				dialog.close();
				reloadRules();
				BootstrapDialog.show({
					type: BootstrapDialog.TYPE_SUCCESS,
					title: '{{ lang._('Success') }}',
					message: esc('{{ lang._('成功导入') }} ' + data.imported + ' {{ lang._('条规则，跳过') }} ' + data.skipped + ' {{ lang._('条重复规则') }}'),
					buttons: [{label: '{{ lang._('Close') }}', action: function(d){ d.close(); }}]
				});
			},
			error: function (xhr) {
				container.find('#rules-import-progress').hide();
				const data = xhr.responseJSON || {};
				const errors = data.errors || [data.message || '{{ lang._('网络请求失败') }}'];
				container.find('#rules-import-errors').addClass('alert alert-danger').html(errors.map(esc).join('<br>'));
			}
		});
	}

	$('#rules-import-open').on('click', function () {
		const body = $('<div>' +
			'<div class="form-group"><label>{{ lang._('格式') }}</label><br>' +
			'<label class="radio-inline"><input type="radio" name="import_format" value="csv" checked> CSV</label>' +
			'<label class="radio-inline"><input type="radio" name="import_format" value="json"> JSON</label></div>' +
			'<div class="form-group"><label>{{ lang._('模式') }}</label><br>' +
			'<label class="radio-inline"><input type="radio" name="import_mode" value="append" checked> {{ lang._('追加') }}</label>' +
			'<label class="radio-inline"><input type="radio" name="import_mode" value="replace"> {{ lang._('替换全部') }}</label></div>' +
			'<div class="form-group"><label>{{ lang._('上传文件') }}</label><input id="rules-import-file" type="file" accept=".csv,.json,text/csv,application/json" class="form-control"></div>' +
			'<div class="form-group"><label>{{ lang._('粘贴文本') }}</label><textarea id="rules-import-payload" class="form-control" rows="5"></textarea></div>' +
			'<div id="rules-import-preview"></div><div id="rules-import-progress" class="progress" style="display:none;"><div class="progress-bar progress-bar-striped active" style="width:100%"></div></div><div id="rules-import-errors"></div>' +
			'</div>');
		const dialog = BootstrapDialog.show({
			title: '{{ lang._('批量导入应用规则') }}',
			message: body,
			buttons: [
				{label: '{{ lang._('Cancel') }}', action: function(d){ d.close(); }},
				{label: '{{ lang._('Import') }}', cssClass: 'btn-primary', action: function(d){
					if (body.find('input[name="import_mode"]:checked').val() === 'replace') {
						ajaxCall('/api/appidentification/rule/stats', {}, function (stats) {
							const total = stats && stats.total ? stats.total : 0;
							BootstrapDialog.confirm('{{ lang._('此操作将清空所有现有规则（共') }} ' + total + ' {{ lang._('条），是否继续？') }}', function (ok) {
								if (ok) {
									submitImport(d, body);
								}
							});
						});
					} else {
						submitImport(d, body);
					}
				}}
			],
			onshown: function () {
				const submit = body.closest('.modal-content').find('.btn-primary');
				submit.prop('disabled', true);
				body.on('change keyup', 'input[name="import_format"], #rules-import-payload', function () {
					renderImportPreview(body);
				});
				body.find('#rules-import-file').on('change', function () {
					const file = this.files[0];
					if (!file) {
						renderImportPreview(body);
						return;
					}
					const reader = new FileReader();
					reader.onload = function (event) {
						body.find('#rules-import-payload').val(event.target.result);
						renderImportPreview(body);
					};
					reader.readAsText(file, 'UTF-8');
				});
			}
		});
	});

	$(document).ajaxError(function(event, xhr, settings) {
		if (settings && settings.url && settings.url.indexOf('/api/appidentification/') === 0) {
			const msg = xhr.responseJSON ? xhr.responseJSON.message : '{{ lang._('网络请求失败') }}';
			showApiError('{{ lang._('加载失败') }}', msg);
		}
	});
});
</script>
