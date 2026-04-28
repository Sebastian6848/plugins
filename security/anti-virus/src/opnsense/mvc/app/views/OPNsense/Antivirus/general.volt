<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
    <li><a data-toggle="tab" href="#dashboard">{{ lang._('Dashboard') }}</a></li>
    <li><a data-toggle="tab" href="#logs">{{ lang._('Logs') }}</a></li>
    <li><a data-toggle="tab" href="#advanced">{{ lang._('Advanced') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
                <button class="btn btn-primary" id="applyAct" type="button"><b>{{ lang._('Apply') }}</b> <i id="applyAct_progress"></i></button>
                <button class="btn" id="repairAct" type="button"><b>{{ lang._('Repair') }}</b> <i id="repairAct_progress"></i></button>
                <button class="btn" id="updateDbAct" type="button"><b>{{ lang._('Update Database') }}</b> <i id="updateDbAct_progress"></i></button>
                <button class="btn" id="eicarAct" type="button"><b>{{ lang._('Run EICAR Test') }}</b> <i id="eicarAct_progress"></i></button>
                <div id="lastActionResult" class="text-muted" style="margin-top: 1em;"></div>
            </div>
        </div>
        <div class="content-box">
            <table class="table table-striped">
                <tbody id="statusBody"></tbody>
            </table>
        </div>
    </div>
    <div id="dashboard" class="tab-pane fade in">
        <div class="content-box">
            <table class="table table-striped">
                <tbody id="dashboardBody"></tbody>
            </table>
        </div>
    </div>
    <div id="logs" class="tab-pane fade in">
        <div class="content-box">
            <button class="btn btn-primary" id="parseLogsAct" type="button"><b>{{ lang._('Parse Logs') }}</b> <i id="parseLogsAct_progress"></i></button>
            <hr />
            <table class="table table-striped table-condensed">
                <thead>
                    <tr>
                        <th>{{ lang._('Time') }}</th>
                        <th>{{ lang._('Client IP') }}</th>
                        <th>{{ lang._('URL') }}</th>
                        <th>{{ lang._('Signature') }}</th>
                        <th>{{ lang._('Action') }}</th>
                        <th>{{ lang._('Source') }}</th>
                    </tr>
                </thead>
                <tbody id="logsBody"></tbody>
            </table>
        </div>
    </div>
    <div id="advanced" class="tab-pane fade in">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form",['fields':advancedForm,'id':'frm_advanced_settings'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAdvancedAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAdvancedAct_progress"></i></button>
            </div>
        </div>
    </div>
</div>

<script>
function esc(value) {
    return $("<div/>").text(value === null || value === undefined ? "" : value).html();
}

function spinner(id, active) {
    if (active) {
        $("#" + id).addClass("fa fa-spinner fa-pulse");
    } else {
        $("#" + id).removeClass("fa fa-spinner fa-pulse");
    }
}

function runService(action, icon, done) {
    var endpoint = action;
    var actionLabel = action;
    if (action == "eicar_test") {
        endpoint = "eicarTest";
        actionLabel = "EICAR test";
    } else if (action == "update_db") {
        endpoint = "updateDb";
        actionLabel = "database update";
    } else if (action == "parse_logs") {
        endpoint = "parseLogs";
        actionLabel = "log parsing";
    }
    spinner(icon, true);
    $("#lastActionResult").text("Running " + actionLabel + "...");
    ajaxCall(url="/api/antivirus/service/" + endpoint, sendData={}, callback=function(data,status) {
        spinner(icon, false);
        $("#lastActionResult").text(actionLabel + ": " + JSON.stringify(data));
        updateStatus();
        updateDashboard();
        updateLogs();
        if (done) {
            done(data);
        }
    });
}

function updateStatus() {
    ajaxCall(url="/api/antivirus/service/status", sendData={}, callback=function(data,status) {
        var rows = "";
        rows += "<tr><th>{{ lang._('Overall') }}</th><td>" + esc(data.overall) + "</td></tr>";
        rows += "<tr><th>{{ lang._('Enabled') }}</th><td>" + esc(data.enabled) + "</td></tr>";
        rows += "<tr><th>{{ lang._('Squid') }}</th><td>" + esc(data.squid && data.squid.running ? "running" : "not running") + "</td></tr>";
        rows += "<tr><th>{{ lang._('C-ICAP') }}</th><td>" + esc(data.cicap && data.cicap.running ? "running" : "not running") + "</td></tr>";
        rows += "<tr><th>{{ lang._('ClamAV') }}</th><td>" + esc(data.clamav && data.clamav.clamd_running ? "running" : "not running") + "</td></tr>";
        rows += "<tr><th>{{ lang._('Virus Database') }}</th><td>" + esc(data.clamav ? data.clamav.db_version : "") + "</td></tr>";
        rows += "<tr><th>{{ lang._('Last Detection') }}</th><td>" + esc(data.detections ? data.detections.last_detection : "") + "</td></tr>";
        $("#statusBody").html(rows);
    });
}

function updateDashboard() {
    ajaxCall(url="/api/antivirus/service/dashboard", sendData={}, callback=function(data,status) {
        var rows = "";
        rows += "<tr><th>{{ lang._('Blocked in 24 hours') }}</th><td>" + esc(data.last_24h) + "</td></tr>";
        rows += "<tr><th>{{ lang._('Blocked in 7 days') }}</th><td>" + esc(data.last_7d) + "</td></tr>";
        rows += "<tr><th>{{ lang._('Top Client IP') }}</th><td>" + esc(data.top_client_ip) + "</td></tr>";
        rows += "<tr><th>{{ lang._('Top Signature') }}</th><td>" + esc(data.top_signature) + "</td></tr>";
        rows += "<tr><th>{{ lang._('Recent Event') }}</th><td>" + esc(data.last_detection) + "</td></tr>";
        $("#dashboardBody").html(rows);
    });
}

function updateLogs() {
    ajaxCall(url="/api/antivirus/service/logs", sendData={}, callback=function(data,status) {
        var rows = "";
        $.each(data.rows || [], function(index, row) {
            rows += "<tr>";
            rows += "<td>" + esc(row.ts) + "</td>";
            rows += "<td>" + esc(row.src_ip) + "</td>";
            rows += "<td>" + esc(row.url) + "</td>";
            rows += "<td>" + esc(row.signature) + "</td>";
            rows += "<td>" + esc(row.action) + "</td>";
            rows += "<td>" + esc(row.source_log) + "</td>";
            rows += "</tr>";
        });
        $("#logsBody").html(rows);
    });
}

$( document ).ready(function() {
    var data_get_map = {
        'frm_general_settings':"/api/antivirus/general/get",
        'frm_advanced_settings':"/api/antivirus/general/get"
    };
    mapDataToFormUI(data_get_map).done(function(data){
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
    });

    updateServiceControlUI('antivirus');
    updateStatus();
    updateDashboard();
    updateLogs();
    setInterval(updateStatus, 10000);

    $("#saveAct").click(function(){
        saveFormToEndpoint(url="/api/antivirus/general/set", formid='frm_general_settings', callback_ok=function(){
            runService("apply", "saveAct_progress");
        });
    });
    $("#saveAdvancedAct").click(function(){
        saveFormToEndpoint(url="/api/antivirus/general/set", formid='frm_advanced_settings', callback_ok=function(){
            runService("apply", "saveAdvancedAct_progress");
        });
    });
    $("#applyAct").click(function(){ runService("apply", "applyAct_progress"); });
    $("#repairAct").click(function(){ runService("repair", "repairAct_progress"); });
    $("#updateDbAct").click(function(){ runService("update_db", "updateDbAct_progress"); });
    $("#eicarAct").click(function(){ runService("eicar_test", "eicarAct_progress"); });
    $("#parseLogsAct").click(function(){ runService("parse_logs", "parseLogsAct_progress"); });
});
</script>
