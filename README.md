Berktacular
===========

Berktacular is a gem that parses json type chef environment files and does things with them.
It supports an additional json field called "cookbook_locations" containing a hash of cookbook locations at the same level as "cookbook_versions"
The top level key is the cookbook name.  Under it, the following keys are supported:
<pre>
  "github"      : "github_account/repo_name"
  "tag"         : "string-%{version}"
  "auto_upgrade": true
  "rel"         : "path/relative/to/repo_name"
  "versions"    : version hash that contains mappings to github commit refs.  see below.
</pre>
The special string '%{version}' is replaced with the version from cookbook_versions.
The 'versions' hash allows the creation of verioned dependancies for cookbooks that are in github but not tagged.  It provides a mapping of arbitrary version strings to a git commit reference.
<pre>
Example:
"cookbook_locations": {
  "untagged_repo": {
    "github": "account/untagged_repo"
    "versions": {
      "0.0.1": {
        "ref": "1234567890abcdef1234567890abcdef12345678"
      }
    }
  }
}
</pre>
This would allow you to reference version "0.0.1" of "untagged_repo" from your cookbook_versions section.

The "auto_upgrade" flag allows berktacular to auto-update a cookbook to latest available tagged version.

Using the --upload flag, berktacular will generate a Berksfile, verify it, and upload the environment file and derived Berksfile to the chef server.
When --upgrade is used, the environment file and Berksfile are both uploaded to the chef server with the latest versions filled in for any cookbooks marked "auto_upgrade".

