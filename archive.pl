#!/usr/bin/perl -w

package Archiver;

$ARCHIVE_DIR = "/var/mailman/web-archives/private";
$PUBLIC_ARCHIVE_DIR = "/var/mailman/web-archives/public";
$PUBLIC_RCFILE = "/var/mailman/mhonarc/public-rc/base.rc";
$PRIVATE_RCFILE = "/var/mailman/mhonarc/private-rc/base.rc";

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

  my $dir = $ARCHIVE_DIR;
  $dir .= "/$self->{listname}/$self->{olddir}";

  $self->{tmpfile}->close;

  if (!-d $dir) {
    use File::Path qw(mkpath);
    mkpath $dir, 0, 0755;
  }

  $rcfile = $self->{private} ? $PRIVATE_RCFILE : $PUBLIC_RCFILE;

  system (<<EOT);
mhonarc -rcfile $rcfile -add -outdir $dir $tmpname -definevar "ARCHDATE=$self->{olddir} LISTNAME=$self->{listname}" >> /var/log/mailman/archive 2>&1 
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

	symlink "$ARCHIVE_DIR/$self->{listname}", "$PUBLIC_ARCHIVE_DIR/$self->{listname}" 
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

  $field_text = $msg->head()->get ("Received", 0);

  my $time;

  if (defined $field_text) {
    $received = new Mail::Field ('received', $field_text);
    if ($received->parsed_ok ()) {
      my $parse_tree = $received->parse_tree();
      $time = str2time ($parse_tree->{date_time}->{whole});
    }
  }

  return if ($start_time > 0 && $time < $start_time);
  return if ($end_time > 0 && $time > $end_time);

  if (defined ($time)) {
    $dir =  strftime ("%Y-%B", gmtime ($time));

    if (defined $self->{olddir} && $self->{olddir} ne $dir)
      {
	$self->output (0);
      }
    
    $self->{olddir} = $dir;
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
  
  my $dirname = $ARCHIVE_DIR . "/$listname";
  
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
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<HTML>
  <HEAD>
     <title>The $listname Archives</title>
  </HEAD>
  <BODY BGCOLOR="#ffffff">
     <h1>The $listname Archives </h1>
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
   } else {
       print INDEX <<EOT;
<form method="get" action="/mailman/search">
<p>
Search:
<input type="text" name="query" size="40">
<select name="subquery"> 
 <option value="+uri:/^http://mail.gnome.org/archives/$listname/">This mailing list only</option>
 <option value="">All mailing lists</option>
</select>
<input type="hidden" name="reference" value="off">
<input type="submit" name="submit" value="Search!">
<a href="/mailman/search">[More...]</a>
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
  </BODY>
</HTML>
EOT
    
  close INDEX;
}

##########################################################

package Main;

use Getopt::Long;

my $listname;
my $private = 0;
my $makeindex = 0;
my $start_time = 0;
my $end_time = 0;

$ENV{PATH} = "$ENV{PATH}:/usr/local/bin";

GetOptions ("listname=s" => \$listname,
	    "makeindex" => \$makeindex,
	    "private" => \$private,
	    "start-time" => \$start_time,
	    "end-time" => \$end_time);

if (@ARGV > 1 || !defined $listname) {
  print STDERR "Usage archive.pl [ --private ] [--start-time DATE] [--end-time DATE] --listname NAME (--makeindex | [ FILE ])\n";
  exit (1);
}

if ($makeindex) {
  Archiver::make_index ($listname, $private);
  exit (0);
}

if ($start_time) {
  $start_time = str2time($start_time);
}

if ($end_time) {
  $end_time = str2time($end_time);
}

my $file = $ARGV[0];
my $msg_text = "";
my @mail  = ();
my $blank = 1;

my $archiver = new Archiver (listname => $listname,
			     private => $private);

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
