

window.document.addEventListener("DOMContentLoaded", function (event) {

  // replace citations with <dt-cite>
  $('.citation>a').each(function(i, val) {
    var href = $(this).attr('href');
    var key = href.replace('#ref-', '');
    var cite = $('<dt-cite></dt-cite>');
    cite.attr('key', key);
    $(this).parent().replaceWith(cite);
  });

  // replace footnotes with <dt-fn>
  $('.footnote-ref').each(function(i, val) {
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

  // move appendixes to dt-appendix section
  $(".appendix").appendTo("dt-appendix");

});
