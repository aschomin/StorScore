@rem = ' vim: set filetype=perl: ';
@rem = ' --*-Perl-*-- ';
@rem = '
@echo off
setlocal
set PATH=%~dp0\perl\bin;%~dp0\bin;%PATH%
perl -w "%~f0" %*
exit /B %ERRORLEVEL%
';

# StorScore
#
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

use strict;
use warnings;

use Getopt::Long;
use File::Basename;
use English;

my $script_name = basename( $PROGRAM_NAME );
my $script_dir = dirname( $PROGRAM_NAME );

my $outfile;

GetOptions(
    "outfile=s" => \$outfile,
);

unless( defined $outfile )
{
    warn "usage: $script_name --outfile=FILE\n";
    exit(-1);
}

$outfile = "$script_dir\\$outfile";

sub my_exec
{
    my $cmd = shift;
    
    system( "echo TEST_BEGIN >> $outfile" );
    system( "echo $cmd >> $outfile" );

    system( "$cmd >> $outfile 2>&1" );

    system( "echo TEST_END >> $outfile" );
    system( "echo. >> $outfile" );
}

sub run_one
{
    my $args = shift;

    my $cargs;
    $cargs .= "--target=1234 ";
    $cargs .= "--pretend ";
    $cargs .= "--verbose ";
    $cargs .= "--noprompt ";

    # ISSUE-REVIEW:
    # Do --target_type=ssd and --target_type=hdd here instead of below?

    # run default recipe 
    my_exec(
        "storscore.cmd $cargs $args"
    );

    # run corners
    my_exec(
        "storscore.cmd $cargs $args --recipe=recipes\\corners.rcp"
    );
}

unlink( $outfile );
chdir( ".." );
    
# Preserve existing results directory
rename( "results", "results.orig" );

run_one( "" );
run_one( "--this_flag_does_not_exist" );
run_one( "--noinitialize" );
run_one( "--noprecondition" );
run_one( "--target_type=ssd" );
run_one( "--target_type=hdd" );
run_one( "--raw_disk" );
run_one( "--active_range=50" );
run_one( "--partition_bytes=1000000000" );
run_one( "--test_id=regr" );
run_one( "--test_id_prefix=regr" );
 
# Restore original results directory
system( "rmdir /S /Q results >NUL 2>&1" );
rename( "results.orig", "results" );

# Post process output file to remove noise
rename( $outfile, "$outfile.orig" );

open( my $in, "<$outfile.orig" );
open( my $out, ">$outfile" );

while( my $line = <$in> )
{
    # Remove random temp file names
    $line =~ s/AppData\\\S*//;

    # Remove ETA info
    $line =~ s/\d{2}:\d{2}:\d{2} (AM|PM)//g;

    # Remove time from autogenerated results dir
    if( $line =~ /results/ )
    {
        $line =~ s/-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}//;
    }

    # Remove "Done" line with overall runtime
    $line =~ s/^Done.*//;

    print $out $line;
}

close $in;
close $out;

unlink( "$outfile.orig" );

print "Done! Diff $outfile against another run.\n";
