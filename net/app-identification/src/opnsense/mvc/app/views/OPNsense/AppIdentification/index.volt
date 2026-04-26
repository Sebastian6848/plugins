{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
	<li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
	<div id="general" class="tab-pane fade in active">
		<div class="content-box" style="padding-bottom: 1.5em;">
			{{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
			<div class="col-md-12">
				<hr />
				<button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
				<button class="btn btn-default" id="restartAct" type="button"><span class="fa fa-refresh"></span> {{ lang._('Restart ntopng') }} <i id="restartAct_progress"></i></button>
			</div>
		</div>
	</div>
</div>

<script>
$(document).ready(function() {
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
			message: $('<div/>').text(message || '{{ lang._('Unknown error') }}').html(),
			buttons: buttons
		});
	}

	function toggleAuthFields() {
		const mode = ($('#general\.auth_mode').val() || 'none').toLowerCase();
		const rowUser = $('#general\.auth_username').closest('.form-group');
		const rowPass = $('#general\.auth_password').closest('.form-group');
		const rowToken = $('#general\.auth_token').closest('.form-group');
		const rowCookie = $('#general\.auth_cookie').closest('.form-group');

		rowUser.toggle(mode === 'basic');
		rowPass.toggle(mode === 'basic');
		rowToken.toggle(mode === 'token');
		rowCookie.toggle(mode === 'cookie');
	}

	const dataGetMap = {'frm_general_settings': '/api/appidentification/general/get'};
	mapDataToFormUI(dataGetMap).done(function() {
		formatTokenizersUI();
		$('.selectpicker').selectpicker('refresh');
		toggleAuthFields();
	});

	$('#general\.auth_mode').on('change', function () {
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
});
</script>
