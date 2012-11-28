According to the interviews in "Creating a Shared Understanding of Testing
Culture on a Social Coding Site" by Pham et al. the following characteristics
affect a project owners pull request acceptance decision. For each one, I
present a list of questions we can answer with the GHTorrent dataset.

* Pull requests of trusted vs untrusted developers. Trusted are developers that
have committed to the project before.

  - Test pull request acceptance speed
  - Test pull request acceptance (or rejection)
  - Test whether, through time, more frequent pull requests lead to merges
    faster merges

* Pull request size. Pull request impact. ("If the project owner believed to have quickly understood the changes' impact, they demanded no tests from the contributor.")

  - Split pull requests in "big" and "small". Criteria:
    - Number of files touched
    - Number of lines touched
    - Kmeans/ExpMax on the above and use produced clusters (?)
  - Test whether "big" pullreqs containing tests are faster to merge than "big"
    pullreqs without tests
  - Test whether "big" pullreqs are merged faster in projects containing tests.
  - For "small" pullreqs test whether the existence of tests (in the project or
    in the pull request) affects merge speed.
  - Continuous integration + pull requests: Check whether Travis integration
    helps with acceptance of pull requests

* Pull requests and types of contribution

  - How to categorize types of contributions:
    - Categorize pullreqs in "adaptive" (mostly modifications), "perfective"
    (mostly additions, linked to an issue), "corrective" (linked to an issue).
    There has been similar work on how to classify big commits (What do large
    commits tell us?: a taxonomical study of large commits by Hindle et al.)
    - New features (just added files, no issue referenced in commit) vs code fixes
    (mixed additions/modifications, issues referenced)
  - Test which type of change gets merged faster.
  - Examine the extend of which pullreqs per category contain tests or not
  - Test whether tests affect the merge (and time) of each kind of pullreq

* Target of changes: changes in the system core vs peripheral changes

  - How to find the system core? Perhaps graph of system components +
    centrality/pagerank metrics? Or perhaps parts of the system that have not
    changed for long before the pull request merge.
  - Classify pull requests in core vs peripheral, based on the files they touch
  - Find tests exercising the core vs peripheral systems
  - Test whether tests help accept pull requests faster in the core

* Effort to create tests for changes affected by pullreq

  - How to calculate/estimate it? Perhaps size/complexity of changes, build
    status on Travis.
  - Test whether high testing effort leads to slower merge times
  - See also pullreq complexity vs testing above

* Communicating requirements via tests

  - BDD style of testing. Grep for //Given, //Then, //When in commits This will
    give an indication on whether BDD is in effect in a repository Check whether
    projects working in the BDD style tend to receive more contributions in
    their test suits.
  - Limit the search to Ruby: split projects to those containing BDD tests
    (cucumber) and normal Runit/Rspec tests. See whether BDD invites more
    testing contributions.

* Motivations for testing in/with pullreqs

  - Domain with strong testing requirements/culture
    - Classify applications per domain (how? probably manually), compare test
      coverage or simpler metrics such as asserts/kloc across domains
    - Test if pullreqs on application domains where testing is strong have a
      higher probability of including/affecting tests

  - Core team acting as role models.
    - Classify developers according to test habits (num of tests, num of tested
      lines, % commits with/affecting tests), identify testing leaders.
    - Test if projects with test leaders receive test-related pullreqs than
      against the general population

  - Tests that fail before the pullreq has been merged and succeed after.
    Supposedly demonstrate efficacy of bug fix, so should be faster to merge
    - For each pull request including new test code, need to identify whether
      test fails before and succeeds after merge. Need to run test or perhaps
      parse Travis CI results
    - Test whether the above identified pull requests are faster/more likely to
      merge than normal bug fixing pull requests.

  - Existence of tests prompts more tests to be contributed -> are test suites
    self-sustainable? Implicit demand for tests in well tested environments
    (e.g. Ruby ecosystem)
    - Classify projects based on strength of test suite. What variables can
      describe the strength of a test suite?
    - Test whether projects with test suites get more tests/test fixes in their
      pull requests
    - Co-evolution of code/test suites

* Core developers vs periphery developers

  - Lots of work already, but perhaps might be good to redo it in the context of
    tasks (and corresponding roles) related to Github, especially since data
    across issues/commits are homogenized

* Project scale: how does it affect testing

  - Test whether large projects tend to improve test suites over time
  - Test whether improvement of test suites (asserts/kloc, coverage) affects
    rate/size of external contributions
  - Testing culture communication: Identify projects with implicit (in their
    build system, or following project ecosystem conventions) or explicit
    (written in their documentation, find them probably through manual effort)
    testing instructions. Test whether those projects are better at attracting
    pullreqs with tests than the average population.

* Drive-by commits

  - Measure % of commits from core team members vs commits from pullreqs not
    comming from core members
  - See what those commits usually affect: code, documentation, tests
  - Classify projects according to % of drive-by commits
  - Test whether drive-by commits have a significant/negligible impact on
    evolution or project quality

####Potential full papers and their contents

* Best practices for submitting/handling pull requests.
  - Explain how pull reqs work
  - Determine factors that affect pull request acceptance. Do a multivariate
  analysis of the following
    - Size
    - Complexity
    - Testing
    - Types of contributions
    - Developer trust
    - Target of changes (system core or peripheral components?)
  - Findings and recommendations on how to construct more effective pullreqs
    and/or when to accept them.

* Testing and pull requests
  - Examine what affects contribution to test suites
    - Domain culture
    - Core team acting as role models
    - Self-sustainability of test suites
    - Communication of testing culture
  - Provide recommendations

####Potential side papers and their contents

* Test suite requirements and evolution
  - How are testing requirements communicated (documentation, BDD style)
  - How this affects contributions to test suite

* Drive-by commits
  - Definition (casual 1-2 commit long pullrequests by developers unknown to the
    project)
  - Empirical evidence of their existence.
  - Motivations for users (classification of commit contents), perhaps
    questionnaires?
  - What affects their acceptance? Motivation to accept and assessment of
    contents from the project team size.
    - Role of testing?
  - Findings and recommendations to developers and practitioners
