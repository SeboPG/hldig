#!/opt/local/bin/perl
#!/usr/bin/perl -w
use strict;
#
# Version 3.1         17-January-2005
#
# External converter for htdig 3.1.4 or later (Perl5 or later)
# Usage: (in htdig.conf)
#
#external_parsers:	application/rtf->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			text/rtf->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/pdf->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/postscript->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/msword->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/wordperfect5.1->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/wordperfect6.0->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/msexcel->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/vnd.ms-excel->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/powerpoint->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/vnd.ms-powerpoint->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/x-shockwave-flash->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl \
#			application/x-shockwave-flash2-preview->text/html /opt/local/htdig-3.1.6/scripts/doc2html.pl
#
#  Uses wp2html to convert Word and WordPerfect documents into HTML, and
#  falls back to using Catdoc for Word and Catwpd for WordPerfect if 
#  Wp2html is unavailable or unable to convert.
#
#  Uses range of other converters as available.
#
#  If all else fails, attempts to read file without conversion.
#
########################################################################################
# Written by David Adams <d.j.adams@soton.ac.uk>.
# Based on conv_doc.pl written by Gilles Detillieux <grdetil@scrc.umanitoba.ca>,
#   which in turn was based on the parse_word_doc.pl script, written by
#   Jesse op den Brouw <MSQL_User@st.hhs.nl>.
########################################################################################

# Install Sys::AlarmCall if you can
eval "use Sys::AlarmCall";

########  Full paths to conversion utilities  ##########
########          YOU MUST SET THESE          ##########
########  (set to undef those you don't have) ##########

# Wp2html converts Word & Wordperfect to HTML
# (get it from: http://www.res.bbsrc.ac.uk/wp2html/)
my $WP2HTML = '';

#Catwpd for WordPerfect to text conversion
# (you don't need this if you have wp2html)
# (get catwpd.c from http://htdig.org.contrib/)
my $CATWPD = '';

# rtf2html converts Rich Text Font documents to HTML
# (get it from http://www.45.free.net/~vitus/ice/catdoc/
#  it is bundled in with catdoc)
my $RTF2HTML = '';

# Catdoc converts Word (MicroSoft) to plain text
# (get it from: http://www.45.free.net/~vitus/ice/catdoc/)

#version of catdoc for Word6, Word7 & Word97 files:
my $CATDOC = '';

#version of catdoc for Word2 files:
my $CATDOC2 = $CATDOC;

#version of catdoc for Word 5.1 for MAC:
my $CATDOCM = $CATDOC;

# PostScript to text converter
# (get it from the ghostscript 3.33 (or later) package)
my $CATPS = "/usr/bin/ps2ascii";

# add to search path the directory which contains gs:
#$ENV{PATH} .= ":/usr/freeware/bin";

# PDF to HTML conversion script:
my $PDF2HTML = '';

# Excel (MicroSoft) to HTML converter
# (get it from http://chicago.sourceforge.net/xlhtml/)
my $XLS2HTML = '';

# Excel (MicroSoft) to .CSV converter
# (you don't need this if you have xlhtml)
# (if you do want it, you can get it with catdoc)
my $CATXLS = '';

# Powerpoint (MicroSoft) to HTML converter
# (get it from http://chicago.sourceforge.net/xlhtml/
#  it is bundled in with xlhtml)
my $PPT2HTML = '';

# Shockwave Flash 
# (extracts links from file)
my $SWF2HTML = '';

# Flash MX 
# (extracts links from file)
my $FMX2HTML = '';

########################################################################

# Other Global Variables
my ($Success, $LOG, $Verbose, $CORE_MESS, $TMP, $RM, $ED, $Magic, $Time,
    $Count, $Prog, $Input, $MIME_type, $URL, $Name, $Efile, $Maxerr, 
    $Redir, $Emark, $EEmark, $Method, $OP_Limit, $IP_Limit);
my (%HTML_Method, %TEXT_Method, %BAD_type);


&init;			# initialise

my $size = -s $Input;
if ($size >= $IP_Limit) {
  &dummy_out($MIME_type);
  &quit("Input file size of $size at or above $IP_Limit limit");
}

&store_methods;		# 
&read_magic;		# Magic reveals type
&error_setup;		# re-route standard error o/p from utilities

# see if a document -> HTML converter will work:
&run('&try_html');
if ($Success) { &quit(0) }

# try a document -> text converter:
&run('&try_text');
if ($Success) { &quit(0) }

# see if a known problem
my $fail = &cannot_do;
if ($fail) { &quit($fail) }

# last-ditch attempt, try copying document
&try_plain;
if ($Success) {&quit(0)}

&quit("UNABLE to convert");

#------------------------------------------------------------------------------

sub init {

  # Doc2html log file
  $LOG = $ENV{'DOC2HTML_LOG'} || '';
  #
  if ($LOG) {
    open(STDERR,">>$LOG"); # ignore possible failure to open
  } # else O/P really does go to STDERR

  # Set to 1 for O/P to STDERR or Log file
  $Verbose = exists($ENV{'DOC2HTML_LOG'}) ? 1 : 0;

  # Limiting size of file doc2html.pl will try to process (default 20Mbyte)
  $IP_Limit = $ENV{'DOC2HTML_IP_LIMIT'} || 20000000; 

  # Limit for O/P returned to htdig (default 10Mbyte)
  $OP_Limit = $ENV{'DOC2HTML_OP_LIMIT'} || 10000000; 

  # Mark error message produced within doc2html script
  $Emark = "!\t";
  # Mark error message produced by conversion utility
  $EEmark = "!!\t";

  # Message to STDERR if core dump detected
  $CORE_MESS = "CORE DUMPED";

  # Directory for temporary files
  $TMP = "/tmp/htdig";
  if (! -d $TMP) {
    mkdir($TMP,0700) or die "Unable to create directory \"$TMP\": $!";
  }
  # Current directory during run of script:
  chdir $TMP or warn "Cannot change directory to $TMP\n";

  # File for error output from utility
  $Efile = 'doc_err.' . $$;

  # Max. number of lines of error output from utility copied
  $Maxerr = 10;

  # System command to delete a file
  $RM = "/bin/rm -f";

  # Line editor to do substitution
  $ED = "/bin/sed -e"; 
  if ($^O eq "MSWin32") {$ED = "$^X -pe"}

  $Time = 60;	# allow 60 seconds for external utility to complete

  $Success = 0;
  $Count = 0;
  $Method = '';
  $Prog = $0;
  $Prog =~ s#^.*/##; 
  $Prog =~ s/\..*?$//;

  $Input = $ARGV[0] or die "No filename given\n";
  $MIME_type = $ARGV[1] or die "No MIME-type given";
  $URL = $ARGV[2] || '?';
  $Name = $URL;
  $Name =~ s#^.*/##;
  $Name =~ s/%([A-F0-9][A-F0-9])/pack("C", hex($1))/gie;
  
  if ($Verbose and not $LOG) { print STDERR "\n$Prog: [$MIME_type] " }
  if ($LOG) { print STDERR "$URL [$MIME_type] " }

}

#------------------------------------------------------------------------------

sub store_methods {
#	The method of dealing with each file type is set up here.
#	Edit as necessary

  my ($mime_type,$magic,$cmd,$cmdl,$type,$description);

  my $name = quotemeta($Name);

  ####Document -> HTML converters####

  # WordPerfect documents
  if ($WP2HTML) {
    $mime_type = "application/wordperfect|application/msword";
    $cmd = $WP2HTML;
    $cmdl = "($cmd -q -DTitle=\"[$name]\" -c doc2html.cfg -s doc2html.sty -i $Input -O; $RM CmdLine.ovr)";
    $magic = '\377WPC';
    &store_html_method('WordPerfect (wp2html)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Word documents
  if ($WP2HTML) {
    $mime_type = "application/msword";
    $cmd = $WP2HTML;
    $cmdl = "($cmd -q -DTitle=\"[$name]\" -c doc2html.cfg -s doc2html.sty -i $Input -O; $RM CmdLine.ovr)";
    $magic = '^\320\317\021\340';
    &store_html_method('Word (wp2html)',$cmd,$cmdl,$mime_type,$magic);
  }

  # RTF documents
  if ($RTF2HTML) {
    $mime_type = "application/msword|application/rtf|text/rtf";
    $cmd = $RTF2HTML;
    # Rtf2html uses filename as title, change this:
    $cmdl = "$cmd $Input | $ED \"s#^<TITLE>$Input</TITLE>#<TITLE>[$name]</TITLE>#\"";
    $magic = '^{\134rtf';
    &store_html_method('RTF (rtf2html)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Microsoft Excel spreadsheet
  if ($XLS2HTML) {
    $mime_type = "application/msexcel|application/vnd.ms-excel";
    $cmd = $XLS2HTML;
    # xlHtml uses filename as title, change this:
    $cmdl = "$cmd -fw $Input | $ED \"s#<TITLE>$Input</TITLE>#<TITLE>[$name]</TITLE>#\"";
    $magic = '^\320\317\021\340';
    &store_html_method('Excel (xlHtml)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Microsoft Powerpoint Presentation
  if ($PPT2HTML) {
    $mime_type = "application/vnd.ms-powerpoint|application/powerpoint";
    $cmd = $PPT2HTML;
    # xlHtml uses filename as title, change this:
    $cmdl = "$cmd $Input | $ED \"s#<TITLE>$Input</TITLE>#<TITLE>[$name]</TITLE>#\"";
    $magic = '^\320\317\021\340';
    &store_html_method('Powerpoint (pptHtml)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Adobe PDF file using Perl script
  if ($PDF2HTML) {
    $mime_type = "application/pdf";
    $cmd = $PDF2HTML;
    # Replace default title (if used) with filename:
    $cmdl = "$cmd $Input $mime_type $name";
    $magic = '%PDF-|\0PDF CARO\001\000\377';
    &store_html_method('PDF (pdf2html)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Shockwave Flash file using Perl script
  if ($SWF2HTML) {
    $mime_type = "application/x-shockwave-flash";
    $cmd = $SWF2HTML;
    $cmdl = "$cmd $Input";
    $magic = '^FWS[\001-\005]'; # versions 1 to 5, perhaps some later versions
    &store_html_method('Shockwave-Flash (swf2html)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Flash MX file using Perl script
  if ($FMX2HTML) {
    $mime_type = "application/x-shockwave-flash";
    $cmd = $FMX2HTML;
    $cmdl = "$cmd $Input $mime_type $name";
    $magic = '^[CF]WS[\006-\010]'; # Flash file version 6 and later
    &store_html_method('Flash MX (fmx2html)',$cmd,$cmdl,$mime_type,$magic);
  }

  ####Document -> Text converters####

  # Word6, Word7 & Word97 documents
  if ($CATDOC) {
    $mime_type = "application/msword";
    $cmd = $CATDOC;
    # -b option increases chance of success:
    $cmdl = "$cmd -a -b -w $Input";
    $magic = '^\320\317\021\340';
    &store_text_method('Word (catdoc)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Word2 documents
  if ($CATDOC2) {
    $mime_type = "application/msword";
    $cmd = $CATDOC2;
    $cmdl = "$cmd -a -b -w $Input";
    $magic = '^\333\245-\000';
    &store_text_method('Word2 (catdoc)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Word 5.1 for MAC documents
  if ($CATDOCM) {
    $mime_type = "application/msword";
    $cmd = $CATDOCM;
    $cmdl = "$cmd -a -b -w $Input";
    $magic = '^\3767\000#\000\000\000\000';
    &store_text_method('MACWord (catdoc)',$cmd,$cmdl,$mime_type,$magic);
  }

  # PostScript files
  if ($CATPS) {
    $mime_type = "application/postscript";
    $cmd = $CATPS;
    # allow PS interpreter to give error messages
    $cmdl = "($cmd; $RM _temp_.???) < $Input";
    $magic = '^.{0,20}?%!|^\033%-12345.*\n%!';
    &store_text_method('PostScript (ps2ascii)',$cmd,$cmdl,$mime_type,$magic);
  }

  # Microsoft Excel file
  if ($CATXLS) {
    $mime_type = "application/vnd.ms-excel";
    $cmd = $CATXLS;
    $cmdl = "$cmd $Input";
    $magic = '^\320\317\021\340';
    &store_text_method('MS Excel (xls2csv)',$cmd,$cmdl,$mime_type,$magic);
  }

  # WordPerfect document
  if ($CATWPD) {
    $mime_type = "application/wordperfect|application/msword";
    $cmd = $CATWPD;
    $cmdl = "$cmd $Input";
    $magic = '\377WPC';
    &store_text_method('WordPerfect (catwpd)',$cmd,$cmdl,$mime_type,$magic);
  }

  ####Documents that cannot be converted####

  # wrapped encapsulated Postscript
  $type = "EPS";
  $magic = '^\305\320\323\306 \0';
  $description = 'wrapped Encapsulated Postscript';
  &store_cannot_do($type,$magic,$description);

  ## Shockwave Flash version 6
  #$type = "SWF6";
  #$description = 'Shockwave-Flash Version 6';
  #$magic = '^CWS\006';
  #&store_cannot_do($type,$magic,$description);

  ## Binary (data or whatever)
  #$type = "BIN";
  #$magic = '[\000-\007\016-\037\177]'; # rather crude test!
  #$description = 'apparently binary';
  #&store_cannot_do($type,$magic,$description);

  return;
}

#------------------------------------------------------------------------------

sub read_magic {

  # Read first bytes of file to check for file type
  open(FILE, "< $Input") || die "Can't open file $Input\n";
  read FILE,$Magic,256;
  close FILE;

  return;
}

#------------------------------------------------------------------------------

sub error_setup {

  if ($Efile) {
   open SAVERR, ">&STDERR";
   if (open STDERR, "> $Efile") {
     print SAVERR " Overwriting $Efile\n" if (-s $Efile);
     $Redir = 1;
   } else { close SAVERR }
  }

}

#------------------------------------------------------------------------------

sub run {

  my $routine = shift;
  my $return;

  if (defined &alarm_call) {
    $return = alarm_call($Time, $routine);
  } else {
    eval $routine;
    $return = $@ if $@;
  }

  if ($return) { &quit($return) }

}

#------------------------------------------------------------------------------

sub try_html  {

  my($set,$cmnd,$type);

  $Success = 0;
  foreach $type (keys %HTML_Method) {
    $set = $HTML_Method{$type};
    if (($MIME_type =~ m/$set->{'mime'}/i) and  
        ($Magic =~ m/$set->{'magic'}/s))     { # found the method to use
      $Method = $type;
      my $cmnd = $set->{'cmnd'};
      if (! -x $cmnd) {
	warn "Unable to execute $cmnd for $type document\n";
	return;
      }
      if (not open(CAT, "$set->{'command'} |")) {
	warn "$cmnd doesn't want to be opened using pipe\n";
	return;
      }
      while (<CAT>) {
	# getting something, so it is working
	$Success = 1;
        if ($_ !~ m/^<!--/) { # skip comment lines inserted by converter
	  print;
	  $Count += length;
	  if ($Count > $OP_Limit) { last }
        }
      }
      close CAT;
      last;
    } 
  }
  return;
}

#------------------------------------------------------------------------------

sub try_text  {

  my($set,$cmnd,$type);

  $Success = 0;
  foreach $type (keys %TEXT_Method) {
    $set = $TEXT_Method{$type};
    if (($MIME_type =~ m/$set->{'mime'}/i) and
        ($Magic =~ m/$set->{'magic'}/s))     { # found the method to use
      $Method = $type;
      my $cmnd = $set->{'cmnd'};
      if (! -x $cmnd) { die "Unable to execute $cmnd for $type document\n" }

      # Open file via selected converter, output head, then its text:
      open(CAT, "$set->{'command'} |") or
	  die "$cmnd doesn't want to be opened using pipe\n";
      &head;
      print "<BODY>\n<PRE>\n";
      $Success = 1;
      while (<CAT>) {
	s/\255/-/g;	# replace dashes with hyphens
	# replace bell, backspace, tab. etc. with single space:
	s/[\000-\040]+/ /g;
	if (length > 1) { # if not just a single character, eg space
	  print &HTML($_), "\n";
	  $Count += length;
	  if ($Count > $OP_Limit) { last }
	}
      }
      close CAT;

      print "</PRE>\n</BODY>\n</HTML>\n";
      last;
    }

  }

  return;
}

#------------------------------------------------------------------------------

sub cannot_do  {

  my ($type,$set);

  # see if known, unconvertable type
  $Method = '';
  foreach $type (keys %BAD_type) {
    $set = $BAD_type{$type};
    if ($Magic =~ m/$set->{'magic'}/s) { # known problem
      return  "CANNOT DO $set->{'desc'} ";
    }
  }

  return 0;
}

#------------------------------------------------------------------------------

sub try_plain  {

  $Success = 0;
  ####### if ($Magic !~ m/^[\000-\007\016-\037\177]) {
  if (-T $Input) { # Looks like text, so go for it:
      $Method = 'Plain Text';
      open(FILE, "<$Input") || die "Error reading $Input\n";
      $Success = 1;
      $Method = 'Plain Text';
      &head;
      print "<BODY>\n<PRE>\n";

      while (<FILE>) {
	# replace bell, backspace, tab. etc. with single space:
	s/[\000-\040\177]+/ /g;
        if (length > 1) {
	  print &HTML($_), "\n";
	  $Count += length;
	  if ($Count > $OP_Limit) { last }
	}
      }
      close FILE;
      print "</PRE>\n</BODY>\n</HTML>\n";

  } else { $Method = '' }

  return;
}

#------------------------------------------------------------------------------

sub dummy_out {

  my $text = shift;
  &head;
  print "<BODY>\n<H6>", $text, "</H6>\n</BODY>\n</HTML>\n";
  return;
}

#------------------------------------------------------------------------------

sub HTML {

  my $text = shift;

  $text =~ s/\f/\n/gs;	# replace form feed
  $text =~ s/\s+/ /g;	# replace multiple spaces, etc. with a single space
  $text =~ s/\s+$//gm;	# remove trailing spaces
  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;

  return &link_text($text);
}

#------------------------------------------------------------------------------  

sub link_text ($) { # look for URLs in text and make them into links

  my $text = ' ' . $_[0] . ' ';
  $text =~ s#([\s({[<|])(https{0,1}://\S{4,}?)(\.*[\s)}\]>;:,])#$1<a href="$2">$2</a>$3#gs;
  $text =~ s#([\s({[<|])(ftp://\S{4,}?)(\.*[\s)};:,\]>|])#$1<a href="$2">$2</a>$3#gs;
  $text =~ s#([\s({[<|])(www\.\S{3,}?)(\.*[\s)};:,\]>|])#$1<a href="http://$2">$2</a>$3#gs;
##  $text =~ s#([\s({[<|])(\S+@\S{2,}?)(\.*[\s)};:,\]>|])#$1<a href="mailto:$2">$2</a>$3 #gs;
  $text =~ s/^ //; $text =~ s/ $//;

  return $text;
}

#------------------------------------------------------------------------------

sub store_html_method {

  my $type = shift;
  my $cmnd = shift;
  my $cline = shift;
  my $mime = shift;
  my $magic = shift;

  $HTML_Method{$type} = {
    'mime'	=> $mime,
    'magic'	=> $magic,
    'cmnd'	=> $cmnd,
    'command'	=> $cline,
    };

  return;
}

#------------------------------------------------------------------------------

sub store_text_method {

  my $type = shift;
  my $cmnd = shift;
  my $cline = shift;
  my $mime = shift;
  my $magic = shift;

  $TEXT_Method{$type} = {
    'mime'	=> $mime,
    'magic'	=> $magic,
    'cmnd'	=> $cmnd,
    'command'	=> $cline,
    };

  return;
}

#------------------------------------------------------------------------------

sub store_cannot_do {

  my $type = shift;
  my $magic = shift;
  my $desc = shift;

  $BAD_type{$type} = { 
    'magic' => $magic,
    'desc' => $desc,
    };

  return;

}

#------------------------------------------------------------------------------

sub head {

      print "<HTML>\n<HEAD>\n";
      print "<TITLE>[" . $Name . "]</TITLE>\n";
      print "</HEAD>\n";

}

#------------------------------------------------------------------------------

sub quit {

  if ($Redir) {	# end redirection of STDERR to temporary file
   close STDERR;
   open STDERR, ">&SAVERR";
  }    

  if ($Verbose) {
    print STDERR "$Method $Count" if ($Success);
    print STDERR "\n";
  } 

  if ($Count > $OP_Limit) {
    print STDERR $Emark, "Output truncated after limit $OP_Limit reached\n";
  }
 
  my $return = shift;  
  if ($return) {
    print STDERR $Emark, $return, "\n";
    $return = 1;
  }

  chdir $TMP;
  if ($Efile && -s $Efile) {
    open EFILE, "<$Efile";
    my $c = 0;
    while (<EFILE>) {
      $c++;
      if ($c <= $Maxerr) {
        print STDERR $EEmark, $_;
      }
    }
    close EFILE;
    print STDERR $Emark, " ... (total of $c lines of error messages)\n" if ($c > $Maxerr);
  }
  unlink $Efile if ($Efile && -e $Efile);

  if (-e "core" && (-M "core" < 0)) {
    print STDERR $Emark, "$CORE_MESS\n";
  }
  exit $return;
}
