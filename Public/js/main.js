$('#auth_policy_form').submit(function() {
   $('#action_key').val(
        $('#action_key_value').val() + $('#resource_key_value').val()
    );
});


var roleObject = $('#role_object')
roleObject.blur(function() {
    $('#role_id').val(
        roleObject.children("option").filter(":selected").val()
    );
    $('#role_name').val(
        roleObject.children("option").filter(":selected").text()
    );
});




