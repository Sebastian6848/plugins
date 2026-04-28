{#

OPNsense® is Copyright © 2014 – 2017 by Deciso B.V.
This file is Copyright © 2026
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

2.  Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

#}

<div class="alert alert-warning" role="alert" id="dl_sig_alert" style="display:none;min-height:65px;">
    <button class="btn btn-primary pull-right" id="dl_sig" type="button">{{ lang._('Download signatures') }} <i id="dl_sig_progress"></i></button>
    <div style="margin-top: 8px;">{{ lang._('No signature database found, please download before use. The download will take several minutes and this message will disappear when it has been completed.') }}</div>
</div>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
    <li><a data-toggle="tab" href="#versions">{{ lang._('Versions') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <div id="general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            <h3>{{ lang._('Status') }}</h3>
            <div class="table-responsive">
                <table class="table table-striped">
                    <tbody>
                        <tr>
                            <td>{{ lang._('ClamAV Engine') }}</td>
                            <td><span id="clamd_status" class="label label-danger">{{ lang._('stopped') }}</span></td>
                        </tr>
                        <tr>
                            <td>{{ lang._('ICAP Service') }}</td>
                            <td><span id="cicap_status" class="label label-danger">{{ lang._('stopped') }}</span></td>
                        </tr>
                        <tr>
                            <td>{{ lang._('Freshclam Service') }}</td>
                            <td><span id="freshclam_status" class="label label-danger">{{ lang._('stopped') }}</span></td>
                        </tr>
                        <tr>
                            <td>{{ lang._('Squid ICAP') }}</td>
                            <td><span id="squid_icap_status" class="label label-danger">{{ lang._('inactive') }}</span></td>
                        </tr>
                        <tr>
                            <td>{{ lang._('SSL Inspection') }}</td>
                            <td><span id="ssl_bump_status" class="label label-danger">{{ lang._('disabled') }}</span></td>
                        </tr>
                        <tr>
                            <td>{{ lang._('SSL Mode') }}</td>
                            <td><span id="ssl_mode">-</span></td>
                        </tr>
                        <tr>
                            <td>{{ lang._('SSL CA') }}</td>
                            <td><span id="ssl_ca_status" class="label label-danger">{{ lang._('missing') }}</span></td>
                        </tr>
                    </tbody>
                </table>
            </div>
            <div class="alert alert-info" role="alert" id="https_scan_hint" style="display:none;">
                {{ lang._('HTTPS scanning uses the existing Squid SSL inspection configuration. Enable SSL inspection in the web proxy and install its CA certificate on clients to scan HTTPS response content.') }}
            </div>
        </div>
        <div class="content-box" style="padding-bottom: 1.5em;">
            <h3>{{ lang._('Configuration') }}</h3>
            {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
                <button class="btn btn-primary" id="applyAct" type="button"><b>{{ lang._('Apply') }}</b> <i id="applyAct_progress"></i></button>
            </div>
        </div>
    </div>
    <div id="versions" class="tab-pane fade in">
        <div class="content-box">
            {{ partial("layout_partials/base_form",['fields':versionForm,'id':'frm_version'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="update_sig" type="button"><b>{{ lang._('Download signatures') }}</b> <i id="update_sig_progress"></i></button>
            </div>
        </div>
    </div>
</div>

<script>
function timeoutCheck() {
    ajaxCall(url="/api/antivirus/service/freshclam", sendData={}, callback=function(data,status) {
        if (data['status'] == 'done') {
            $("#dl_sig_progress").removeClass("fa fa-spinner fa-pulse");
            $("#update_sig_progress").removeClass("fa fa-spinner fa-pulse");
            $("#dl_sig").prop("disabled", false);
            $("#update_sig").prop("disabled", false);
            $('#dl_sig_alert').hide();
            var version_get_map = {'frm_version':"/api/antivirus/service/version"};
            mapDataToFormUI(version_get_map).done(function(data){
                formatTokenizersUI();
                $('.selectpicker').selectpicker('refresh');
            });
            refreshAntivirusStatus();
        } else {
            setTimeout(timeoutCheck, 2500);
        }
    });
}

function updateAntivirusStatus(data) {
    var clamd = data['clamd'] == 'running' ? 'running' : 'stopped';
    var cicap = data['cicap'] == 'running' ? 'running' : 'stopped';
    var freshclam = data['freshclam'] == 'running' ? 'running' : 'stopped';
    var squid_icap = data['squid_icap'] == 'active' ? 'active' : 'inactive';
    var ssl_bump = data['ssl_bump'] == 'enabled' ? 'enabled' : 'disabled';
    var ssl_ca = data['ssl_ca'] == 'present' ? 'present' : 'missing';
    $("#clamd_status").text(clamd).removeClass("label-success label-danger").addClass(clamd == 'running' ? "label-success" : "label-danger");
    $("#cicap_status").text(cicap).removeClass("label-success label-danger").addClass(cicap == 'running' ? "label-success" : "label-danger");
    $("#freshclam_status").text(freshclam).removeClass("label-success label-danger").addClass(freshclam == 'running' ? "label-success" : "label-danger");
    $("#squid_icap_status").text(squid_icap).removeClass("label-success label-danger").addClass(squid_icap == 'active' ? "label-success" : "label-danger");
    $("#ssl_bump_status").text(ssl_bump).removeClass("label-success label-danger").addClass(ssl_bump == 'enabled' ? "label-success" : "label-danger");
    $("#ssl_mode").text(data['ssl_mode'] == 'sni_only' ? 'SNI only' : 'inspection');
    $("#ssl_ca_status").text(ssl_ca).removeClass("label-success label-danger").addClass(ssl_ca == 'present' ? "label-success" : "label-danger");
    if (ssl_bump != 'enabled' || data['ssl_mode'] == 'sni_only' || ssl_ca != 'present') {
        $("#https_scan_hint").show();
    } else {
        $("#https_scan_hint").hide();
    }
}

function refreshAntivirusStatus() {
    ajaxCall(url="/api/antivirus/service/status", sendData={}, callback=function(data,status) {
        updateAntivirusStatus(data);
    });
}

$( document ).ready(function() {
    var data_get_map = {'frm_general_settings':"/api/antivirus/settings/get"};
    mapDataToFormUI(data_get_map).done(function(data){
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
    });

    var version_get_map = {'frm_version':"/api/antivirus/service/version"};
    mapDataToFormUI(version_get_map).done(function(data){
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
    });

    refreshAntivirusStatus();

    ajaxCall(url="/api/antivirus/service/freshclam", sendData={}, callback=function(data,status) {
        if (data['status'] != 'done') {
            if (data['status'] == 'running') {
                $("#dl_sig_progress").addClass("fa fa-spinner fa-pulse");
                $("#dl_sig").prop("disabled", true);
                setTimeout(timeoutCheck, 2500);
            }
            $('#dl_sig_alert').show();
        }
    });

    $("#saveAct").click(function(){
        saveFormToEndpoint(url="/api/antivirus/settings/set", formid='frm_general_settings', callback_ok=function(){
            $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
            $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
        });
    });

    $("#applyAct").click(function(){
        saveFormToEndpoint(url="/api/antivirus/settings/set", formid='frm_general_settings', callback_ok=function(){
            $("#applyAct_progress").addClass("fa fa-spinner fa-pulse");
            var endpoint = $("#general\\.enabled").is(":checked") ? "/api/antivirus/service/start" : "/api/antivirus/service/stop";
            ajaxCall(url=endpoint, sendData={}, callback=function(data,status) {
                refreshAntivirusStatus();
                $("#applyAct_progress").removeClass("fa fa-spinner fa-pulse");
            });
        });
    });

    $("#dl_sig, #update_sig").click(function(){
        $("#dl_sig_progress").addClass("fa fa-spinner fa-pulse");
        $("#update_sig_progress").addClass("fa fa-spinner fa-pulse");
        $("#dl_sig").prop("disabled", true);
        $("#update_sig").prop("disabled", true);
        ajaxCall(url="/api/antivirus/service/freshclam", sendData={action:1}, callback_ok=function(){
            setTimeout(timeoutCheck, 2500);
        });
    });

    if(window.location.hash != "") {
        $('a[href="' + window.location.hash + '"]').click()
    }
    $('.nav-tabs a').on('shown.bs.tab', function (e) {
        history.pushState(null, null, e.target.hash);
    });
});
</script>
