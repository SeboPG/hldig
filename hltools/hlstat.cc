//
// htstat.cc
//
// htstat: A utility to give statistics on the contents of the word and doc DB.
//
// Part of the ht://Dig package   <http://www.htdig.org/>
// Copyright (c) 1999-2004 The ht://Dig Group
// For copyright details, see the file COPYING in your distribution
// or the GNU Library General Public License (LGPL) version 2 or later
// <http://www.gnu.org/copyleft/lgpl.html>
//
// $Id: htstat.cc,v 1.6 2004/05/28 13:15:25 lha Exp $
//
#ifdef HAVE_CONFIG_H
#include "hlconfig.h"
#endif /* HAVE_CONFIG_H */

#include "WordContext.h"
#include "HtURLCodec.h"
#include "HtWordList.h"
#include "HtConfiguration.h"
#include "DocumentDB.h"
#include "defaults.h"
#include "messages.h"

#include <errno.h>

#ifndef _MSC_VER                /* _WIN32 */
#include <unistd.h>
#endif

// If we have this, we probably want it.
#ifdef HAVE_GETOPT_H
#include <getopt.h>
#elif HAVE_GETOPT_LOCAL
#include <getopt_local.h>
#endif

int verbose = 0;

void usage ();
void reportError (char *msg);

//*****************************************************************************
// int main(int ac, char **av)
//
int
main (int ac, char **av)
{
  int alt_work_area = 0;
  int url_list = 0;
  String configfile = DEFAULT_CONFIG_FILE;
  int c;
  extern char *optarg;

  while ((c = getopt (ac, av, "vc:au")) != -1)
  {
    switch (c)
    {
    case 'c':
      configfile = optarg;
      break;
    case 'v':
      verbose++;
      break;
    case 'a':
      alt_work_area++;
      break;
    case 'u':
      url_list++;
      break;
    case '?':
      usage ();
      break;
    }
  }

  HtConfiguration *config = HtConfiguration::config ();
  config->Defaults (&defaults[0]);

  if (access ((char *) configfile, R_OK) < 0)
  {
    reportError (form (_("Unable to find configuration file '%s'"),
                       configfile.get ()));
  }

  config->Read (configfile);

  //
  // Check url_part_aliases and common_url_parts for
  // errors.
  String url_part_errors = HtURLCodec::instance ()->ErrMsg ();

  if (url_part_errors.length () != 0)
    reportError (form (_("Invalid url_part_aliases or common_url_parts: %s"),
                       url_part_errors.get ()));


  // We may need these through the methods we call
  if (alt_work_area != 0)
  {
    String configValue;

    configValue = config->Find ("word_db");
    if (configValue.length () != 0)
    {
      configValue << ".work";
      config->Add ("word_db", configValue);
    }

    configValue = config->Find ("doc_db");
    if (configValue.length () != 0)
    {
      configValue << ".work";
      config->Add ("doc_db", configValue);
    }

    configValue = config->Find ("doc_index");
    if (configValue.length () != 0)
    {
      configValue << ".work";
      config->Add ("doc_index", configValue);
    }

    configValue = config->Find ("doc_excerpt");
    if (configValue.length () != 0)
    {
      configValue << ".work";
      config->Add ("doc_excerpt", configValue);
    }
  }

  DocumentDB docs;
  if (docs.Read (config->Find ("doc_db"), config->Find ("doc_index"),
                 config->Find ("doc_excerpt")) == OK)
  {
    List *urls = docs.URLs ();
    cout << _("hlstat: Total documents: ") << urls->Count () << endl;
    if (url_list)
    {
      // Spit out the list of URLs too
      String *url;

      cout << _("hlstat: URLs in database: ") << endl;
      urls->Start_Get ();
      while ((url = (String *) urls->Get_Next ()))
      {
        cout << "\t" << url->get () << endl;
      }
    }

    delete urls;
    docs.Close ();
  }

  // Initialize htword
  WordContext::Initialize (*config);

  HtWordList words (*config);
  if (words.Open (config->Find ("word_db"), O_RDONLY) == OK)
  {
    cout << _("hlstat: Total words: ") << words.WordRefs ()->Count () << endl;
    cout << _("hlstat: Total unique words: ") << words.Words ()->
      Count () << endl;
    words.Close ();
  }

  return 0;
}


//*****************************************************************************
// void usage()
//   Display program usage information
//
void
usage ()
{
  Usage help;
  cout << _("usage:");
  cout << " hlstat [-v][-a][-c configfile][-u]\n";
  printf (_("This program is part of hl://Dig %s\n\n"), VERSION);
  cout << _("Options:\n");
  help.verbose ();
  help.alternate_common ();
  cout << "\t\tTells hlstat to append .work to the database files \n";
  cout << "\t\tallowing it to operate on a second set of databases.\n";
  help.config ();
  cout << "\t-u\tGive a list of URLs in the document database.\n\n";
  exit (0);
}


//*****************************************************************************
// Report an error and die
//
void
reportError (char *msg)
{
  cout << "hlstat: " << msg << "\n\n";
  exit (1);
}
