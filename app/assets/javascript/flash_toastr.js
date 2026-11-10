$(document).ajaxError(function(event, xhr) {
  if (xhr.status === 403) {
    var response = {};

    try {
      response = JSON.parse(xhr.responseText);
    } catch (e) {}

    if (response.error) {
      toastr.danger({description: response.error});
    }
  }
});