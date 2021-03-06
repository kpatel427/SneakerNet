#!/usr/bin/env perl
# Moves folders from the dropbox-inbox pertaining to reads, and
# Runs read metrics on the directory

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename qw/fileparse basename dirname/;
use File::Temp;
use FindBin;

use lib "$FindBin::RealBin/../lib/perl5";
use SneakerNet qw/readConfig samplesheetInfo command logmsg version/;
my @fastqExt=qw(.fastq.gz .fq.gz .fastq .fq);

my $snVersion=version();

local $0=fileparse $0;
exit(main());

sub main{
  my $settings=readConfig();
  GetOptions($settings,qw(help numcpus=i debug tempdir=s)) or die $!;
  die usage() if($$settings{help} || !@ARGV);
  $$settings{numcpus}||=1;
  $$settings{tempdir}||=File::Temp::tempdir(basename($0).".XXXXXX",TMPDIR=>1,CLEANUP=>1);

  my $dir=$ARGV[0];

  mkdir("$dir/SneakerNet/SalmID");
  
  identifyEach($dir,$settings);

  command("cat $dir/SneakerNet/SalmID/*/*.tsv > $dir/SneakerNet/forEmail/SalmID.tsv");

  return 0;
}

sub identifyEach{
  my($dir,$settings)=@_;

  my $sampleInfo=samplesheetInfo("$dir/SampleSheet.csv",$settings);
  while(my($sampleName,$s)=each(%$sampleInfo)){
    next if(ref($s) ne 'HASH'); # avoid file=>name aliases
    my $taxon=$$s{species} || 'NOT LISTED';

    my $outdir="$dir/SneakerNet/SalmID/$sampleName";
    next if(-e $outdir);
    my $tempdir="$$settings{tempdir}/$sampleName";
    mkdir $tempdir;
    for my $fastq(@{ $$s{fastq} }){
      logmsg $fastq;
      command("SalmID.py -i '$fastq' > $tempdir/".basename($fastq,@fastqExt).".tsv");
    }
    command("mv $tempdir $outdir");
  }
}

sub usage{
  "Run SalmID on each fastq file to identify the species/subspecies
  Usage: $0 run-dir
  --debug          Show debugging information
  --numcpus     1  Number of CPUs (has no effect on this script)
  "
}
