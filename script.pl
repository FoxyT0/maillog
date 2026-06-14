#!/usr/bin/perl

use v5.28;
use strict;
use warnings;
use DBI;

my $LOG_FILE_PATH = './maillog';

# timestamp, int_id, flag, id 
my $ARRIVAL_REGEXP = qr/
    ^(\d{4}\-\d{2}\-\d{2}\s\d{2}\:\d{2}\:\d{2})
    \s(\w*\-\w*\-\w*)
    \s<=\s.*
    id=(.*)
    /mx;

# timestamp, int_id, flag, address
my $LOG_REGEXP = qr/
    ^(\d{4}\-\d{2}\-\d{2}\s\d{2}\:\d{2}\:\d{2})
    \s(\w*\-\w*\-\w*)
    \s.{2}
    \s([\w\-\.]+@([\w-]+\.)+[\w-]{2,}|<>|:blackhole:)
    /mx;

my $STR_WITHOUT_DATETIME_REGEXP = qr/^(\d{4}\-\d{2}\-\d{2}\s\d{2}\:\d{2}\:\d{2})\s/;

my $DATE_TIME_CUT_REGEXP = qr/(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})\s(\w+-\w+-\w+)/;

sub main {
    my $FH = openFile($LOG_FILE_PATH) or die "Failed to open '$LOG_FILE_PATH' : $!";
    unless (defined $FH) {
        die "Failed to open '$LOG_FILE_PATH'";
    }

    my $dbh = connectDB($ENV{DB_NAME}, $ENV{DB_HOST}, $ENV{DB_PORT}, $ENV{DB_USER}, $ENV{DB_PASSWORD});
    
    my $message_insert = $dbh->prepare(
        "INSERT INTO message (created, id, int_id, str, status) VALUES (?, ?, ?, ?, NULL)"
    );
    my $log_insert = $dbh->prepare(
        "INSERT INTO log (created, int_id, str, address) VALUES (?, ?, ?, ?)"
    );

    while (my $line = <$FH>) {
        chomp $line;
        my $str = $line;
        $str =~ s/$STR_WITHOUT_DATETIME_REGEXP//;
        if ($line =~ $ARRIVAL_REGEXP) {
            inserIntoMessageTable($message_insert, $1, $3, $2, $str);
        } elsif ($line =~ $LOG_REGEXP) {
            inserIntoLogTable($log_insert, $1, $2, $str, $3);
        } elsif ($line =~ $DATE_TIME_CUT_REGEXP) { 
            inserIntoLogTable($log_insert, $1, $2, $str, undef);
        }
    }

    $message_insert->finish if $message_insert;
    $log_insert->finish if $log_insert;

    $dbh->disconnect if defined $dbh;
    close $FH;
}

sub inserIntoMessageTable {
    my ($message_insert, $created, $id, $int_id, $str) = @_;

    $message_insert->execute($created, $id, $int_id, $str);
}

sub inserIntoLogTable {
    my ($log_insert, $created, $int_id, $str, $address) = @_;

    $log_insert->execute($created, $int_id, $str, $address);
}

sub connectDB {
    my ($DB_NAME, $DB_HOST, $DB_PORT, $DB_USER, $DB_PASSWORD) = @_;
    my $dbh = DBI->connect(
        "dbi:Pg:dbname=$DB_NAME;host=$DB_HOST;port=$DB_PORT",
        $DB_USER,
        $DB_PASSWORD,
        { RaiseError => 1, AutoCommit => 1 }
    );
    return $dbh;
}

sub openFile {
    my ($path) = @_;
    open my $fielHadler, '<', $path or do {
        my $err = $!;
        warn "Cannot open '$path': $err";
        return;
    };
    return $fielHadler;
}

main();

1;