

- RStudio post preview isn't quite right for inline collection preview
    - relative references won't be correct when output_dir is defined
    - we either need:to:
        - copy the post to output_dir during preview (maybe smart copy?); or
        - don't attempt to show site navigational elements for single post preview
    - Currently no footer in preview

- Saving Rmd file in website project re-knits


- index/category/archive pages
- google analytics and discourse commenting
- search
- built-in social buttons

- Clike should allow dots in name

- R highlighting treatment (for now we just patched clike to handle comments)


- Docs: note that echo = FALSE by default and explain 70 character constraint
- Warn users on code width > 70 characters
- Set output width to 70 characters
- Document 70 characters

- Improved error messages for incomplete author field

- Add thumbnails to sample posts
- Add some citations to sample posts

- base_dir + author should yield a citation url

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

- Embedded articles:

   - document cannonical url
   - attribution metadata for inclusion when importing/syndicating (do during import)
   - import article function(s)


- Document prism changes somewhere:
    - Added comment pattern: {pattern:/(^|[^\\])#.*/,lookbehind:!0}
    - Allow . in function names: function:/[a-z\.0-9_]

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
    
    
    
