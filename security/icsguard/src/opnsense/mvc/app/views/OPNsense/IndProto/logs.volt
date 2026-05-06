<script>
$(document).ready(function() {
    function htmlEscape(value) {
        return $("<div/>").text(value === undefined ? "" : value).html();
    }

    var formatters = {
        action: function(column, row) {
            var action = row.action || "";
            var classes = {
                drop: "label-danger",
                blocked: "label-danger",
                pass: "label-success",
                allowed: "label-success",
                reject: "label-danger",
                alert: "label-warning"
            };
            return '<span class="label ' + (classes[action] || "label-default") + '">' + htmlEscape(action) + '</span>';
        }
    };

    $("#grid-indproto-logs").UIBootgrid({
        search: "/api/indproto/log/search_log",
        options: {
            rowCount: [10, 25, 50, 100],
            selection: false,
            rowSelect: false,
            responsive: true,
            requestHandler: function(request) {
                request.proto = $("#filter-proto").val() || "all";
                request.src_ip = $("#filter-src").val() || "";
                request.dst_ip = $("#filter-dst").val() || "";
                request.start_time = $("#filter-start").val() || "";
                request.end_time = $("#filter-end").val() || "";
                request.limit = $("#filter-limit").val() || "200";
                return request;
            },
            formatters: formatters
        }
    });

    $(".selectpicker").selectpicker("refresh");
    $("#refresh-logs").click(function() {
        $("#grid-indproto-logs").bootgrid("reload");
    });
    $("#reset-logs").click(function() {
        $("#filter-proto").val("all").selectpicker("refresh");
        $("#filter-src").val("");
        $("#filter-dst").val("");
        $("#filter-start").val("");
        $("#filter-end").val("");
        $("#filter-limit").val("200");
        $("#grid-indproto-logs").bootgrid("search", "");
        $("#grid-indproto-logs").bootgrid("reload");
    });
});
</script>

<div class="content-box">
    <div class="row" style="padding: 10px 10px 0 10px;">
        <div class="col-sm-2">
            <select class="selectpicker" id="filter-proto" data-width="100%">
                <option value="all">{{ lang._('All protocols') }}</option>
                <option value="modbus">Modbus</option>
                <option value="nclink">NCLink</option>
                <option value="dnp3">DNP3</option>
                <option value="s7comm">S7comm</option>
            </select>
        </div>
        <div class="col-sm-2">
            <input id="filter-src" type="text" class="form-control" placeholder="{{ lang._('Source IP') }}">
        </div>
        <div class="col-sm-2">
            <input id="filter-dst" type="text" class="form-control" placeholder="{{ lang._('Destination IP') }}">
        </div>
        <div class="col-sm-2">
            <input id="filter-start" type="text" class="form-control" placeholder="{{ lang._('Start time') }}">
        </div>
        <div class="col-sm-2">
            <input id="filter-end" type="text" class="form-control" placeholder="{{ lang._('End time') }}">
        </div>
        <div class="col-sm-1">
            <input id="filter-limit" type="text" class="form-control" value="200" placeholder="{{ lang._('Limit') }}">
        </div>
        <div class="col-sm-1 text-right">
            <button class="btn btn-default" id="refresh-logs" type="button"><span class="fa fa-refresh"></span></button>
            <button class="btn btn-default" id="reset-logs" type="button"><span class="fa fa-undo"></span></button>
        </div>
    </div>
    <div class="alert alert-info" style="margin: 10px;">
        {{ lang._('S7comm matching is based on byte signatures and is marked BETA in generated rules.') }}
    </div>
    <table id="grid-indproto-logs" class="table table-condensed table-hover table-striped table-responsive">
        <thead>
            <tr>
                <th data-column-id="timestamp" data-width="180" data-type="string">{{ lang._('Time') }}</th>
                <th data-column-id="src_ip" data-width="140" data-type="string">{{ lang._('Source IP') }}</th>
                <th data-column-id="dest_ip" data-width="140" data-type="string">{{ lang._('Destination IP') }}</th>
                <th data-column-id="dest_port" data-width="90" data-type="string">{{ lang._('Port') }}</th>
                <th data-column-id="proto" data-width="100" data-type="string">{{ lang._('Protocol') }}</th>
                <th data-column-id="signature" data-type="string">{{ lang._('Rule') }}</th>
                <th data-column-id="action" data-width="100" data-type="string" data-formatter="action">{{ lang._('Action') }}</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>
</div>
