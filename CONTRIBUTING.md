## How to contribute to ActiveRecord::HierarchicalQuery

#### **Do you have questions about the source code?**

* This type of project is *challenging*. If you want to help but
  are intimidated or having trouble, reach out to @zachaysan and
  he'll teach you how it fits together so you don't waste time.

#### **Did you find a bug?**

* **Do not open up a GitHub issue for security vulnerabilities**,
    instead reach out privately to @zachaysan. You should get a
    response within three business days. If you don't you hit his spam
    filter. Make a vague Github issue.

* **Ensure the bug was not already reported** by searching current
    [Issues](https://github.com/take-five/activerecord-hierarchical_query/issues).

* If the bug is for the non-latest version of Rails, and is not
  security related, then only open an issue if you are prepared
  to tackle the bug yourself. Rails 3 is no longer supported.

* Still need to make an issue? Be sure to include a **title and
  clear description**, as much relevant information as possible.
  Please have steps to re-create the issue *from scratch* if at
  all possible.

#### **Writing a patch?**

* [Fork it](http://github.com/take-five/activerecord-hierarchical_query/fork),
  clone it, `bundle`, `rake`. Tests all pass? Great. Make a new branch,
  then start writing the patch. Write commit messages like
  [this](https://git.kernel.org/pub/scm/git/git.git/tree/Documentation/SubmittingPatches?id=HEAD#n133).

* Most patches should come with tests.

* Tests all pass, but you're still nervous? If you have a Rails
  project with a well developed test suite build the gem locally
  and make sure it works there as well.
  [This](https://guides.rubygems.org/faqs/) might help if you are
  having trouble.

#### **Did you write a patch that fixes a bug?**

* Open a new GitHub pull request with the patch. Try to keep PRs small.

* Ensure the PR description clearly describes the problem and
  solution. Include the relevant issue number if applicable.

* Please squash commits that are effectively one simple change into a
  single commit. So if your patch changes a method and the test for
  the method, keep both changes in a single commit.

#### **Whitespace / code format / cosmetic changes in patches**

* Please don't. At some point this repo may be overhauled, but for
  now it's more important to focus on keeping it functional.

#### **Do you intend to add a new feature or change an existing one?**

* Performance changes: Great! Prototype it out to make sure it
  works, then make an issue with the suggestion.

* Security-by-default changes: Same.

* Extending functionality: Maybe? Privately contact
  @zachaysan. This project prizes stability and reliability over
  functionality, but if it is really useful it's worth a chat.

#### **Do you want to contribute to the documentation?**

* Great. Anything to make things clearer is appreciated,
  especially from junior developers that struggled to figure
  something out.
