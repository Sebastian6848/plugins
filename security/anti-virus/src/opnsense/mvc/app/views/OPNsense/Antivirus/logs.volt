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
        <div class="row" style="padding: 10px 10px 0 10px;">
            <div class="col-sm-3">
                <select class="selectpicker antivirus-log-filter" id="blocked-severity" data-width="100%">
                    <option value="all">{{ lang._('All severities') }}</option>
                    <option value="alert">{{ lang._('Alert') }}</option>
                    <option value="warning">{{ lang._('Warning') }}</option>
                    <option value="error">{{ lang._('Error') }}</option>
                    <option value="info">{{ lang._('Info') }}</option>
                </select>
            </div>
            <div class="col-sm-3">
                <select class="selectpicker antivirus-log-filter" id="blocked-since" data-width="100%">
                    <option value="all">{{ lang._('All time') }}</option>
                    <option value="1h">{{ lang._('Last hour') }}</option>
                    <option value="today">{{ lang._('Today') }}</option>
                    <option value="yesterday">{{ lang._('Yesterday') }}</option>
                    <option value="7d">{{ lang._('Last 7 days') }}</option>
                </select>
            </div>
            <div class="col-sm-6 text-right">
                <button class="btn btn-default antivirus-log-refresh" data-grid="grid-blocked" type="button"><span class="fa fa-refresh"></span></button>
                <button class="btn btn-default antivirus-log-reset" data-grid="grid-blocked" type="button"><span class="fa fa-undo"></span></button>
            </div>
        </div>
        <table id="grid-blocked" class="table table-responsive">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
                    <th data-column-id="time" data-type="string" data-width="180">{{ lang._('Time') }}</th>
                    <th data-column-id="severity" data-type="string" data-width="100" data-formatter="severity">{{ lang._('Severity') }}</th>
                    <th data-column-id="client" data-type="string" data-width="140">{{ lang._('Client IP') }}</th>
                    <th data-column-id="user" data-type="string" data-width="100">{{ lang._('User') }}</th>
                    <th data-column-id="threat" data-type="string">{{ lang._('Threat') }}</th>
                    <th data-column-id="url" data-type="string">{{ lang._('URL') }}</th>
                    <th data-column-id="action" data-type="string" data-width="100" data-formatter="action">{{ lang._('Action') }}</th>
                    <th data-column-id="source" data-type="string" data-width="100">{{ lang._('Source') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
    <div id="raw" class="tab-pane fade in">
        <div class="row" style="padding: 10px 10px 0 10px;">
            <div class="col-sm-2">
                <select class="selectpicker antivirus-log-filter" id="raw-severity" data-width="100%">
                    <option value="all">{{ lang._('All severities') }}</option>
                    <option value="alert">{{ lang._('Alert') }}</option>
                    <option value="warning">{{ lang._('Warning') }}</option>
                    <option value="error">{{ lang._('Error') }}</option>
                    <option value="info">{{ lang._('Info') }}</option>
                </select>
            </div>
            <div class="col-sm-2">
                <select class="selectpicker antivirus-log-filter" id="raw-since" data-width="100%">
                    <option value="all">{{ lang._('All time') }}</option>
                    <option value="1h">{{ lang._('Last hour') }}</option>
                    <option value="today">{{ lang._('Today') }}</option>
                    <option value="yesterday">{{ lang._('Yesterday') }}</option>
                    <option value="7d">{{ lang._('Last 7 days') }}</option>
                </select>
            </div>
            <div class="col-sm-2">
                <select class="selectpicker antivirus-log-filter" id="raw-program" data-width="100%">
                    <option value="all">{{ lang._('All programs') }}</option>
                    <option value="c-icap">c-icap</option>
                    <option value="clamd">clamd</option>
                    <option value="freshclam">freshclam</option>
                </select>
            </div>
            <div class="col-sm-6 text-right">
                <button class="btn btn-default antivirus-log-refresh" data-grid="grid-raw" type="button"><span class="fa fa-refresh"></span></button>
                <button class="btn btn-default antivirus-log-reset" data-grid="grid-raw" type="button"><span class="fa fa-undo"></span></button>
            </div>
        </div>
        <table id="grid-raw" class="table table-responsive">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
                    <th data-column-id="time" data-type="string" data-width="180">{{ lang._('Time') }}</th>
                    <th data-column-id="severity" data-type="string" data-width="100" data-formatter="severity">{{ lang._('Severity') }}</th>
                    <th data-column-id="program" data-type="string" data-width="160">{{ lang._('Program') }}</th>
                    <th data-column-id="message" data-type="string">{{ lang._('Message') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
</div>

<script>
$( document ).ready(function() {
    function htmlEscape(value) {
        return $("<div/>").text(value === undefined ? "" : value).html();
    }

    function readFilters(prefix) {
        return {
            severity: $("#" + prefix + "-severity").val() || "all",
            since: $("#" + prefix + "-since").val() || "all",
            program: $("#" + prefix + "-program").val() || "all"
        };
    }

    function filterRequest(prefix, request) {
        var filters = readFilters(prefix);
        request.severity = filters.severity;
        request.since = filters.since;
        request.program = filters.program;
        return request;
    }

    function gridForPane(pane) {
        return pane.attr("id") == "raw" ? $("#grid-raw") : $("#grid-blocked");
    }

    var formatters = {
        severity: function(column, row) {
            var severity = row.severity || "info";
            var classes = {
                alert: "label-danger",
                error: "label-danger",
                warning: "label-warning",
                info: "label-info"
            };
            return '<span class="label ' + (classes[severity] || "label-default") + '">' + htmlEscape(severity) + '</span>';
        },
        action: function(column, row) {
            return '<span class="label label-danger">' + htmlEscape(row.action || "") + '</span>';
        }
    };

    $("#grid-blocked").UIBootgrid({
        search: "/api/antivirus/logs/blocked",
        options: {
            rowCount: [10, 25, 50, 100],
            selection: false,
            rowSelect: false,
            responsive: true,
            searchSettings: {
                delay: 300,
                characters: 1
            },
            requestHandler: function(request) {
                return filterRequest("blocked", request);
            },
            formatters: formatters
        }
    });

    $("#grid-raw").UIBootgrid({
        search: "/api/antivirus/logs/raw",
        options: {
            rowCount: [10, 25, 50, 100],
            selection: false,
            rowSelect: false,
            responsive: true,
            searchSettings: {
                delay: 300,
                characters: 1
            },
            requestHandler: function(request) {
                return filterRequest("raw", request);
            },
            formatters: formatters
        }
    });

    $(".selectpicker").selectpicker("refresh");

    $(".antivirus-log-filter").on("changed.bs.select change", function(){
        gridForPane($(this).closest(".tab-pane")).bootgrid("reload");
    });

    $(".antivirus-log-refresh").click(function(){
        $("#" + $(this).data("grid")).bootgrid("reload");
    });

    $(".antivirus-log-reset").click(function(){
        var pane = $(this).closest(".tab-pane");
        pane.find(".antivirus-log-filter").val("all").selectpicker("refresh");
        gridForPane(pane).bootgrid("search", "");
        gridForPane(pane).bootgrid("reload");
    });
});
</script>
