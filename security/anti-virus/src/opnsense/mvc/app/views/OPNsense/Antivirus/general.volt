<script>
    "use strict";

    function antivirusStatusClass(value) {
        if (value === "running" || value === "active") {
            return "text-success fa-check-circle";
        }
        if (value === "stopped" || value === "inactive") {
            return "text-danger fa-times-circle";
        }
        return "text-muted fa-question-circle";
    }

    function updateAntivirusStatus() {
        ajaxCall(url="/api/antivirus/service/status", sendData={}, callback=function(data, status) {
            ["clamd", "cicap", "squid_icap"].forEach(function(item) {
                $("#status_" + item)
                    .removeClass("text-success text-danger text-muted fa-check-circle fa-times-circle fa-question-circle")
                    .addClass(antivirusStatusClass(data[item]));
                $("#status_" + item + "_value").text(data[item] || "-");
            });
            $("#sig_version").text(data["sig_version"] || "-");
            $("#sig_updated").text(data["sig_updated"] || "-");
        });
    }

    $(document).ready(function() {
        mapDataToFormUI({'frm_general_settings': "/api/antivirus/settings/get"}).done(function() {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
        });

        $("#saveAct").click(function() {
            saveFormToEndpoint("/api/antivirus/settings/set", "frm_general_settings", function() {
                $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
                ajaxCall(url="/api/antivirus/service/reload", sendData={}, callback=function() {
                    $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
                    updateAntivirusStatus();
                });
            });
        });

        $("#startAct, #stopAct, #restartAct, #updateSigsAct").SimpleActionButton({
            onAction: function() {
                updateAntivirusStatus();
            }
        });

        updateAntivirusStatus();
    });
</script>

<div class="content-box">
    <div class="row">
        <div class="col-md-4">
            <h3>{{ lang._('antivirus.general.status_clamd') }}</h3>
            <p><span id="status_clamd" class="fa text-muted fa-question-circle"></span> <span id="status_clamd_value">-</span></p>
        </div>
        <div class="col-md-4">
            <h3>{{ lang._('antivirus.general.status_cicap') }}</h3>
            <p><span id="status_cicap" class="fa text-muted fa-question-circle"></span> <span id="status_cicap_value">-</span></p>
        </div>
        <div class="col-md-4">
            <h3>{{ lang._('antivirus.general.status_chain') }}</h3>
            <p><span id="status_squid_icap" class="fa text-muted fa-question-circle"></span> <span id="status_squid_icap_value">-</span></p>
        </div>
    </div>
    <hr />
    <div class="row">
        <div class="col-md-4">
            <strong>{{ lang._('antivirus.general.sig_version') }}</strong>
            <p id="sig_version">-</p>
        </div>
        <div class="col-md-4">
            <strong>{{ lang._('antivirus.general.sig_updated') }}</strong>
            <p id="sig_updated">-</p>
        </div>
        <div class="col-md-4">
            <button class="btn btn-primary" id="updateSigsAct" data-endpoint="/api/antivirus/service/update_sigs" data-label="{{ lang._('antivirus.general.update_now') }}"></button>
        </div>
    </div>
</div>

<div class="content-box">
    {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general_settings']) }}
    <div class="col-md-12">
        <hr />
        <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
        <button class="btn btn-default" id="startAct" data-endpoint="/api/antivirus/service/start" data-label="{{ lang._('antivirus.general.start') }}"></button>
        <button class="btn btn-default" id="stopAct" data-endpoint="/api/antivirus/service/stop" data-label="{{ lang._('antivirus.general.stop') }}"></button>
        <button class="btn btn-default" id="restartAct" data-endpoint="/api/antivirus/service/restart" data-label="{{ lang._('antivirus.general.restart') }}"></button>
    </div>
</div>
