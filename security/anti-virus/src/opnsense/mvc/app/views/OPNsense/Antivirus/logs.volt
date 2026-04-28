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
    <li class="active"><a data-toggle="tab" href="#blocked">{{ lang._('Blocked Threats') }}</a></li>
    <li><a data-toggle="tab" href="#raw">{{ lang._('Raw Log') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <div id="blocked" class="tab-pane fade in active">
        <table id="grid-blocked" class="table table-responsive">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
                    <th data-column-id="time" data-type="string" data-width="180">{{ lang._('Time') }}</th>
                    <th data-column-id="client" data-type="string" data-width="140">{{ lang._('Client IP') }}</th>
                    <th data-column-id="user" data-type="string" data-width="100">{{ lang._('User') }}</th>
                    <th data-column-id="threat" data-type="string">{{ lang._('Threat') }}</th>
                    <th data-column-id="url" data-type="string">{{ lang._('URL') }}</th>
                    <th data-column-id="action" data-type="string" data-width="100">{{ lang._('Action') }}</th>
                    <th data-column-id="source" data-type="string" data-width="100">{{ lang._('Source') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
    <div id="raw" class="tab-pane fade in">
        <table id="grid-raw" class="table table-responsive">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
                    <th data-column-id="time" data-type="string" data-width="180">{{ lang._('Time') }}</th>
                    <th data-column-id="program" data-type="string" data-width="160">{{ lang._('Program') }}</th>
                    <th data-column-id="message" data-type="string">{{ lang._('Message') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
</div>

<div class="col-md-12">
    <hr />
    <button class="btn btn-primary" id="refreshAct" type="button"><b>{{ lang._('Refresh') }}</b></button>
    <br /><br />
</div>

<script>
$( document ).ready(function() {
    $("#grid-blocked").UIBootgrid({
        search: "/api/antivirus/logs/blocked",
        options: {
            rowCount: [10, 25, 50, 100]
        }
    });

    $("#grid-raw").UIBootgrid({
        search: "/api/antivirus/logs/raw",
        options: {
            rowCount: [10, 25, 50, 100]
        }
    });

    $("#refreshAct").click(function(){
        $("#grid-blocked").bootgrid("reload");
        $("#grid-raw").bootgrid("reload");
    });
});
</script>
