According to the interviews by "Creating a Shared Understanding of Testing
Culture on a Social Coding Site" by Pham et al. the following characteristics
affect a project owners pull request acceptance decision. For each one, I
present a list of tests we can to do with the data in order to confirm/reject
the claims. 

* Pull requests of trusted vs untrusted developers. Trusted are developers that
have committed on a project again.
  
  - Test pull request acceptance speed
  - Test pull request acceptance (or rejection)
  - Test whether, through time, more frequent pull requests lead to merges faster
  merges

* Pull request size. Pull request impact. ("If the project owner believed to have quickly understood the changes' impact, they demanded no tests from the contributor.")
  
  - Split pull requests in "big" and "small". Criteria:
    * Number of files touched
    * Number of lines touched
    * Kmeans/ExpMax on the above and use produced clusters (?)
  - Test whether "big" pullreqs containing tests are faster to merge than
  "big" pullreqs without tests
  - Test whether "big" pullreqs are merged faster in projects containing tests.
  - For "small" pullreqs test whether the existence of tests (in the project or
   in the pull request) affects merge speed.

* Pull requests and types of contribution
  - Categorize pullreqs in "adaptive" (mostly modifications), "perfective"
  (mostly additions, linked to an issue), "corrective" (linked to an issue).
  There has been similar work on how to classify big commits (What do large
  commits tell us?: a taxonomical study of large commits by Hindle et al.) 
  - Test which type of change gets merged faster.
  - Examine the extend of which pullreqs per category contain tests or not
  - Test whether tests affect the merge (and time) of each kind of pullreq

* Target of changes: changes in the system core vs peripheral changes
  - How to find the system core? Perhaps graph of system components components +
  centrality/pagerank metrics?  
  - Classify pull requests in core vs peripheral, based on the files they touch
  - Find tests exercising the core vs peripheral systems
  - Test whether tests help accept pull requests faster in the core

* Effort to create tests for changes affected by pullreq
  - How to calculate/estimate it?
  - Test whether high testing effort leads to slower merge times
  - See also pullreq complexity vs testing above

* Communicating requirements via tests
  - ?

* Motivations for testing pullreqs
  - Domain with strong testing requirements/culture
    - Classify applications per domain (how? probably manually), compare 
    test coverage or simpler metrics such as asserts/kloc across domains
    - Test if pullreqs on application domains where testing is strong have
    a higher probability of including/affecting tests
  - Core team acting as role models.
    - Classify developers according to test habits (num of tests, num of 
    tested lines, % commits with/affecting tests), identify testing leaders. 
    - Test if projects with test leaders receive test-related pullreqs than
    against the general population
  - Tests that fail before the pullreq change and succeed after merge
    - 
  - Existence of tests promtps more tests to be contributed
    - Classify projects in  
