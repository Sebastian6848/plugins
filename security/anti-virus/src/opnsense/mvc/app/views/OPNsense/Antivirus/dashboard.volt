<script src="{{ cache_safe('/ui/js/chart.umd.min.js') }}"></script>

<script>
    "use strict";

    function renderList(target, rows, nameKey) {
        const list = $(target);
        list.empty();
        rows.forEach(function(row) {
            $("<li/>")
                .addClass("list-group-item")
                .append($("<span/>").text(row[nameKey] || "-"))
                .append($("<span/>").addClass("badge").text(row.count || 0))
                .appendTo(list);
        });
    }

    $(document).ready(function() {
        ajaxCall(url="/api/antivirus/log/stats", sendData={}, callback=function(data, status) {
            $("#last24h").text(data.last24h || 0);
            renderList("#top_ips", data.top_ips || [], "ip");
            renderList("#top_sigs", data.top_sigs || [], "sig");

            const ctx = $("#trend7d")[0].getContext("2d");
            const trend = data.trend7d || [];
            new Chart(ctx, {
                type: "line",
                data: {
                    labels: trend.map(function(item) { return item.date; }),
                    datasets: [{
                        label: "{{ lang._('antivirus.dashboard.trend7d') }}",
                        data: trend.map(function(item) { return item.count; }),
                        borderColor: "#1b6d85",
                        backgroundColor: "rgba(27, 109, 133, 0.15)",
                        tension: 0.25,
                        fill: true
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false }
                    },
                    scales: {
                        y: { beginAtZero: true, ticks: { precision: 0 } }
                    }
                }
            });
        });
    });
</script>

<div class="content-box">
    <h2>{{ lang._('antivirus.dashboard.title') }}</h2>
    <div class="row">
        <div class="col-md-3">
            <h3>{{ lang._('antivirus.dashboard.last24h') }}</h3>
            <p class="lead" id="last24h">0</p>
        </div>
        <div class="col-md-9">
            <h3>{{ lang._('antivirus.dashboard.trend7d') }}</h3>
            <div style="height: 260px;">
                <canvas id="trend7d"></canvas>
            </div>
        </div>
    </div>
    <hr />
    <div class="row">
        <div class="col-md-6">
            <h3>{{ lang._('antivirus.dashboard.top_ips') }}</h3>
            <ul id="top_ips" class="list-group"></ul>
        </div>
        <div class="col-md-6">
            <h3>{{ lang._('antivirus.dashboard.top_sigs') }}</h3>
            <ul id="top_sigs" class="list-group"></ul>
        </div>
    </div>
</div>
