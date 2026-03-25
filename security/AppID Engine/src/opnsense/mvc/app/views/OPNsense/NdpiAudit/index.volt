<script>
    $(document).ready(function () {
        mapDataToFormUI({'frm_GeneralSettings': '/api/ndpiaudit/general/get'}).done(function () {
            $('.selectpicker').selectpicker('refresh');
            updateServiceControlUI('ndpiaudit');
        });

        $('#reconfigureAct').SimpleActionButton({
            onPreAction: function () {
                const deferred = $.Deferred();
                saveFormToEndpoint('/api/ndpiaudit/general/set', 'frm_GeneralSettings', deferred.resolve, true, deferred.reject);
                return deferred;
            }
        });
    });
</script>

<div class="content-box">
    <div class="alert alert-info" style="margin-top: 10px;">
        {{ lang._('Traffic is mirrored by pf dup-to to a loopback interface. Engine failures do not interrupt forwarding path.') }}
    </div>
    {{ partial('layout_partials/base_form', ['fields': generalForm, 'id': 'frm_GeneralSettings']) }}
</div>

{{ partial('layout_partials/base_apply_button', {'data_endpoint': '/api/ndpiaudit/service/reconfigure', 'data_service_widget': 'ndpiaudit'}) }}
