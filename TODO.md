


- Sorts posts by reverse-chron

- Consider requiring pandoc 2

- index/category/archive pages (categories should be inline)
- email subscription (http://www.wpbeginner.com/opinion/stop-using-feedburner-move-to-feedburner-alternatives/)
- google analytics 
- discourse commenting
- search
- RSS feed for collection
   (support images: https://stackoverflow.com/questions/483675/images-in-rss-feed)
- rstudio addins/templates/projects for article creation
   - Created with link in footer

- built-in social buttons

- Add some citations to sample posts



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

- Embedded article workflow:

   - document cannonical url
   - attribution metadata for inclusion when importing/syndicating (do during import)
   - import article function(s)


- Document prism changes somewhere:
    - Added comment pattern: {pattern:/(^|[^\\])#.*/,lookbehind:!0}
    - Allow . in function names: function:/[a-z\.0-9_]

- http://bwlewis.github.io/cassini/

- Download supplemetary figures
- Abbreviations and supplementary figures
- "articles" that are presentations or other content (e.g. PDF!?!?!?!?)
    - http://viewerjs.org/
- Article indexes include repository URLs, source code, etc.
- Copy BibTeX on citation hover

- test for arxiv as distill does when generating citations

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
    
    
    
