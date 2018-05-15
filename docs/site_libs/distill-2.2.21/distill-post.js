
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
  var doi = $('d-byline').find('h3:contains("DOI")');
  var doi_p = doi.next().empty();
  if (!front_matter.doi) {
    // if we have a citation and valid citationText then link to that
    if ($('#citation').length > 0 && front_matter.citationText) {
      doi.html('Citation');
      $('<a href="#citation"></a>')
        .text(front_matter.citationText)
        .appendTo(doi_p);
    } else {
      hide_byline_column("DOI");
    }
  } else {
    $('<a></a>')
       .attr('href', "https://doi.org/" + front_matter.doi)
       .html(front_matter.doi)
       .appendTo(doi_p);
  }

  // move appendix-bottom entries to the bottom
  $('.appendix-bottom').appendTo('d-appendix').children().unwrap();
  $('.appendix-bottom').remove();

  $('body').css('opacity', 1);
});

