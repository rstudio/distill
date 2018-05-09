
window.document.addEventListener("DOMContentLoaded", function (event) {

  // hide author/affiliations entirely if we have no authors
  var front_matter = JSON.parse($("#distill-front-matter").html());
  var have_authors = front_matter.authors && front_matter.authors.length > 0;
  if (!have_authors)
    $('d-byline').addClass('hidden');

  // hide elements of author/affiliations grid that have no value
  function hide_byline_column(caption) {
    $('d-byline').find('h3:contains("' + caption + '")').parent().css('visibility', 'hidden');
  }

  // published date
  if (!front_matter.publishedDate)
    hide_byline_column("Published");

  // document object identifier
  if (!front_matter.doi) {
    // if we have a citation and valid citationText then link to that
    if ($('#citation').length > 0 && front_matter.citationText) {
      var doi = $('d-byline').find('h3:contains("DOI")');
      doi.html('Citation');
      var p = doi.next().empty();
      var a = $('<a class="byline-citation-link" href="#citation"></a>');
      a.text(front_matter.citationText);
      p.append(a);
    } else {
      hide_byline_column("DOI");
    }
  }

  // move appendix-bottom entries to the bottom
  $('.appendix-bottom').appendTo('d-appendix').children().unwrap();
  $('.appendix-bottom').remove();

  console.log('moved bottom appendix entries');

  $('body').css('display', 'initial');
});

