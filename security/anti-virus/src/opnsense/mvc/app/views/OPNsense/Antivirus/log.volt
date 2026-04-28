<script>
    "use strict";

    function antivirusLogFilters() {
        return {
            filter_ip: $("#filter_ip").val(),
            filter_sig: $("#filter_sig").val(),
            date_from: $("#date_from").val(),
            date_to: $("#date_to").val()
        };
    }

    $(document).ready(function() {
        $("#grid-detections").UIBootgrid({
            search: "/api/antivirus/log/search",
            options: {
                rowCount: 50,
                selection: false,
                multiSelect: false,
                requestHandler: function(request) {
                    const filters = antivirusLogFilters();
                    request.filter_ip = filters.filter_ip;
                    request.filter_sig = filters.filter_sig;
                    request.date_from = filters.date_from;
                    request.date_to = filters.date_to;
                    request.limit = request.rowCount;
                    request.offset = (request.current - 1) * request.rowCount;
                    return request;
                },
                formatters: {
                    url: function(column, row) {
                        return $("<div/>").text(row.url || "").html();
                    },
                    signature: function(column, row) {
                        return $("<div/>").text(row.signature || "").html();
                    }
                }
            }
        });

        $("#filterAct").click(function() {
            $("#grid-detections").bootgrid("reload");
        });

        $("#exportAct").click(function() {
            const query = $.param(antivirusLogFilters());
            window.location = "/api/antivirus/log/export?" + query;
        });
    });
</script>

<div class="content-box">
    <h2>{{ lang._('antivirus.log.title') }}</h2>
    <div class="row">
        <div class="col-md-3">
            <label for="date_from">{{ lang._('antivirus.log.date_from') }}</label>
            <input type="date" id="date_from" class="form-control" />
        </div>
        <div class="col-md-3">
            <label for="date_to">{{ lang._('antivirus.log.date_to') }}</label>
            <input type="date" id="date_to" class="form-control" />
        </div>
        <div class="col-md-3">
            <label for="filter_ip">{{ lang._('antivirus.log.filter_ip') }}</label>
            <input type="text" id="filter_ip" class="form-control" />
        </div>
        <div class="col-md-3">
            <label for="filter_sig">{{ lang._('antivirus.log.filter_sig') }}</label>
            <input type="text" id="filter_sig" class="form-control" />
        </div>
    </div>
    <br />
    <button class="btn btn-primary" id="filterAct" type="button">{{ lang._('Filter') }}</button>
    <button class="btn btn-default" id="exportAct" type="button">{{ lang._('antivirus.log.export') }}</button>
</div>

<div class="content-box">
    <table id="grid-detections" class="table table-condensed table-hover table-striped">
        <thead>
            <tr>
                <th data-column-id="ts" data-order="desc">{{ lang._('antivirus.log.col_ts') }}</th>
                <th data-column-id="src_ip">{{ lang._('antivirus.log.col_src_ip') }}</th>
                <th data-column-id="url" data-formatter="url">{{ lang._('antivirus.log.col_url') }}</th>
                <th data-column-id="signature" data-formatter="signature">{{ lang._('antivirus.log.col_sig') }}</th>
                <th data-column-id="action">{{ lang._('antivirus.log.col_action') }}</th>
            </tr>
        </thead>
        <tbody>
        </tbody>
        <tfoot>
        </tfoot>
    </table>
</div>
