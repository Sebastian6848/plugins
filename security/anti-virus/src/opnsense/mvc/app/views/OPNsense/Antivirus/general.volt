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

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <div id="general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
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
                    </tbody>
                </table>
            </div>
            {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
                <button class="btn btn-primary" id="applyAct" type="button"><b>{{ lang._('Apply') }}</b> <i id="applyAct_progress"></i></button>
            </div>
        </div>
    </div>
</div>

<script>
function updateAntivirusStatus(data) {
    var clamd = data['clamd'] == 'running' ? 'running' : 'stopped';
    var cicap = data['cicap'] == 'running' ? 'running' : 'stopped';
    $("#clamd_status").text(clamd).removeClass("label-success label-danger").addClass(clamd == 'running' ? "label-success" : "label-danger");
    $("#cicap_status").text(cicap).removeClass("label-success label-danger").addClass(cicap == 'running' ? "label-success" : "label-danger");
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

    refreshAntivirusStatus();

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
});
</script>
