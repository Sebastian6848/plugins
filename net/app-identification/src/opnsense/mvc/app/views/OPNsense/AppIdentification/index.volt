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
	const dataGetMap = {'frm_general_settings': '/api/appidentification/general/get'};
	mapDataToFormUI(dataGetMap).done(function() {
		formatTokenizersUI();
		$('.selectpicker').selectpicker('refresh');
	});

	$('#saveAct').click(function() {
		saveFormToEndpoint('/api/appidentification/general/set', 'frm_general_settings', function() {
			$('#saveAct_progress').addClass('fa fa-spinner fa-pulse');
			ajaxCall('/api/appidentification/general/reconfigure', {}, function() {
				$('#saveAct_progress').removeClass('fa fa-spinner fa-pulse');
			});
		});
	});

	$('#restartAct').click(function() {
		$('#restartAct_progress').addClass('fa fa-spinner fa-pulse');
		ajaxCall('/api/appidentification/general/ntopngrestart', {}, function() {
			$('#restartAct_progress').removeClass('fa fa-spinner fa-pulse');
		});
	});
});
</script>
