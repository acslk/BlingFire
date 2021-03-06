@perl -Sx %0 %*
@goto :eof
#!perl


sub usage {

print <<EOM;

Usage: fa_ts_compare [OPTIONS] corpusA.utf8 corpusB.utf8 > accuracy.txt

This program compares corpus B against corpus A (assuming A is 100% correct.)
Corpora should be identical, except for assgined POS tags.

  --out-diff=<file> -- output high-lighted differences in HTML format

  --out-mx=<file> -- output confusion matrix: TagA\tTagB\tCount

Input format:
  ...
  Word1/TAG Multi_Word_2/TAG ...Word2/TAG\\n
  ...
EOM

}

$out_diff = "";
$out_mx = "";

while (0 < 1 + $#ARGV) {

    if("--help" eq $ARGV [0]) {

        usage ();
        exit (0);

    } elsif ($ARGV [0] =~ /^--out-diff=(.+)/) {

        $out_diff = $1;

    } elsif ($ARGV [0] =~ /^--out-mx=(.+)/) {

        $out_mx = $1;

    } else {

      last;
    }
    shift @ARGV;
}


$SIG{PIPE} = sub { die "ERROR: Broken pipe at fa_ts_compare" };

if("" ne $out_diff) {
  open OUTDIFF, ">$out_diff" ;
}


$tag_count = 0;
$matched_tag_count = 0;

$fileA = $ARGV [0];
$fileB = $ARGV [1];

$LineNum=0;

$[ = 1;			# set array base to 1

open INPUTA, "< $fileA" ;
open INPUTB, "< $fileB" ;

# read line by line
while(<INPUTA>) {

  $LineA = $_;

  $LineNum++;

  # read same line from the INPUTB
  if(!($LineB = <INPUTB>)) {
    print STDERR "ERROR: Corpus A has more lines than corpus B. \"$LineA\" at line: $LineNum is in A but B is empty.";
    exit(1);
  }

  $LineA =~ s/[\r\n]+//g;
  $LineA =~ s/^\xEF\xBB\xBF//;

  $LineB =~ s/[\r\n]+//g;
  $LineB =~ s/^\xEF\xBB\xBF//;

  # split sentence into words
  @FldA = split(" ", $LineA, 999999);
  @FldB = split(" ", $LineB, 999999);

  # see if the amount of tokens in each line is the same
  if($#FldA != $#FldB) {
     print STDERR "ERROR: Different amount of tokens. $#FldA != $#FldB. Corpus A: \"$LineA\" Corpus B:\"$LineB\" at line: $LineNum";
     exit(1);
  }

  $found_mismatches = 0;
  $diff_str = "";

  # see which of the tags match
  for($i = 1; $i <= $#FldA; $i++) {

    $twA = $FldA[$i];
    $tA = "";
    if($twA =~ /^.*[\x2f]([^\x2f]+)$/) {
      $tA = $1;
    } else {
      print STDERR "ERROR: Corpus A contains invalid line: \"$LineA\". Cannot get tag for \"$twA\" at line: $LineNum";
      exit(1);
    }

    $twB = $FldB[$i];
    $tB = "";
    if($twB =~ /^.*[\x2f]([^\x2f]+)$/) {
      $tB = $1;
    } else {
      print STDERR "ERROR: Corpus B contains invalid line: \"$LineB\". Cannot get tag for \"$twB\" at line: $LineNum";
      exit(1);
    }

    $tag_count = 1 + $tag_count;

    # update matched tags count, if needed
    if($tA eq $tB) {

      $matched_tag_count = 1 + $matched_tag_count;
      $diff_str .= ($twA . " ");

    } else {

      $found_mismatches = 1;
      $diff_str .= ("<strong>" . $twA . "-->" . $tB . "</strong> ");
    }

    # update confusion matrix, if needed
    if("" ne $out_mx) {
       $mx{$tA . "\t" . $tB} = 1 + $mx{$tA . "\t" . $tB} ;
    }
  }

  # see if the diff should be printed out
  if($found_mismatches == 1 && "" ne $out_diff) {
    print OUTDIFF "<p> $LineNum: " . $diff_str . "</p>\n";
  }

  # print the progress
  if(0 == $LineNum % 1000) {
    print STDERR "Compared Lines: $LineNum                                \r";
  }
}

close OUTDIFF ;
close INPUTA ;
close INPUTB ;

# print the confusion matrix, if needed
if("" ne $out_mx) {

  open MX, ">$out_mx" ;

  foreach $tt (sort keys %mx) {
    # print TAGA\tTAGB\tCOUNT
    print MX "$tt\t$mx{$tt}\n";
  }

  close MX ;
}

print "Total Tag Count: $tag_count \n" ;
print "Matched Tag Count: $matched_tag_count\n";
if(0 < $tag_count) {
  printf "Accuracy: %4.4f %\n", (100.0 * ((0.0 + $matched_tag_count) / (0.0 + $tag_count)));
} else {
  print "Accuracy: UNDEFINED\n";
}
