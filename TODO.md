
- larger scale visualization layouts
    - iframe with npr library (pym.js) for sizing (generic) (check with shinyapps.io)
    - distillVisualization() top level shinyApp equivalent with distill bootstrap theme 
       - use the less compiler for this
    "full bleed"
    - ggplot2 theme for distill
    - crosstalk compatibility?
        - distillRow/distillCol
    - publishing/previewing workflow?
    - app.R or ui.R / server.R in the same directory; automagic local run

    - Full bleed media objects (videos, docs (http://viewerjs.org/), etc.)

Embedded articles:

- Site publishing on RStudio Connect

- Shared content/code and shared dependency copying for posts

- Use top level posts .html with subdirs (no src)

- custom site engine (rendering posts and clean_site)

- consider use mustache for producing iframe page (faster?)

- preview images may not work
- preview images with absolute files may not work

- custom site engine that handles _articles
- forward metadata from embedded article to enclosing frame
  (propagate citation_url/canonical_url)
- automatically hide chrome for embedded=1
- hosts metadata parameter to control embedding

- for each dir in _articles
   - find html output for article (no re-render). Or, perhaps just re-render
     when .html is older than .Rmd? (allows site build to work for incremental)
   - use resource_files metadata in Rmd for include/exclude?
   - find_external_resources (see shiny_prerendered for last-modified check)
   - create articles/dir/article
       - copy .html file
       - copy _files directory
       - copy copyable_site_resources
   - create articles/dir/index.html which embeds article/foo.html
   - can have _articles/dir/article.yml for external articles
   - import_article() function for automatically creating article.yml
   



- articles/index pages
    - https://github.com/wikiti/jquery-paginate
    - iframe based inclusion
    - http://davidjbradshaw.github.io/iframe-resizer/
    - pym.js


- Download supplemetary figures
- Abbreviations and supplementary figures
- "articles" that are presentations or other content (e.g. PDF!?!?!?!?)
    - http://viewerjs.org/
- Article indexes include repository URLs, source code, etc.
- Copy BibTeX on citation hover

- Citables figures/images

- eLife
- 

- JOSS (Journal of Open Source Scientific Software)
- JSS (Journal of Statistical Software)


- GH PullReview inline in IDE

- Check out https://publons.com/home/, F1000

- Figshare


- radix.pub
    - Use GitHub organizations/repos for URL namespace
    - Commit hook based publishing
    - Provide frame with social, GA, discourse, etc.
    - RSC for internal version of same
    - Highlighting and commenting
    
    
    
