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
DVCs hosting, easy forking of projects, workflow support tools, such as code reviewing systems and issue trackers and social networking features. The result is a new type of development workflow, where transparency, immediacy and general "openess" help developers^1^ overcome the communication barriers inherent to distributed programming and lowers the barriers of engagement to 
external contributors.
### How does pull-based development work?Generally speaking, the purpose of distributed development is to enable a potential contributor to submit a set of changes to a software project. The contribution models afforded by DVCSs are a superset of those in centralized version control environments. With respect to receiving and processing external contributions, the following strategies can be employed with DVCs:Shared repository
:  The core team shares the project’s repository, with read and write permissions, with the contributors. To work, contributors clone it locally, modify its contents, potentially introducing new branches, and push their changes back to the central one. To cope with multiple versions and multiple developers, larger projects usually adopt a branching model, i.e., an organized way to inspect and test contributions before those are merged to the main development branch.

Pull requests
: The project’s main repository is not shared among potential contributors; instead, contributors fork (clone) the repository and make their changes independent of each other. When a set of changes is ready to be submitted to the main repository, they create a pull request, which specifies a local branch to be merged with a branch in the main repository. A member of the project’s core team is then responsible to inspect the changes and pull them to the project’s master branch. If changes are considered unsatisfactory, more changes may be requested; in that case, contributors need to update their local branches with new commits. Furthermore, as pull requests only specify branches from which certain commits can be pulled, there is nothing that forbids their use in the shared repository approach (cross-branch pull requests). 



## Why is pull-based development effective?

We conducted an quantitative study of the top 300 pull request
using projects on Github, as provided by our GHTorrent dataset[#addef]. This number includes projects written in Ruby, Python,
Java and Scala and excluded projects without external contributions. 
In total, we analyzed almost 170k pull requests. 

### Is it effective?

Our findings show that the majority (80%) of pull requests are merged within 4 days, 60% in less than a day, while 30% are merged within one hour (independent of project size).

One of the promises of the pull request model is fast development turnover, i.e., the time between the submission of a pull request and its acceptance in the project’s main repository. In various studies of the patch submission process in projects such as Apache and Mozilla, the researchers found that the time to commit 50% of the contributions to the main project repository ranges from a few hours [30] to less than 3 days [32, 3].  These numbers are indicating that pull-based development through pull requests may be more efficient than traditional email-based patches. Also, it is project- related factors that affect the turnover time, rather than characteristics of the pull request itself. This means that it is mostly up to the project to tune its processes (notably, testing coverage and process openess) for faster turnover.


### Process transparency

The interviewees in Dabbish et al. [10] identify the management of pull requests as the most important project activity. Dabbish et al. mention that project managers “made inferences about the quality of a code contribution based on its style, efficiency, thoroughness (for example, was testing in- cluded?), and the submitter’s track record”. Some of the inspec- tion points mentioned by project managers (testing code in pull requests, track record) are also included as features in our classi- fication models, but they do not seem to affect the merge decision process as much. However, the developer track record is important for the speed of processing pull requests. Moreover, we found that from rejected pull requests, almost 53% are rejected due to the distributed nature of pull-based development. While the pull request process is transparent from the project manager’s side (and praised for that by Dabbish et al.’s interviewees), our findings suggest it is less so from the potential contributor’s point of view.

### Attracting contributions

Pham et al. [26] found that pull requests make casual contributions straightforward through a mechanism often referred to as “drive-by commits”. As the relative cost to fork a repository is negligible on Github (54% of the repositories are forks), it is not uncommon for developers to fork other repositories to perform casual commits. Such commits might be identified as pull requests that contain a single commit from users that are not yet part of the project’s community and comprise 7% of the total number of pull requests in 2012. Moreover, 3.5% of the forks were created for the sole purpose of creating a drive-by commit. More work needs to be done for the accurate definition and assessment of the implications of drive-by commits.

### Crowd-sourcing code reviews

### Democratizing development


## Applying pull-based development


## Conclusions

### Acknowledgments

## References

#### About

**Georgios Gousios** is a postdoctoral researcher at the Delft University
of Technology, NL. His research interests include distributed software
development, big data in software engineering and software testing.
In the past, he has worked on a variety of topics ranging from virtual machines to software engineering research platforms and co-edited the "Beautiful Architectures" book  (O'Reilly 2009). Recently, he was a recipient of a EC Marie Curie IEF grant. He can be found on various social networks as @gousiosg, while he maintains a blog at http://gousios.gr/blog.

---

1. Not everyone agrees. See Linus Torvald's opinion on [Github's pull requests](https://github.com/torvalds/linux/pull/17).