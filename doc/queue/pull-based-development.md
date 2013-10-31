# Pull-based development

**Georgios Gousios**

October 2013

*By pulling change sets from remote repositories, as opposed to pushing them
to a central one, distributed software development teams can collaborate more efficiently.*

Since their appearance in 2001, distributed version control systems (DVCS), notably Git, have revolutionized the way distributed software development is carried out. Driven by pragmatic needs, most DVCSs were designed from scratch to work as advanced patch management systems, rather than versioned file systems. For most DVCSs, a file is an ordered set of changes, the serial application of which leads to the current state. Changes are stamped by globally unique identifiers, which can be used to track the commit’s content across repositories. When integrating changes, the change sets can originate from a local filesystem or a remote host; tools facilitate the acquisition and application of change sets on a local mirror. 

The distributed nature of DVCSs enables a *pull-based development model*.
In that, changes are offered to a project repository through a network of project forks rather than being pushed to it. The novelty of the pull-based
model lays in the decoupling of the development effort from the decision to incorporate the results of the development in the code base. By separating the concerns of building artifacts and integrating changes, work is cleanly distributed between a *team of contributors* that submits, often occasional, changes to be considered for merging and a *core team* that oversees the merge process, providing feedback, conducting tests, requesting changes, and finally accepting the contributions. Like many (most?) distributed development practices followed today, pull-based development has its roots in Open Source Software development.
Linus Torvalds, applied it as a 
managing incoming contributions to the Linux kernel project, and build 
Git as a tool to support it. Within the kernel development model, a
contributed patch, in the form of a list of commits or an actual text diff, can go through a variety of testing and integration repositories before it reaches the main line.

While the Linux development process is *de facto* efficient, its complexity
and tool centric approach can be daunting for non team members, which limits
its accessibility to potential contributors. As more projects came to appreciate pull-based development, a
business opportunity had risen: provide a standardized pull-based development workflow that can be appealing to the masses.
Various code hosting sites, notably Github, have tapped on it, by combining
DVCs hosting, easy forking of projects, workflow support tools, such as code reviewing systems and issue trackers and social networking features. The result is a new type of development workflow, where transparency, immediacy and general "openess" help developers^1^ lift the communication barriers inherent to distributed programming and lowers the barriers of engagement to 
external contributors.
## How does pull-based development work?Generally speaking, the purpose of distributed development is to enable a potential contributor to submit a set of changes to a software project. The contribution models afforded by DVCSs are a superset of those in centralized version control environments. With respect to receiving and processing external contributions, the following strategies can be employed with DVCs:**Shared repository**
:  The core team shares the project’s repository, with read and write permissions, with the contributors. To work, contributors clone it locally, modify its contents, potentially introducing new branches, and push their changes back to the central one. To cope with multiple versions and multiple developers, larger projects usually adopt a *branching model*, i.e., an organized way to inspect and test contributions before those are merged to the main development branch (e.g. Git flow).

**Pull requests**
: The project’s main repository is not shared among potential contributors; instead, contributors *fork* (clone) the repository and make their changes independent of each other. When a set of changes is ready to be submitted to the main repository, they create a pull request, which specifies a local branch to be merged with a branch in the main repository. A member of the project’s core team is then responsible to inspect the changes and pull them to the project’s master branch. If changes are considered unsatisfactory, more changes may be requested; in that case, contributors need to update their local branches with new commits. Furthermore, as pull requests only specify branches from which certain commits can be pulled, there is nothing that forbids their use in the shared repository approach (*cross-branch pull requests*). 

### The Github factor

Github supports all types of distributed development outlined above; however, pull requests receive special treatment. The site is tuned to allow easy forking of projects by contributors, while facilitating the generation of pull requests through automatic comparison of project branches. Github’s pull request model follows the generic pattern presented above; in addition it provides tools for contextual discussions and in-line code reviews.

A Github pull request contains a branch (local or in another repository) from which a core team member should pull commitsfrom. Github automatically discovers the commits to be merged and presents them in the pull request. By default, pull requests are submitted to the base (*upstream* in Git parlance) repository for inspection. The inspection is either a code review of the commits submitted with the pull request or a discussion about the features introduced by the pull request. Any Github user can participate to both types of inspection. As a result of the inspection, pull requests can be updated with new commits or be closed as redundant, uninteresting or duplicate. In case of an update, the contributor creates new commits in the forked repository, while Github automatically updates the displayed commits. The code inspection can then be repeated on the refreshed commits.



## Why is pull-based development effective?

In a distributed collaboration setting, a process if effective if
its results are accepted as part of the final product and it is efficient if
this happens in a timely manner with respect to the project planning. 

To examine the effectiveness of pull-based development, we conducted a quantitative study of the top 300 pull request
using projects on Github, as provided by our GHTorrent dataset[#add ref]. The set included projects written in Ruby, Python,
Java and Scala and excluded projects without external contributions. 
In total, we analyzed almost 170k pull requests. From this set, we also examined manually 350 not merged pull requests to determine the reasons for which those were rejected.

### Is it effective?

Yes. 82% of the submitted pull requests are merged. What is more important is that we saw little variation across projects, which means that the effective rate
of accepted contributions is very high. Similar studies of email or bug database patch acceptance in open source projects mention that 40% of the
contributions are accepted.

Moreover, the code reviewing process 

### Is it efficient?

Yes. The majority (80%) of pull requests are merged within 4 days, 60% in less than a day, while 30% are merged within one hour (independent of project size). In various studies of the patch submission process in projects such as Apache and Mozilla, the researchers found that the time to commit 50% of the contributions to the main project repository ranges from a few hours to less than 3 days. We found that project-related factors affect the turnover time, rather than characteristics of the pull request itself. This means that it is mostly up to the project to tune its processes (notably, testing coverage and process openess) for faster turnover.

### Process transparency

The interviewees in Dabbish et al. [10] identify the management of pull requests as the most important project activity. Dabbish et al. mention that project managers “made inferences about the quality of a code contribution based on its style, efficiency, thoroughness (for example, was testing included?), and the submitter’s track record”. Some of the inspection points mentioned by project managers (testing code in pull requests, track record) are also included as features in our classification models, but they do not seem to affect the merge decision process as much. However, the developer track record is important for the speed of processing pull requests. Moreover, we found that from rejected pull requests, almost 53% are rejected due to the distributed nature of pull-based development. While the pull request process is transparent from the project manager’s side (and praised for that by Dabbish et al.’s interviewees), our findings suggest it is less so from the potential contributor’s point of view.

### Attracting contributions

Pull requests make casual contributions straightforward through a mechanism often referred to as “drive-by commits”. As forking a repository is a click of a button away on Github (and indeed more than 60% of the repositories are forks), it is not uncommon for developers to fork other repositories to perform casual commits. 
such as fixes to spelling mistakes or indentation issues. 
In addition, Github provides web based editors
for various file formats, by which any user can edit any file in another
repository; behind the scenes, Github forks the repository and asks the user
to create a pull request to the original one.
Drive-by commits might be identified as pull requests that contain a single commit from users that are not yet part of the project’s community and comprise 7% of the total number of pull requests in 2012. Moreover, 3.5% of the forks were created for the sole purpose of creating a drive-by commit. 

Drive-by commits can be a great way of attracting contributions. 

**TODO** Look for commits in the repo by drive by committers


### Crowd-sourcing code reviews

An important part of the contribution process to an open source project is the review of the provided code. In other studies, report that 80% of the core team members are also participating in the code reviews for patches. In our dataset, we found that *all* core team members across all projects have participated in at least one discussion in a pull request. Moreover, we found that in all projects in our dataset, the community discussing pull requests is actually bigger than the core team members.

**TODO** We need to look at whether num commenters non-team-members, non-pullrequesters > 0

### Democratizing development

One of our key findings is that pull requests are not treated differently based on their origin; both core team members and external developers have equal chances to get their pull request accepted within the same time boundaries. This is a radical change in the way open source development is being carried out. Before pull requests, most projects employed membership promotion strategies to promote interested third party developers to the core team. With pull requests, developers can contribute to any repository, without loss of authorship information. The chances that those contributions will get accepted are higher with pull requests (82% vs 40%).



## Applying pull-based development

As with every process change, the real challenge is to make it work for
the organization's benefit. The expected benefit might be different for
each organization. 

## Conclusions

## References

* Vincent Driessen. [A successful Git branching model](http://nvie.com/posts/a-successful-git-branching-model/)

#### About

**Georgios Gousios** is a researcher at the Delft University of Technology, NL. His research interests include distributed software
development, big data in software engineering and software testing.
In the past, he has worked on a variety of topics ranging from virtual machines to software engineering research platforms and co-edited the "Beautiful Architectures" book  (O'Reilly 2009). Recently, he was a recipient of a EC Marie Curie IEF grant. He can be found on Github and Twitter as @gousiosg, while he maintains a blog at http://gousios.gr/blog.

---

1. Not everyone agrees. See Linus Torvald's opinion on [Github's pull requests](https://github.com/torvalds/linux/pull/17).