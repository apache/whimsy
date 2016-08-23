Configuring the Secretary Workbench

Install Dependencies
--------------------

Change directory to `whimsy/www/secretary/workbench`

Run:

```
$ bundle install
```

The last line of the output should say:

```
Bundle updated!
```

Indentify where files are to be found
-------------------------------------

Copy template

```
$ cp local_paths.yml ~/.secassist
```

Edit file paths in `~/.secassist`.  For all but the `mail` entry, what you will
be specifying is the path to a local checkout of the associated ASF repository.
And, yes, many of these entries are subdirectories of others that are in the
list, which gives flexibility should have have done your initial checkout
specifying the `--depth` parameter.  Just identify where each can be found.

For the last entry, specify the name of a new file location which will be used
in the next step to configure mail.  I suggest `.secmail` in your home
directory.  This needs to be a full path (i.e., don’t start with a `~`).


Configure Apache to display documents received
--------------

Edit `/etc/apache2/other/whimsy.conf`.  Search for `# for secretary workbench`.
On the next two lines, update the paths to point to where you have a local
checkout of `documents/received`.

Run:

```
$ sudo apachectl restart
```

Install pdftk
-------------

Download from [pdflabs](https://www.pdflabs.com/tools/pdftk-server/).

