

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

  $('h1.appendix').each(function(i, val) {
    appendix = true;
    $(this).nextUntil($('h1')).addBack().appendTo($('dt-appendix'));
  });

   $('h2.appendix').each(function(i, val) {
    appendix = true;
    $(this).nextUntil($('h1, h2')).addBack().appendTo($('dt-appendix'));
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
    if (pre.parent().is('.distill-layout-chunk')) {
      dt_code.insertBefore(pre.parent());
      pre.remove();
    } else {
      pre.replaceWith(dt_code);
    }
  });

  // mark child figures created by R chunks 100% width
  $('.distill-layout-chunk').each(function(i, val) {
    $(this).children('img, .html-widget').css('width', '100%');
  });

  // add class to pandoc style tables
  $('tr.header').parent('thead').parent('table').addClass('pandoc-table');
  $('.kable-table').children('table').addClass('pandoc-table');
});
