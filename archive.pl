#!/usr/bin/perl -w

package Archiver;

$PUBLIC_ARCHIVE_DIR = "/var/lib/mailman/archives/public";
$PUBLIC_RCFILE = "/home/admin/mhonarc/public-rc/base.rc";
$PRIVATE_ARCHIVE_DIR = "/var/lib/mailman/archives/private";
$PRIVATE_RCFILE = "/home/admin/mhonarc/private-rc/base.rc";

use Date::Parse qw(str2time);
use Mail::Field;
use Mail::Internet;
use POSIX qw(strftime tmpnam);
use IO::File;

sub new {
  my ($pkg, %options) = @_;

  my $self = bless {}, $pkg;

  die "Must specify listname" unless exists $options{listname};
  $self->{listname} = $options{listname};

  $self->{private} = exists $options{private} ? $options{private} : 0;

  $self->{debug} = exists $options{debug} ? $options{debug} : 0;

  $self->{olddir} = undef;
  my $tmpname = $self->{tmpname} = tmpnam();

  $self->{tmpfile} = new IO::File;
  if (!$self->{tmpfile}->open ("$tmpname", O_WRONLY|O_CREAT|O_EXCL, 0700))
    {
      die "Cannot open temporary file $tmpname: $!\n";
    }

  $self;
}

sub output {
  my ($self, $last) = @_;
  
  my $tmpname = $self->{tmpname};

  my $dir = $PRIVATE_ARCHIVE_DIR;
  $dir .= "/$self->{listname}/$self->{olddir}";

  $self->{tmpfile}->close;

  if (!-d $dir) {
    use File::Path qw(mkpath);
    mkpath $dir, 0, 0755;
  }

  $rcfile = $self->{private} ? $PRIVATE_RCFILE : $PUBLIC_RCFILE;

  system (<<EOT);
mhonarc -umask 022 -rcfile $rcfile -add -outdir $dir $tmpname -definevar "ARCHDATE=$self->{olddir} LISTNAME=$self->{listname}" >> /var/log/mailman/archive 2>&1 
EOT

  if (-f "$dir.txt") {
     system ("cat < $tmpname >> $dir.txt");
  } else {
     system ("gzip -c < $tmpname >> $dir.txt.gz");
  }

  if ($last) {
    unlink $tmpname;
    make_index ($self->{listname}, $self->{private});

    if (!$self->{private} &&
	!-l "$PUBLIC_ARCHIVE_DIR/$self->{listname}") {

	if (!-d $PUBLIC_ARCHIVE_DIR) {
	    use File::Path qw(mkpath);
	    mkpath $PUBLIC_ARCHIVE_DIR, 0, 0755;
	}

	symlink "$PRIVATE_ARCHIVE_DIR/$self->{listname}", "$PUBLIC_ARCHIVE_DIR/$self->{listname}" 
    }
	
    
  } else {
    if (!$self->{tmpfile}->open ("$tmpname", O_WRONLY|O_TRUNC))
      {
	die "Cannot open temporary file $tmpname: $!\n";
      }
  }
}

sub handle_msg {
  my ($self, $msg_lines, $msg_text) = @_;

  my $msg = new Mail::Internet ( $msg_lines );

  my $received_count = $msg->head()->count ("Received");
  $received_text1 = $received_count >= 1 ? $msg->head()->get ("Received", 0) : undef;
  $received_text2 = $received_count >= 2 ? $msg->head()->get ("Received", 1) : undef;
  $received_text3 = $received_count >= 3 ? $msg->head()->get ("Received", 2) : undef;

  my $time;

  if (defined $received_text1) {
    $received = Mail::Field->new('Received', $received_text1);
    if ($received->parsed_ok ()) {
      my $parse_tree = $received->parse_tree();
      $time = str2time ($parse_tree->{date_time}->{whole});
      if(defined($time)) {
        $self->{last_time} = $time;
        $self->{last_parsable_time} = $received1_text;
      }
    }
    elsif (defined($received_text2)) {
      $received = Mail::Field->new('Received', $received_text2);
      if ($received->parsed_ok ()) {
        my $parse_tree = $received->parse_tree();
        $time = str2time ($parse_tree->{date_time}->{whole});
        if(defined($time)) {
          $self->{last_time} = $time;
          $self->{last_parsable_time} = $received1_text;
        }
      }
      elsif (defined($received_text3)) {
        $received = Mail::Field->new('Received', $received_text3);
        if ($received->parsed_ok ()) {
          my $parse_tree = $received->parse_tree();
          $time = str2time ($parse_tree->{date_time}->{whole});
          if(defined($time)) {
            $self->{last_time} = $time;
            $self->{last_parsable_time} = $received1_text;
          }
        }
      }
    }
    else {
      if($self->{debug}) {
        print STDERR "Failed parsing first three Received headers.\n";
      }
    }
  }
  if(defined($time)) {
    if(defined($self->{start_time})) {
      return if($self->{start_time} > 0 && $time < $self->{start_time});
    }
    if(defined($self->{end_time})) {
      return if($self->{end_time} > 0 && $time > $self->{end_time});
    }
    
    $dir = strftime ("%Y-%B", gmtime ($time));
    if (defined $self->{olddir} && $self->{olddir} ne $dir)
    {
	  $self->output (0);
    }
    
    $self->{olddir} = $dir;
    $self->{last_time} = $time;
    $self->{last_parsable_time} = $received1_text;
  }
  else {
    if($self->{debug}) {
      if(defined($received1_text)) {
        print "Couldn't parse 'Received: ".$received1_text."'\n";
      }
      else {
        print "No 'Received' header found.\n";
      }
      if(defined($self->{last_time})) {
        print "Last parsable time was ".strftime("%Y-%B-%m", gmtime($self->{last_time}))."\n";
      }
    }
  }
  
  $self->{tmpfile}->print($msg_text);
}

my %months =
(
 january => 1,
 february => 2,
 march => 3,
 april => 4,
 may => 5,
 june => 6,
 july => 7,
 august => 8,
 september => 9,
 october => 10,
 november => 11,
 december => 12
);

sub make_index {
  my ($listname, $private) = @_;
  
  my $dirname = $PRIVATE_ARCHIVE_DIR . "/$listname";
  
  opendir DH, "$dirname" || die "Cannot open $dirname for indexing: $!\n";

  my %dirs;
  while (defined ($dir = readdir DH))
    {
      my ($y,$m) = $dir =~ /^(\d+)-(\w+)$/;
      if (defined ($y)) {
	$dirs{$y * 100 + $months{lc($m)}} = $dir;
      }
    }
  
  close DH;

  open INDEX, "> $dirname/index.html" || die "Cannot open index $dirname/index.html: $!\n";

  print INDEX <<EOT;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <link href="/css/layout.css" rel="stylesheet" type="text/css" media="screen">
  <link href="/css/style.css" rel="stylesheet" type="text/css" media="all">
  <link rel="icon" type="image/png" href="http://www.gnome.org/img/logo/foot-16.png">
  <link rel="SHORTCUT ICON" type="image/png" href="http://www.gnome.org/img/logo/foot-16.png">
  <title>The $listname Archives</title>
</head>

<body>
  <!-- site header -->
  <div id="page">
    <ul id="general">
      <li id="siteaction-gnome_home" class="home">
        <a href="http://www.gnome.org/" title="Home">Home</a>
      </li>
      <li id="siteaction-gnome_news">
        <a href="http://news.gnome.org" title="News">News</a>
      </li>
      <li id="siteaction-gnome_projects">
        <a href="http://www.gnome.org/projects/" title="Projects">Projects</a>
      </li>
      <li id="siteaction-gnome_art">
        <a href="http://art.gnome.org" title="Art">Art</a>
      </li>
      <li id="siteaction-gnome_support">
        <a href="http://www.gnome.org/support/" title="Support">Support</a>
      </li>
      <li id="siteaction-gnome_development">
        <a href="http://developer.gnome.org" title="Development">Development</a>
      </li>
      <li id="siteaction-gnome_community">
        <a href="http://www.gnome.org/community/" title="Community">Community</a>
      </li>
    </ul>
    <div id="header">
      <h1>The $listname Archives </h1>
      <div id="control">
      <div id="search">
        <form method="get" action="http://www.google.com/custom">
          <input type="text" name="q" maxlength="255" size="15" class="searchTerms">
          <input type="hidden" name="domains" value="mail.gnome.org">
          <select name="hq">
            <option value="inurl:/archives/$listname/">This mailing list</option>
            <option value="inurl:/archives/">All mailing lists</option>
          </select>
          <input type="hidden" name="sitesearch" value="mail.gnome.org">
          <input type="submit" class="searchButton" value="Search">
        </form>
      </div>
      </div>
      <div id="tabs">
        <ul id="portal-globalnav">
          <li id="portaltab-root">
            <a href="/"><span>Home</span></a>
          </li>
          <li><a href="/mailman/listinfo"><span>Mailing lists</span></a></li>
          <li class="selected"><a href="/archives"><span>List archives</span></a></li>
        </ul>
      </div> <!-- end of #tabs -->
    </div> <!-- end of #header -->
  </div>
<!-- end site header -->

  <div class="body">
     <p>
      <a href="http://mail.gnome.org/mailman/listinfo/$listname">More info on this list...</a>
     </p>
EOT
   
    if ($private) {
	print INDEX <<EOT;
<form method="get" action="/mailman/private/$listname/search">
<p>
Search:
<input type="text" name="query" size="40">
<input type="submit" name="submit" value="Search!">
<a href="/mailman/private/$listname/search">[More...]</a>
</p>
</form>
EOT
   }

  print INDEX <<EOT; 
        <table border=3>
          <tr><td>Archive</td>
          <td>View by:</td>
          <td>Downloadable version</td></tr>
EOT

  for $key (reverse sort keys %dirs) {
    $date = $dirs{$key};

    my ($mboxfile,$mboxtype,$mboxsize);
    
    if (-f "$dirname/$date.txt.gz") {
      $mboxfile = "$date.txt.gz";
      $mboxtype = "Gzip'd Text";
    } elsif (-f "$dirname/$date.txt") {
      $mboxfile = "$date.txt";
      $mboxtype = "Text";
    }

    if (defined $mboxfile) {
      $mboxsize = (stat ("$dirname/$mboxfile"))[7];
    } else {
      $mboxfile = "$date.txt";
      $mboxtype = "???";
      $mboxsize = 0;
    }
    
    print INDEX <<EOT;
            <tr>
            <td>$date:</td>
            <td>
              <A href="$date/thread.html">[ Thread ]</a>
              <A href="$date/date.html">[ Date ]</a>
              <A href="$date/author.html">[ Author ]</a>
            </td>
            <td><A href="$mboxfile">[ $mboxtype $mboxsize bytes ]</a></td>
            </tr>
EOT
  }

  print INDEX <<EOT;
  </table>
  <div id="footer">
    Copyright &copy; 2005, 2006, 2007 <a href="http://www.gnome.org/">The GNOME Project</a>.<br />
    <a href="http://validator.w3.org/check/referer">Optimised</a> for <a href="http://www.w3.org/">standards</a>. Hosted by <a href="http://www.redhat.com/">Red Hat</a>.
  </div>

  </div> <!-- end of div.body -->
</body>
</html>
EOT
    
  close INDEX;
}

##########################################################

package Main;

use Getopt::Long;
use Date::Parse qw(str2time);

my $listname;
my $private = 0;
my $makeindex = 0;
my $start_time = 0;
my $end_time = 0;
my $debug = 0;

$ENV{PATH} = "$ENV{PATH}:/usr/local/bin";

GetOptions ("listname=s" => \$listname,
	    "makeindex" => \$makeindex,
	    "private" => \$private,
	    "start-time=s" => \$start_time,
	    "end-time=s" => \$end_time,
	    "debug" => \$debug);

if (@ARGV > 1 || !defined $listname) {
  print "Usage archive.pl [--debug] [ --private ] [--start-time DATE] [--end-time DATE] --listname NAME (--makeindex | [ FILE ])\n";
  exit (1);
}

umask 0022;

if ($makeindex) {
  Archiver::make_index ($listname, $private);
  exit (0);
}

my $file = $ARGV[0];
my $msg_text = "";
my @mail  = ();
my $blank = 1;

my $archiver = new Archiver (listname => $listname,
			     private => $private, debug => $debug);

if ($start_time) {
  $archiver->{start_time} = str2time($start_time);
}
if ($end_time) {
  $archiver->{end_time} = str2time($end_time);
}

if (defined $file) {
  open(FH,"< $file") or die ("cannot open '$file': $!\n");
  $fh = \*FH;
} else {
  $fh = \*STDIN;
}

my $line;
while (defined ($line = <$fh>)) {
  if ($blank && $line =~ /\AFrom .*\d{4}/) {
    # Matched beginning of a new message

    $archiver->handle_msg (\@mail, $msg_text) if scalar(@mail);
    @mail = ( $line );
    $msg_text = $line;
    $blank = 0;
  }
  else {
    $blank = $line =~ m#\A\Z#o ? 1 : 0;
    push @mail, $line;
    $msg_text .= $line;
  }
}

$archiver->handle_msg (\@mail, $msg_text) if scalar(@mail);

close($fh);

$archiver->output (1);

exit (0);
