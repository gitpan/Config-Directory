package Config::Directory;

use 5.000;
use File::Basename;
use File::Spec;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

sub readfile
{
    my ($self, $df, $arg) = @_;
    my $content = '';

    # Open
    open FILE, "<$df" or die "can't open file '$df': $!";

    # Read only $arg->{lines} lines, if set
    if ($arg->{lines} && $arg->{lines} =~ m/(\d+)/) {
        for (1 .. $1) {
            $content .= <FILE>;
        }
    }

    # Slurp entire file
    else {
        local $/ = undef;
        $content = <FILE>;
    }
    close FILE;

    return $content;
}

sub init
{
    my ($self, $dir, $arg) = @_;
    $dir = [ $dir ] if ref $dir ne 'ARRAY';
    my $env = $arg->{env};
    my $maxsize = $arg->{maxsize} || 102_400;
    my $ignore = $arg->{ignore};

    # Iterate over directories
    for my $d (@$dir) {
        if (! -d $d) {
            warn "invalid directory '$d'"; 
            next;
        }
 
        # Read file list
        my @files = ();
        if ($arg->{glob}) {
            @files = glob File::Spec->catfile($d, $arg->{glob});
        }
        else {
            opendir DIR, $d or die "can't open directory '$d': $!";
            @files = readdir DIR;
        }

        # Iterate over files
        for my $f (@files) {
            my $df = $arg->{glob} ? $f : File::Spec->catfile($d, $f);
            $f = basename($f) if $arg->{glob};
            my $pf = defined $arg->{prefix} ? $arg->{prefix} . "$f" : $f;
            my $ef = $env eq '1' ? $pf : "${env}$f" if $env;

            # Ignore directories
            next if -d $df;

            # Ignore if matches $ignore regex
            next if defined $ignore && $f =~ m/$ignore/;

            # Ignore if size > $maxsize
            next if -s $df > $maxsize;

            # Zero-sized files clear any existing entry
            if (-z $df) {
                delete $self->{$pf};
                delete $ENV{$ef} if $env;
                next;
            }

            # Warn on permissions problems
            if (! -r $df) {
                warn "can't read file '$df'";
                next;
            }

            # Read file
            $self->{$pf} = $self->readfile($df, $arg);

            # Chomp value unless chomp => 0 arg given
            chomp $self->{$pf} 
                unless exists $arg->{'chomp'} && $arg->{'chomp'} == 0;

            # Add to environment ('env_dir') if 'env' option and single line
            if ($env) {
                my ($first, $rest) = split /\n/, $self->{$pf}, 2;
                if (! $rest) {
                    $ENV{$ef} = $self->{$pf};
                    chomp $ENV{$ef};
                }
            }
        }
        closedir DIR;
    }

    return $self;
}

sub new 
{
    my $self = bless {}, shift;
    $self->init(@_);
}

1;

__END__

=head1 NAME

Config::Directory - hash-based interface to directories of files


=head1 SYNOPSIS

  use Config::Directory;

  # Simple 
  $c = Config::Directory->new("/etc");
  print $c->{passwd}, "\n";

  # Multiple config directories
  $cc = Config::Directory->new([ "/usr/local/myapp/conf", "$HOME/.myapp" ]);

  # Options: add prefix, export values to environment, read only first line
  #   ignore all README.* files
  $qc = Config::Directory->new("/var/qmail/service/qmail/env",
      { prefix => 'QMAIL_', env => 1, lines => 1, ignore => 'README.*' });
  print $q->{QMAIL_CONCURRENCY}, $ENV{QMAIL_CONCURRENCY}, "\n";


=head1 ABSTRACT

  OO-interface to directories of files, particularly suited to configs 
  loaded from multiple small files across multiple cascading 
  directories.


=head1 DESCRIPTION

Config::Directory presents an OO hash-based read-only interface to
directories of files. It is particularly suited to configuration
directories where settings can cascade across multiple directories 
with multiple files per directory.  Using multiple directories for
configuration data allows an application to support, for example,
distribution defaults, global site settings, and user-specific local
settings. Using multiple configuration files can often simplify
formatting, reduce parsing requirements, and improve scriptability 
(e.g. 'echo 10 > conf/MAXSIZE').

Config::Directory uses a very simple OO-style interface - only the new()
method exists. Basic usage is:

  # Load all files in a single directory
  $c = Config::Directory->new("/etc");
  print $c->{passwd};

where the returned Config::Directory object will contain a hash reference
of the files in the directory, keyed by filename, with each entry
containing the (chomped) contents of the relevant file. Subdirectories
are ignored, as are zero-length files and files greater than 100K in size
(the limit is tunable via the 'maxsize' option). 

The directory argument to new() can be either a single directory, as 
in the example above, or an arrayref of directories to allow multiple 
cascading configuration directories. Thus:

  # Multiple config directories
  $cc = Config::Directory->new([ "/usr/local/myapp/conf", "$HOME/.myapp" ]);

loads the files from /usr/local/myapp/conf, followed by those from
$HOME/.myapp. Later files with the same name override previous ones.

new() also takes an optional hashref of options. The following are
currently defined:

=over 4

=item B<lines>

The maximum number of lines (newline-delimited) to read from a file
(default: unlimited).

=item B<maxsize>

Maximum size of file to read - files larger than B<maxsize> are 
ignored (default: 100K).

=item B<ignore>

Regex of filenames to ignore (default: none).

=item B<glob>

Glob pattern of filenames to include - all other files are ignored
(default: none).

=item B<prefix>

Prefix to prepend to key values (filenames) in the returned hashref,
and to environment variables, if the B<env> option is set (default:
none). e.g.
 
  $cc = Config::Directory("$HOME/.myapp", { prefix => 'MYAPP_' });

=item B<env>

Flag to indicate whether single-line values should be set as 
environment variables. If B<env> is 1, the variable name will be the 
same as the corresponding key value (including a B<prefix>, if set).
If B<env> is true but != 1, the B<env> value will be used as the
prefix prepended to the filename when setting the environment 
variables (default: none). e.g.

  $cc = Config::Directory("$HOME/.myapp", { env => 'MYAPP_' });

will set environment variables MYAPP_filename1, MYAPP_filename2, etc.

=item B<chomp>

By default, all file values are B<chomp>ed, which allows single-line
files to produce immediately useful values. If you don't like this,
you can turn it off by setting chomp to zero.

=back


=head1 LIMITATIONS

Config::Directory is currently read-only. A read-write interface is 
likely in the future (see e.g. Tie::TextDir in the meantime).

It's also not recursive - subdirectories are simply ignored. And
there is no file-merging support - files of the same name in later
directories simply overwrite the previous ones.


=head1 SEE ALSO

The Tie::TextDir and DirDB modules are conceptually similar, but use
a TIEHASH interface and do not support inheritance across multiple
directories. The facility to export to the environment is inspired by
the env_dir utility in Dan J. Bernstein's daemontools.


=head1 AUTHOR

Gavin Carr, E<lt>gavin@openfusion.com.auE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Gavin Carr and Open Fusion Pty. Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
