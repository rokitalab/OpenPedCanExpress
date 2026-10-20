<!--Hi there, thanks for your contribution! Please take a moment to fill out this template to facilitate the review of your pull request.-->

### Purpose/implementation Section

#### What does this pull request change, and why?



#### What was your approach?



#### What GitHub issue does your pull request address?
<!--For example, "Closes #12". Remove this section if there is no issue.-->



#### What does this change affect?

<!-- Check all those that apply. -->

- [ ] The web app (`public/`): plots, the Configure panel, or other behavior users see
- [ ] Preprocessing (`scripts/`): the Parquet files would change if rebuilt
- [ ] Source data or metadata (`data/source/`): new or updated inputs, labels, or groups
- [ ] Documentation only (README, Docs page, release notes)
- [ ] Deployment or GitHub workflows

### Directions for reviewers. Tell potential reviewers what kind of feedback you are soliciting.

#### Which areas should receive a particularly close look?



#### Is there anything that you want to discuss further?



### Testing

#### How did you test this?
<!--For example, which genes you searched, which groups or options you checked, and how you ran the app (`python3 -m http.server` in `public/`, then open `index.html`). If you rebuilt the Parquet files, note how long it took and any warnings.-->



#### Screenshots
<!--For changes to the plots or the Configure panel, add before and after screenshots. Remove this section if not applicable.-->



### Data and release impact

<!-- Check all those that apply, or remove this section if it is not applicable. -->

- [ ] This pull request needs the Parquet files to be rebuilt and uploaded to a new data release folder (describe what changes in the data).
- [ ] The app's default data release (`index.html`) should change when this is released.
- [ ] No data or release changes are needed.

#### Reproducibility Checklist

<!-- Check all those that apply or remove this section if it is not applicable.-->

- [ ] The dependencies required to run the code in this pull request have been added to `scripts/00-install-deps.R` and the project `Dockerfile`.
- [ ] Any new source file is listed in `data/source/README.md`, and large data files are not committed to git.

#### Documentation Checklist

- [ ] The release notes (`public/releases.js`) describe the change, if users will notice it.
- [ ] The Docs page (`public/docs.html`) and `README.md` are up to date.
- [ ] The code is documented and contains comments where the reason is not obvious.
