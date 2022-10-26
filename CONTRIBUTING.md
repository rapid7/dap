# Contributing to dap

The users and maintainers of dap would greatly appreciate any contributions
you can make to the project.  These contributions typically come in the form of
filed bugs/issues or pull requests (PRs).  These contributions routinely result
in new versions of the [dap gem](https://rubygems.org/gems/dap) to be
released.  The process for everything is described below.

## Contributing Issues / Bug Reports

If you encounter any bugs or problems with dap, please file them
[here](https://github.com/rapid7/dap/issues/new), providing as much detail as
possible.  If the bug is straight-forward enough and you understand the fix for
the bug well enough, you may take the simpler, less-paperwork route and simply
fill a PR with the fix and the necessary details.

## Contributing Code

dap uses a model nearly identical to that of
[Metasploit](https://github.com/rapid7/metasploit-framework) as outlined
[here](https://github.com/rapid7/metasploit-framework/wiki/Setting-Up-a-Metasploit-Development-Environment),
at least from a ```git``` perspective.  If you've been through that process
(or, even better, you've been through it many times with many people), you can
do exactly what you did for Metasploit but with dap and ignore the rest of
this document.

On the other hand, if you haven't, read on!

### Fork and Clone

Generally, this should only need to be done once, or if you need to start over.

1. Fork dap: Visit https://github.com/rapid7/dap and click Fork,
   selecting your github account if prompted
2.  Clone ```git@github.com:<your-github-username>/dap.git```, replacing
```<your-github-username>``` with, you guessed it, your Github username.
3.  Add the master dap repository as your upstream:

 ```
   git remote add upstream git://github.com/rapid7/dap.git
 ```
4. Update your `.git/config` to ensure that the `remote ["upstream"]` section is configured to pull both branches and PRs from upstream.  It should look something like the following, in particular the second `fetch` option:

    ```
     [remote "upstream"]
      url = git@github.com:rapid7/dap.git
      fetch = +refs/heads/*:refs/remotes/upstream/*
      fetch = +refs/pull/*/head:refs/remotes/upstream/pr/*
     ```
5. Fetch the latest revisions, including PRs:

    ```
    git fetch --all
    ```

### Branch and Improve

If you have a contribution to make, first create a branch to contain your
work.  The name is yours to choose, however generally it should roughly
describe what you are doing.  In this example, and from here on out, the
branch will be FOO, but you should obviously change this:

```
git fetch --all
git checkout master
git rebase upstream/master
git checkout -b FOO
```

Now, make your changes, commit as necessary with useful commit messages.

Please note that changes to [lib/dap/version.rb](https://github.com/rapid7/dap/blob/master/lib/dap/version.rb) in PRs are almost never necessary.

Now push your changes to your fork:

```
git push origin FOO
```

Finally, submit the PR.  Navigate to ```https://github.com/<your-github-username>/dap/compare/FOO```, fill in the details and submit.

### Testing

You are encourage to perform testing _before_ submitting the PR.  There are two types of tests in place:
run `bundle exec rspec spec`.  # Testing

There are two testing frameworks in place.

* Ruby `rspec`
* [bats](https://github.com/sstephenson/bats) integration tests

To run these tests locally, run:
```
docker build -t dap_testing -f Dockerfile.testing . && \
docker run --rm --name dap_testing -it -e DAP_EXECUTABLE=dap dap_testing /bin/bash -l -c "rvm use 2.7.6 && gem build dap && gem install dap*.gem && bundle exec rspec spec && find /opt/bats_testing -name \*.bats | grep -v test/test_helper/ | xargs -n1 bats"
```

## Landing PRs

(Note: this portion is a work-in-progress.  Please update it as things change)

Much like with the process of submitting PRs, dap's process for landing PRs
is very similar to [Metasploit's process for landing
PRs](https://github.com/rapid7/metasploit-framework/wiki/Landing-Pull-Requests).
In short:

1. Follow the "Fork and Clone" steps from above
2. Update your `.git/config` to ensure that the `remote ["upstream"]` section is configured to pull both branches and PRs from upstream.  It should look something like the following, in particular the second `fetch` option:

    ```
     [remote "upstream"]
      url = git@github.com:rapid7/dap.git
      fetch = +refs/heads/*:refs/remotes/upstream/*
      fetch = +refs/pull/*/head:refs/remotes/upstream/pr/*
     ```
3. Fetch the latest revisions, including PRs:

    ```
    git fetch --all
    ```
4. Checkout and branch the PR for testing.  Replace ```PR``` below with the actual PR # in question:

    ```
    git checkout -b landing-PR upstream/pr/PR
    ```
5. Test the PR (see the Testing section above)
6. Merge with master, re-test, validate and push:

    ```
    git checkout -b upstream-master --track upstream/master
    git merge -S --no-ff --edit landing-PR # merge the PR into upstream-master
    # re-test if/as necessary
    git push upstream upstream-master:master --dry-run # confirm you are pushing what you expect
    git push upstream upstream-master:master # push upstream-master to upstream:master
    ```
7. If applicable, release a new version (see next section)

## Releasing New Versions

When dap's critical parts are modified, for example its decoding or underlying supporting code, a new version _must_ eventually be released.  Releases for non-functional updates such as updates to documentation are not necessary.

When a new version of dap is to be released, you _must_ follow the instructions below.

1. If are not already a dap project contributor for the dap gem (you'd be listed [here under OWNERS](https://rubygems.org/gems/dap)), become one:
  1. Get an account on [Rubygems](https://rubygems.org)
  2. Contact one of the dap project contributors (listed [here under OWNERS](https://rubygems.org/gems/dap) and have them add you to the dap gem.  They'll need to run:
    ```
      gem owner dap -a EMAIL
    ```
2. Edit [lib/dap/version.rb](https://github.com/rapid7/dap/blob/master/lib/dap/version.rb) and increment ```VERSION```.  Commit and push to rapid7/dap master.
3. Run `rake release`.  Among other things, this creates the new gem, uploads it to Rubygems and tags the release with a tag like `v<VERSION>`, where `<VERSION>` is replaced with the version from `version.rb`.  For example, if you release version 1.2.3 of the gem, the tag will be `v1.2.3`.
4. If your default remote repository is not `rapid7/dap`, you must ensure that the tags created in the previous step are also pushed to the right location(s).  For example, if `origin` is your fork of dap and `upstream` is `rapid7/master`, you should run `git push --tags --dry-run upstream` to confirm what tags will be pushed and then `git push --tags upstream` to push the tags.

## Misc tips on building dap

Ruby often comes prepackaged on linux/mac os systems. Although the README already mentions using `rbenv`, it useful to make sure your envoiroment is actually using `rbenv` before running any ruby commands such as `gem`, `bundle`, `ruby` or `dap` itself utilizing the `which` command to confirm that the their paths indicate they came from `rbenv`.
