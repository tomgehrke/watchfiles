# watchfiles.sh

## What is it?

This bash script is just a fancier way of getting file listings without having to remember all of the command-line options for `ls` or `find` while also giving you some reasonably formatted results.

## Why is it?

The problem I was originally trying to solve was that I needed to monitor several folders that were used as part of a file transfer process. In its basic form, File A gets dropped in a folder, a process picks it up, a response is generated and then that file is moved to a response folder. With little visibility into this file movement, problems would be identified by customers after the fact. Things are going to break, but it's always better if one can self-identify and resolve an issue before a customer is impacted.

## How does it work?

Much can be gleaned about the usage possibilites by a review of the command line arguments.

```bash
Usage: ./watchfiles.sh [OPTION] ...
List files recursively (the current directory by default).

Mandatory arguments to long options are mandatory for short options too.

  -t, --target             Path to target directory if other than current.
                           NOTE: If your target path has wildcards or spaces, you
                           will want to enclose the path in quotation marks.
  -p, --fileRegex          The regex pattern for including a file in the listing.
  -n, --minAgeAlert        Flag files that are at least this old (in minutes).
  -N, --minAgeIgnore       Exclude from the listing files that are newer (in minutes).
  -a, --maxAgeAlert        Flag files that are older than this (in minutes).
  -A, --maxAgeIgnore       Exclude from the listing files that are older (in minutes).
  -b, --minSizeAlert       Flag files that are smaller than this size (in kilobytes).
  -B, --minSizeIgnore      Exclude from the listing files that are smaller (in kilobytes).
  -k, --maxSizeAlert       Flag files that are larger than this size (in kilobytes).
  -K, --maxSizeIgnore      Exclude from the listing files that are larger (in kilobytes).
  -0, --zeroByteAlert      Flag files that are 0 bytes.
  -H, --suppressHeading    Do not show the listing heading block
  -O, --showOptions        Show the command line options used as criteria for this
                           listing as part of the listing heading block
  -P, --plainText          Output contains no color or decoration escape codes.
  -s, --mailSubject        The subject line for emailed output.
                           ('Watchfiles Report' is the default.)
  -f, --mailFrom           The address an emailed report should be sent from.
  -d, --mailDistribution   The distribution list of comma separated addresses the
                           email should be sent to.
  -e, --mailSuppressEmpty  An email will not be sent if the set criteria did not
                           result in any files being listed.
  -S, --mailEmptySubject   The subject line of the email if no files are listed.
  -v, --version            Show script version
  -T, --title              Adds a title line at the top of the output
```

## Use Cases

It is all well and good to see the options, but what combination(s) solve which problems. What follows are a few use cases that I have found to be useful.

### Folder Monitoring...

Let us say that people are dropping files in a folder to be moved with the following considerations:

* The files may be large so it may take some time for a file to be completely transferred.
* The process that picks up the files is polling the target folder once every 5 minutes.
* Files older than 7 days old need special attention.
* Files older than 30 days can be ignored.
* Alert when files are 0 bytes

That command line might look like this:

```bash
./watchfiles.sh --target /mnt/d/Downloads/ --minAgeIgnore 5 --maxAgeAlert 10080 --maxAgeIgnore 43200 -0 --showOptions
```

![image](https://user-images.githubusercontent.com/5069920/172442417-1ba0e2f3-6de7-4e76-8f5d-ade363c76120.png)

#### ...As "Live" Dashboard

Running the script one time is useful enough if you just want a snapshot. However, if you are looking to keep a constant eye on things, you may want something that runs continually. You could run the script repeatedly in a loop, but that gets pretty jumpy with either constant scrolling or the entire terminal blinking if you decide to *clear* it between runs.

This use case is not built intrinsically into the script, but there are script options to make this case a little nicer to work with.

The magic is in the [watch](https://en.wikipedia.org/wiki/Watch_(command)) command.

Maybe you want to monitor your temp folder and make sure that things are being cleaned out. Or you just want to see what goes on in that folder when you aren't looking. You might try this:

```bash
watch --color ./watchfiles.sh --target "/mnt/c/temp/" --maxAgeAlert 10080 --title "Temporary" --suppressHeading
```
![image](https://user-images.githubusercontent.com/5069920/172448534-0c8bd39a-e2d9-4809-b37a-1f1d416f5d85.png)

In this instance, we are suppressing the heading, adding a title and keeping things minimal. Every two (2) seconds the display updates with the current output of the script. If someone were to delete the file the display would quickly update to reflect the new reality.

![image](https://user-images.githubusercontent.com/5069920/172448960-65a3a837-509f-4774-ac48-ab06af8c81e8.png)

#### ...As An Emailed Report

Maybe you do not need the near-live monitoring. Perhaps a check several times a day with an email sent each time, but with subject lines that reflect a status.

**NOTE:** Emails require that _mail_ be installed and configured. Which is out of scope for this document.

You might create a cron job that calls the following:

```bash
./watchfiles.sh --target /temp --minAgeIgnore 5 --showOptions --zeroByteAlert --mailSubject "Temp Folder Requires Cleaning!" --mailEmptySubject "Temp Folder ALL CLEAR!" --mailFrom yourmail@yourdomain.com --mailDistribution admin1@yourdomain.com,admin2@yourdomain.com
```

## Conclusion

One could monitor for log files growing excessively large. Or lingering "lock" files. While the options are not limitless, there is some reasonable flexibility here. And as new use cases crop up, I (or someone) will add to the script.
