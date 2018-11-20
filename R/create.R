


#' Create a Radix website
#'
#' Create a basic skeleton for a Radix website or blog. Use the `create_website()`
#' function for a website and the `create_blog()` function for a blog.
#'
#' @param dir Directory for website
#' @param title Title of website
#' @param gh_pages Configure the site for publishing using [GitHub
#'   Pages](https://pages.github.com/)
#' @param edit Open site index file or welcome post in an editor.
#'
#' @note The `dir` and `title` parameters are required (they will be prompted for
#'   interatively if they are not specified).
#'
#' @examples
#' \dontrun{
#' library(radix)
#' create_website("mysite", "My Site")
#' }
#' @export
create_website <- function(dir, title, gh_pages = FALSE, edit = interactive()) {
  do_create_website(dir, title, gh_pages, edit, "website")
  render_website(dir, "website")
  invisible(NULL)
}


#' @rdname create_website
#' @export
create_blog <- function(dir, title, gh_pages = FALSE, edit = interactive()) {

  # create the website
  params <- do_create_website(dir, title, gh_pages, edit = FALSE, "blog")

  # create the welcome post
  welcome <- "welcome.Rmd"
  target_path <- file.path(params$dir, "_posts", "welcome")
  render_template(
    file = welcome,
    type = "blog",
    target_path = target_path,
    data = list(
      title = params$title,
      date = format(Sys.Date(), "%m-%d-%Y")
    )
  )

  # render the welcome post
  rmarkdown::render(file.path(target_path, welcome))

  # render the site
  render_website(dir, "blog")

  # edit the welcome post if requested
  if (edit)
    edit_file(file.path(target_path, welcome))

  invisible(NULL)
}


#' Create a new blog post
#'
#' @param title Post title
#' @param author Post author. Automatically drawn from previous post if not provided.
#' @param slug Post slug (directory name). Automatically computed from title if not
#'   provided.
#' @param date_prefix Data prefix for post slug (preserves chronological order for posts
#'   within the filesystem).
#' @param draft Mark the post as a `draft` (don't include it in the article listing).
#' @param edit Open the post in an editor after creating it.
#'
#' @note This function must be called from with a working directory that is within
#'  a Radix website.
#'
#' @examples
#' \dontrun{
#' library(radix)
#' create_post("My Post")
#' }
#'
#' @export
create_post <- function(title, author = "auto", slug = "auto", date_prefix = TRUE,
                        draft = FALSE, edit = interactive()) {

  # determine site_dir (must call from within a site)
  site_dir <- find_site_dir(".")
  if (is.null(site_dir))
    stop("You must call create_post from within a Radix website")

  # more discovery
  site_config <- site_config(site_dir)
  posts_dir <- file.path(site_dir, "_posts")
  posts_index <- file.path(site_dir, site_config$output_dir, "posts", "posts.json")

  # auto-slug
  slug <- resolve_slug(title, slug)
  post_dir <- file.path(posts_dir, slug)

  # add date prefix
  post_date <- Sys.Date()
  if (!identical(date_prefix, FALSE)) {
    if (isTRUE(date_prefix))
      date_prefix <- Sys.Date()
    else if (is.character(date_prefix))
      date_prefix <- parse_date(date_prefix)
    if (is_date(date_prefix)) {
      post_date <- date_prefix
      date_prefix <- as.character(date_prefix, format = "%Y-%m-%d")
    } else {
      stop("You must specify either TRUE/FALSE or a date for date_prefix")
    }
    post_dir <- file.path(posts_dir, paste(date_prefix, slug, sep = "-"))
  }

  # determine author
  if (identical(author, "auto")) {

    # default to NULL
    author <- NULL

    # look author of most recent post
    if (file.exists(posts_index))
      posts <- read_json(posts_index)
    else
      posts <- list()
    if (length(posts) > 0)
      author <- list(author = posts[[1]]$author)
  }
  # if we still don't have an author then auto-detect
  if (is.null(author))
    author <- list(author = list(list(name = fullname(fallback = "Unknown"))))
  # author to yaml
  author <- yaml::as.yaml(author, indent.mapping.sequence = TRUE)

  # add draft
  if (draft)
    draft <- '\ndraft: true'
  else
    draft <- ''

  # create yaml
  yaml <- sprintf(
'---
title: "%s"
description: |
  A short description of the post.
%sdate: %s
output:
  radix::radix_article:
    self_contained: false%s
---', title, author, format.Date(post_date, "%m-%d-%Y"), draft)


  # body
  body <-
'

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = FALSE)
```

Radix is a publication format for scientific and technical writing, native to the web.

Learn more about using Radix at <https://rstudio.github.io/radix>.

'

  # create the post directory
  if (dir_exists(post_dir))
    stop("Post directory '", post_dir, "' already exists.", call. = FALSE)
  dir.create(post_dir, recursive = TRUE)

  # create the post file
  post_file <- file.path(post_dir, file_with_ext(slug, "Rmd"))
  con <- file(post_file, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeChar(yaml, con, eos = NULL, useBytes = TRUE)
  writeChar(body, con, eos = NULL, useBytes = TRUE)

  # edit if requested
  if (edit)
    edit_file(post_file)

  # return path to post (invisibly)
  invisible(post_file)
}



new_project_create_website <- function(dir, ...) {
  params <- list(...)
  create_website(dir, params$title, params$gh_pages, edit = FALSE)
}

new_project_create_blog <- function(dir, ...) {
  params <- list(...)
  create_blog(dir, params$title, params$gh_pages, edit = FALSE)
}

do_create_website <- function(dir, title, gh_pages, edit, type) {

  # prompt for arguments if we need to
  if (missing(dir)) {
    if (interactive())
      dir <- readline(sprintf("Enter directory name for %s: ", type))
    else
      stop("dir argument must be specified", call. = FALSE)
  }
  if (missing(title)) {
    if (interactive())
      title <- readline(sprintf("Enter a title for the %s: ", type))
    else
      stop("title argument must be specified", call. = FALSE)
  }

  # ensure dir exists
  message("Creating website directory ", dir)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  # copy template files
  render_website_template <- function(file, data = list()) {
    render_template(file, type, dir, data)
  }
  render_website_template("_site.yml", data = list(
    name = basename(dir),
    title = title,
    output_dir = if (gh_pages) "docs" else "_site"
  ))
  render_website_template("index.Rmd", data = list(title = title, gh_pages = gh_pages))
  render_website_template("about.Rmd")

  # if this is for gh-pages then create .nojekyll
  if (gh_pages) {
    nojekyll <- file.path(dir, ".nojekyll")
    message("Creating ", nojekyll, " for gh-pages")
    file.create(nojekyll)
  }

  # if we are running in RStudio then create Rproj
  if (have_rstudio_project_api())
    rstudioapi::initializeProject(dir)

  if (edit)
    edit_file(file.path(dir, "index.Rmd"))

  invisible(list(
    dir = dir,
    title = title
  ))
}


render_website <- function(dir, type) {
  message(sprintf("Rendering %s...", type))
  rmarkdown::render_site(dir)
}

render_template <- function(file, type, target_path, data = list()) {
  message("Creating ", file.path(target_path, file))
  template <- system.file(file.path("rstudio", "templates", "project", type, file),
                          package = "radix")
  template <- paste(readLines(template, encoding = "UTF-8"), collapse = "\n")
  output <- whisker::whisker.render(template, data)
  if (!dir_exists(target_path))
    dir.create(target_path, recursive = TRUE, showWarnings = FALSE)
  writeLines(output, file.path(target_path, file), useBytes = TRUE)
}

edit_file <- function(file) {
  if (rstudioapi::hasFun("navigateToFile"))
    rstudioapi::navigateToFile(file)
  else
    utils::file.edit(file)
}

resolve_slug <- function(title, slug) {

  if (identical(slug, "auto"))
    slug <- title

  slug <- tolower(slug)                        # convert to lowercase
  slug <- gsub("\\s+", "-", slug)              # replace spaces with -
  slug <- gsub("[^a-zA-Z0-9\\-]+", "", slug)   # remove all non-word chars
  slug <- gsub("\\-{2,}", "-", slug)           # replace multiple - with single -
  slug <- gsub("^-+", "", slug)                # trim - from start of text
  slug <- gsub("-+$", "", slug)                # trim - from end of text

  slug

}




