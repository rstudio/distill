
## distill v0.7 (Development)

* Update to latest version of Distll template from https://github.com/distillpub/template


## radix v0.6 (CRAN)

* Custom listing pages (e.g. gallery of featured posts)
* Support for bookdown-style figure cross-references (e.g. `\@ref{fig:plot1}`)
* Allow use of markdown within footnotes
* Support for text headers within website navigation menus
* Fix issue with RStudio version check (check was failing with 4-digit patch version)
* Recover gracefully from invalid posts.json file (e.g. due to git merge)
* Syntax highlighting for unknown languages (now they are mapped to "clike", previously they were removed entirely)
* Correctly render favicon for articles in collections
* Provide option to show Disqus comments by default
* Fix issue with relative references to bibliographies from posts
* Fix intermediates_dir error that occurred when rendering from source on RStudio Connect
* Enable `import_post()` to work with file paths as well as URLs
* Set standard plot width to 6.5 inches (was 6.0, new width closer to golden ratio)
* Don't force plots in standard l-body layout to a width of 100%
* Forward `check_license` from `import_post()` to `import_article()`
* Normalize authors specified as plain strings to list form
* Use standard figure caption CSS treatment for table captions
* Provide default title ("Untitled") for articles that lack one
* Scroll horizontal overflow from code blocks on mobile devices 
* Fix problem with mailto links within blog posts
* Render welcome post in New Radix Blog RStudio template

## radix v0.5

* Initial CRAN release
