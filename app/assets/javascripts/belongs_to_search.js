$(function() {
  $(".field-unit--belongs-to-search select").each(function initializeSelectize(index, element) {
    var $element = $(element);
    $element.selectize({
      valueField: 'id',
      labelField: 'dashboard_display_name',
      searchField: 'dashboard_display_name',
      create: false,
      preload: 'focus',
      searchUrl: $element.data('url') + '?search=',

      load: function(query, callback) {
        $.ajax({
          url: this.settings.searchUrl + encodeURIComponent(query),
          type: 'GET',
          error: function() {
            callback();
          },
          success: function(res) {
            callback(res.resources);
          }
        });
      },
    });
  });
});
