

(function($) {
  $.fn.changeElementType = function(newType) {
    var attrs = {};

    $.each(this[0].attributes, function(idx, attr) {
      attrs[attr.nodeName] = attr.nodeValue;
    });

    this.replaceWith(function() {
      return $("<" + newType + "/>", attrs).append($(this).contents());
    });
  };
})(jQuery);

window.document.addEventListener("DOMContentLoaded", function (event) {

  // flag indicating that we have appendix items
  var appendix = $('.appendix-bottom').children('h3').length > 0;

  // replace citations with <d-cite>
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
    var dt_cite = $('<d-cite></d-cite>');
    dt_cite.attr('key', cites.join());
    $(this).replaceWith(dt_cite);
  });
  // remove refs
  $('#refs').remove();

  // replace footnotes with <d-footnote>
  $('.footnote-ref').each(function(i, val) {
    appendix = true;
    var href = $(this).attr('href');
    var id = href.replace('#', '');
    var fn = $('#' + id);
    var fn_p = $('#fn1>p');
    fn_p.find('.footnote-back').remove();
    var text = fn_p.text();
    var dtfn = $('<d-footnote></d-footnote>');
    dtfn.text(text);
    $(this).replaceWith(dtfn);
  });
  // remove footnotes
  $('.footnotes').remove();

  $('h1.appendix, h2.appendix').each(function(i, val) {
    $(this).changeElementType('h3');
  });
  $('h3.appendix').each(function(i, val) {
    appendix = true;
    $(this).nextUntil($('h1, h2, h3')).addBack().appendTo($('d-appendix'));
  });

  // show d-appendix if we have appendix content
  $("d-appendix").css('display', appendix ? 'grid' : 'none');

  // replace code blocks with d-code
  $('pre>code').each(function(i, val) {
    var code = $(this);
    var pre = code.parent();
    var clz = "";
    var language = pre.attr('class');
    if (language) {
      if ($.inArray(language, ["r", "cpp", "c", "java"]) != -1)
        language = "clike";
      language = ' language="' + language + '"';
      var dt_code = $('<d-code block' + language + clz + '></d-code>');
      dt_code.text(code.text());
      if (pre.parent().is('.layout-chunk')) {
        dt_code.insertBefore(pre.parent());
        pre.remove();
      } else {
        pre.replaceWith(dt_code);
      }
    } else {
      code.addClass('text-output').unwrap().changeElementType('pre');
    }
  });

  // prevent underline for linked images
  $('a > img').parent().css({'border-bottom' : 'none'});

  // mark child figures created by R chunks 100% width
  $('.layout-chunk').each(function(i, val) {
    $(this).children('img, .html-widget').css('width', '100%');
  });

  // add class to pandoc style tables
  $('tr.header').parent('thead').parent('table').addClass('pandoc-table');
  $('.kable-table').children('table').addClass('pandoc-table');
});
