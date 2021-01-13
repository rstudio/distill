## distill v1.2 (CRAN)

-   Support for optional user display of source code via the `code_folding` option.
-   Display citation popup when hovering over references.
-   Definitely fix issue w/ importing articles from git repos with `main` default branch. (\#215)
-   Fix an issue with highlighting on Windows when there is a space in the resource's path (\#236).
-   Add optional cookie consent overlay for opt-in to Google Analytics and Disqus.
-   Support for including pages that use alternate R Markdown formats within Distill websites.
-   Automatically register collections referenced in `listings` YAML metadata.
-   Enhance `create_article()` function to create articles from alternate formats.
-   Fix issue w/ broken images in search results for pages with no preview image.
-   Fix issue w/ attempting to add non-site Rmds (e.g. README.Rmd) to search index.
-   Fix issue w/ duplicate `includes` within website articles
-   Suppress citation for individual articles/posts via `citation: false` metadata.
-   Add `sourceCode` class to pre and code tags for downlit output.

## distill v1.1

-   Fixed issue with `overflow: hidden` for code blocks on mobile devices (is now `overflow: auto`).
-   Improve full text search behavior w/ `ignoreLocation: true` and `threshold: 0`.
-   Fix issue w/ importing articles from git repos with `main` default branch.
-   Make headroom scroll tolerance a bit more forgiving (5px vs. 1px).

## distill v1.0

-   Add site search feature using [Fuse.js](https://github.com/krisk/Fuse) (enabled by default for blog sites). Can be explicitly enabled or disabled for any site using the `search` field in the `navbar` key of `_site.yml`.

-   Provide navbar link to website source code when `source_url` is provided in the `navbar` key of `_site.yml`.

-   Use pandoc rather than distill for bibliography generation. Provides support for `csl`, `nocite`, and `link-citations`, as well as the use of multiple bibliographies (including non-BibTeX ones). Eliminates distill provided mouse-over citation display, but users seem to value the Pandoc features more than this one.

-   Use pandoc rather than distill for code output (syntax highlighting themes can be customized using the `highlight` option). New default highlighting theme optimized for accessibility.

-   Use the [downlit](https://downlit.r-lib.org/) package to syntax highlight R code chunks (controlled by the `highlight_downlit` option, which is enabled by default).

-   More straightforward theming using the `theme` option (available for both articles and sites) and the `create_theme()` function.

-   Provide heading anchor links in left margin on hover.

-   Display article table of contents in the left sidebar. This is done only when the browser \>= 1000 pixels wide, otherwise it's shown at the top.

-   Added `create_article()` function for straightforward creation of new articles.

-   Show author (below date) within article listings.

-   Various improvements to category display, including showing categories on article pages and within article listings, adding a special "articles" category at the top that shows all articles, and display of the active category when a category filter is applied to a listing.

-   Don't apply table td/th bottom border styles to gt tables.

-   Support for `orcid_id` author metadata (displays next to author name).

-   Added `rename_post_dir()` function for renaming post directories to reflect updated titles and publishing dates.

-   Ensure that date fields in RSS feeds and sitemaps use `en_US.UTF-8` locale.

## distill v0.8 (CRAN)

-   Generate RSS category feeds using rss/categories in site config
-   Support rendering full RSS content when rss/full_content is TRUE in site config
-   Ability to add custom HTML to top of sidebar.
-   Provide aria attributes on toolbar icons
-   Add "volume," "issue," "issn," and "publisher" fields for journal article BibTeX entries when those are provided in YAML.
-   Provide alt text for logo image in navigation bar.
-   Add support some missing Google Scholar meta tags such as `citation_conference_title`, `citation_isbn`, `citation_firstpage`, `citation_lastpage`, `citation_dissertation_institution`, `citation_technical_report_institution`, and `citation_technical_report_number` and their corresponding bibliography entries.

## distill v0.7 (CRAN)

-   Update to latest version of Distill template from <https://github.com/distillpub/template>

## radix v0.6 (CRAN)

-   Custom listing pages (e.g. gallery of featured posts)
-   Support for bookdown-style figure cross-references (e.g. `\@ref{fig:plot1}`)
-   Allow use of markdown within footnotes
-   Support for text headers within website navigation menus
-   Fix issue with RStudio version check (check was failing with 4-digit patch version)
-   Recover gracefully from invalid posts.json file (e.g. due to git merge)
-   Syntax highlighting for unknown languages (now they are mapped to "clike", previously they were removed entirely)
-   Correctly render favicon for articles in collections
-   Provide option to show Disqus comments by default
-   Fix issue with relative references to bibliographies from posts
-   Fix intermediates_dir error that occurred when rendering from source on RStudio Connect
-   Enable `import_post()` to work with file paths as well as URLs
-   Set standard plot width to 6.5 inches (was 6.0, new width closer to golden ratio)
-   Don't force plots in standard l-body layout to a width of 100%
-   Forward `check_license` from `import_post()` to `import_article()`
-   Normalize authors specified as plain strings to list form
-   Use standard figure caption CSS treatment for table captions
-   Provide default title ("Untitled") for articles that lack one
-   Scroll horizontal overflow from code blocks on mobile devices
-   Fix problem with mailto links within blog posts
-   Render welcome post in New Radix Blog RStudio template

## radix v0.5

-   Initial CRAN release
