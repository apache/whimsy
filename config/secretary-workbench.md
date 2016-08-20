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
directory.  This needs to be a full path (i.e., don't start with a `~`).

Configure mail
--------------

Every mail delivery system appears to be different.  Once whitelisted, `sendmail` works fine on `whimsy-vm3.apache.org`.  Others may require passwords or may throttle the rate at which emails can be sent.

The one option that appears to work for everybody is gmail.

Start by copying the `secmail.rb` template to the location you specified in
your `local_paths.yml`.   For example, if you took the recommendatio above, issue:

```
$ cp secmail.rb ~/.secmail
```

Edit the file, and replace the line that says `delivery_method :sendmail`
with the following block of code:

```
delivery_method :smtp,
  address:        "smtp.gmail.com",
  port:           587,
  domain:         "apache.org",
  authentication: "plain",
  user_name:      "<your-gmail-user-name>",
  password:       "<your-gmail-password>",
  enable_starttls_auto: true
```

Note that the code later in the file determines what *from* address will be
used in the email (and the `domain` above should match the host portion of
this address).  Gmail will just be used as a delivery mechanism.

Also note that the $USER value in this script is your Apache user id, which
may be different than your local user id.

Configure Apache to display documents received
--------------

Edit `/etc/apache2/other/whimsy.conf`.  Search for `# for secretary workbench`.
On the next two lines, update the paths to point to where you have a local
checkout of `documents/received`.

Run:

```
$sudo apachectl restart
```

