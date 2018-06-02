

#' Render a listing of Radix articles
#'
#' @param collection Collection name
#'
#' @export
article_listing <- function(collection) {

  # collection dir
  collection_dir <- paste0("_", collection)
  if (!dir_exists(collection_dir))
    stop("The collection '", collection, "' does not exist")

  # article listing
  articles_yaml <- file.path(collection_dir, file_with_ext(collection, "yml"))
  if (!file.exists(articles_yaml))
    stop("The collection '", collection, "' does not have an article listing.\n",
         "(try running render_site() to generate the listing)")
  articles <- yaml::yaml.load_file(articles_yaml)

  # generate html
  articles_html <- lapply(articles, function(article) {

    path <- file.path(collection, article$path)

    metadata <- div(class = "metadata",
      div(class = "publishedDate",
          sprintf("%s %d, %s",
          article$published_month,
          article$published_day,
          article$published_year))
    )

    thumbnail <- div(class = "thumbnail",
      img(src = file.path(path, article$preview))
    )

    description <- div(class = "description",
      h2(article$title),
      p(article$description)
    )

    a(href = paste0(path, "/"), class = "post-preview",
      metadata,
      thumbnail,
      description
    )
  })

  # wrap in a div
  div(class = "posts-list l-page", articles_html)
}

