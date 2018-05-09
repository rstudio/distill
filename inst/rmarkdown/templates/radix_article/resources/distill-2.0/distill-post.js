
window.document.addEventListener("DOMContentLoaded", function (event) {

  // hide author/affiliations entirely if we have no authors
  var front_matter = JSON.parse($("#distill-front-matter").html());
  if (!front_matter.authors || front_matter.authors.length === 0)
    $('d-byline').addClass('hidden');

  // hide elements of author/affiliations grid that have no value
  function hide_byline_column(value, caption) {
    if (!value)
      $('d-byline').find('h3:contains("' + caption + '")').parent().css('visibility', 'hidden');
  }
  hide_byline_column(front_matter.publishedDate, "Published");
  hide_byline_column(front_matter.doi, "DOI");

  // move appendix-bottom entries to the bottom
  $('.appendix-bottom').appendTo('d-appendix').children().unwrap();
  $('.appendix-bottom').remove();

  console.log('moved bottom appendix entries');

  $('body').css('display', 'initial');
});

