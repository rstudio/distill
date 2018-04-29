

window.document.addEventListener("DOMContentLoaded", function (event) {

  // flag indicating that we have appendix items
  var appendix = false;

  // replace citations with <dt-cite>
  $('.citation').each(function(i, val) {
    appendix = true;
    // pull out all unique citation references
    var anchors = $(this).children('a');
    var cites = [];
    anchors.each(function(i, val) {
      var href = $(val).attr('href');
      var cite = href.replace('#ref-', '');
      if ($.inArray(cite, cites) === -1)
        cites.push(cite);
    });
    // create dt-site
    var dt_cite = $('<dt-cite></dt-cite>');
    dt_cite.attr('key', cites.join());
    $(this).replaceWith(dt_cite);
  });

  // replace footnotes with <dt-fn>
  $('.footnote-ref').each(function(i, val) {
    appendix = true;
    var href = $(this).attr('href');
    var id = href.replace('#', '');
    var fn = $('#' + id);
    var fn_p = $('#fn1>p');
    fn_p.find('.footnote-back').remove();
    var text = fn_p.text();
    var dtfn = $('<dt-fn></dt-fn>');
    dtfn.text(text);
    $(this).replaceWith(dtfn);
  });

  // move appendixes to dt-appendix section
  $(".appendix").each(function(i, val) {
    appendix = true;
    $(this).appendTo("dt-appendix");
  });

  // show dt-appendix if we have appendix content
  $("dt-appendix").css('display', appendix ? 'inherit' : 'none');

  // replace code blocks with dt-code
  $('pre>code').each(function(i, val) {
    var code = $(this);
    var pre = code.parent();
    var language = pre.attr('class') || "none";
    if ($.inArray(language, ["r", "cpp", "c", "java"]) != -1)
      language = "clike";
    language = ' language="' + language + '"';
    var dt_code = $('<dt-code block' + language + '></dt-code>');
    dt_code.text(code.text());
    pre.replaceWith(dt_code);
  });

  // apply fig.layout to figures
  $('.fig-layout-chunk').each(function(i, val) {

    var fig_layout = $(this).attr('data-fig-layout');

    var img = $(this).children('img');
    if (img.length > 0)
      img.addClass(fig_layout).unwrap();

  });


});
