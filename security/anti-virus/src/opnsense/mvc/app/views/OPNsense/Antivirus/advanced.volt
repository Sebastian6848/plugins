<script>
    "use strict";

    $(document).ready(function() {
        mapDataToFormUI({'frm_advanced_settings': "/api/antivirus/settings/get"}).done(function() {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
        });

        $("#saveAct").click(function() {
            saveFormToEndpoint("/api/antivirus/settings/set", "frm_advanced_settings", function() {
                $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
                ajaxCall(url="/api/antivirus/service/reload", sendData={}, callback=function() {
                    $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
                });
            });
        });
    });
</script>

<div class="content-box">
    <h2>{{ lang._('antivirus.advanced.title') }}</h2>
    {{ partial("layout_partials/base_form", ['fields': advancedForm, 'id': 'frm_advanced_settings']) }}
    <div class="col-md-12">
        <hr />
        <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
    </div>
</div>

<div class="content-box">
    <div class="alert alert-info" role="alert">
        {{ lang._('antivirus.advanced.ssl_bump_hint') }}
    </div>
    <div class="alert alert-warning" role="alert">
        {{ lang._('antivirus.advanced.hw_req_hint') }}
    </div>
</div>
