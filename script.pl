# <= прибытие сообщения (в этом случае за флагом следует адрес отправителя)
# => нормальная доставка сообщения
# -> дополнительный адрес в той же доставке
# ** доставка не удалась
# == доставка задержана (временная проблема)

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
    \s\<\=\s.*
    id\=(.*)
    /mx;

    # timestamp, int_id, flag, address
my $LOG_REGEXP = qr/
    ^(\d{4}\-\d{2}\-\d{2}\s\d{2}\:\d{2}\:\d{2})
    \s(\w*\-\w*\-\w*)
    \s.{2}
    \s([\w\-\.]+@([\w-]+\.)+[\w-]{2,}|<>|:blackhole:)
    /mx;

my $messageCount = 0;
my $logCount = 0;

open (fileHandler, "<", $LOG_FILE_PATH) or die $!;

my $dbh = DBI->connect(
    "dbi:Pg:dbname=${ENV{DB_NAME}};host=${ENV{DB_HOST}};port=${ENV{DB_PORT}}",
    $ENV{DB_USER},
    $ENV{DB_PASSWORD},
    { RaiseError => 1, AutoCommit => 1 }
);

my $message_insert = $dbh->prepare(
    "INSERT INTO message (created, id, int_id, str, status) VALUES (?, ?, ?, ?, NULL)" # status ?
);

my $log_insert = $dbh->prepare(
    "INSERT INTO log (created, int_id, str, address) VALUES (?, ?, ?, ?)"
);

while (<fileHandler>){
    (my $str = $_) =~ s/^(\d{4}\-\d{2}\-\d{2}\s\d{2}\:\d{2}\:\d{2})\s//g;
    if ($_ =~ $ARRIVAL_REGEXP) {
        $message_insert->execute($1, $3, $2, $str);
    } elsif ($_ =~ $LOG_REGEXP) {
        $log_insert->execute($1, $2, $str, $3);
    } elsif ($_ =~ /(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})\s(\w+-\w+-\w+)/) { 
        $log_insert->execute($1, $2, $str, undef);
    }
}

close(fileHandler);

1;