<script>
    $(document).ready(function() {
        $("#{{formGridRule['table_id']}}").UIBootgrid(
            {   search:'/api/indproto/rules/search_rule/',
                get:'/api/indproto/rules/get_rule/',
                set:'/api/indproto/rules/set_rule/',
                add:'/api/indproto/rules/add_rule/',
                del:'/api/indproto/rules/del_rule/',
                toggle:'/api/indproto/rules/toggle_rule/'
            }
        );

        $("#applyAct").SimpleActionButton({
            onPreAction: function() {
                const dfObj = new $.Deferred();
                saveFormToEndpoint("/api/indproto/general/set", "frm_general_settings", function() {
                    dfObj.resolve();
                }, true, function() {
                    dfObj.reject();
                });
                return dfObj;
            },
            onAction: function(data) {
                if (data.status === "ok") {
                    $("#indprotoChangeMessage").hide();
                    $("#{{formGridRule['table_id']}}").bootgrid("reload");
                }
            }
        });

        mapDataToFormUI({'frm_general_settings':"/api/indproto/general/get"}).done(function() {
            $('.selectpicker').selectpicker('refresh');
        });
    });
</script>

<div class="content-box">
    <div class="table-responsive">
        {{ partial("layout_partials/base_form", ['fields':formGeneral, 'id':'frm_general_settings']) }}
    </div>
</div>

<div class="content-box">
    {{ partial('layout_partials/base_bootgrid_table', formGridRule) }}
</div>

<div class="content-box">
    <div id="indprotoChangeMessage" class="alert alert-info" style="display: none" role="alert">
        {{ lang._('After changing settings, please apply them to regenerate Suricata rules.') }}
    </div>
    <button class="btn btn-primary" id="applyAct"
            data-endpoint="/api/indproto/rules/apply"
            data-label="{{ lang._('Apply') }}"
            data-error-title="{{ lang._('Error applying industrial protocol rules') }}"
            type="button"></button>
</div>

{{ partial("layout_partials/base_dialog", ['fields':formDialogRule, 'id':formGridRule['edit_dialog_id'], 'label':lang._('Edit Rule')]) }}
