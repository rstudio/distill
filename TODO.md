
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

- can we force self_contained: false (error condition?)

- custom site engine (rendering posts and clean_site)

- preview images may not work
- preview images with absolute files may not work

- custom site engine that handles _articles / collections

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
   

- reference citation metadata should throttle on actual inclusion

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
    
    - Embed page content with <noscript></noscript> ?
    - Noframes: https://www.w3.org/TR/REC-html40/present/frames.html#h-16.4.1
    
    
    
