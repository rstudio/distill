

window.document.addEventListener("DOMContentLoaded", function (event) {

  $('.citation>a').each(function(i, val) {
    var href = $(this).attr('href');
    var key = href.replace('#ref-', '');
    var cite = $('<dt-cite></dt-cite>');
    cite.attr('key', key);
    $(this).parent().replaceWith(cite);
  })

});
