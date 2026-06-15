#!/usr/bin/env perl
use strict;
use warnings;
use HTTP::Server::Simple::CGI;
use CGI qw(:standard -utf8);
use DBI;

my $port = $ENV{WEB_PORT};
my $host = $ENV{DB_HOST};
my $dbport = $ENV{DB_PORT};
my $dbname = $ENV{DB_NAME};
my $dbuser = $ENV{DB_USER};
my $dbpass = $ENV{DB_PASSWORD};
my $dsn = "dbi:Pg:dbname=$dbname;host=$host;port=$dbport";
my $LIMIT = 100;

{
    package MyWebServer;
    use base qw(HTTP::Server::Simple::CGI);

    sub handle_request {
        my ($self, $cgi) = @_;
        print "HTTP/1.0 200 OK\r\n";
        print $cgi->header(-type => 'text/html; charset=UTF-8');
        print $cgi->start_html(-title => 'Поиск по адресу', -encoding => 'utf-8');
        print $cgi->h1('Поиск по адресу получателя');

        my $addr = $cgi->param('address') // '';

        print $cgi->start_form(-method=>'GET'),
              "Адрес: ", $cgi->textfield(-name=>'address', -value=>$addr, -size=>60), " ",
              $cgi->submit(-value=>'Поиск'),
              $cgi->end_form;

        if (defined $addr && $addr ne '') {
            my $dbh = DBI->connect($dsn, $dbuser, $dbpass, { RaiseError => 1, AutoCommit => 1, pg_enable_utf8 => 1 });
            if (!$dbh) {
                print $cgi->p("DB connect failed: $DBI::errstr");
                print $cgi->end_html;
                return;
            }

            my $sql = qq{
                SELECT created, str
                FROM (
                    SELECT m.created, m.int_id, m.str
                    FROM message m
                    WHERE m.int_id IN (
                        SELECT DISTINCT l.int_id
                        FROM log l
                        WHERE l.address = ?
                    )

                    UNION ALL

                    SELECT l.created, l.int_id, l.str
                    FROM log l
                    WHERE l.address = ?
                ) t
                ORDER BY int_id, created
                LIMIT ?
            };

            my $sth = $dbh->prepare($sql) or die $dbh->errstr;
            $sth->execute($addr, $addr, $LIMIT + 1) or die $sth->errstr;

            my @rows;
            while (my $r = $sth->fetchrow_hashref) {
                push @rows, $r;
            }

            for my $r (@rows) {
                print $r->{created}, " ", $r->{str}, "<br>\n";
            }
            
            $sth->finish;
            $dbh->disconnect;

            my $count = scalar @rows;
            my $more = 0;
            if ($count > $LIMIT) {
                $more = 1;
                $#rows = $LIMIT - 1;
                $count = $LIMIT;
            }

            if ($count == 0) {
                print $cgi->p("Ничего не найдено для адреса: " . $cgi->escapeHTML($addr));
            } else {
                print $cgi->p("Найдено записей: $count" . ($more ? " (показаны первые $LIMIT)" : "") );
                print "<pre>\n";
                foreach my $r (@rows) {
                    my $ts = $r->{log_created} // '';
                    my $line = sprintf("%s %s", $ts, $r->{log_str} // '');
                    print $cgi->escapeHTML($line) . "\n";
                }
                print "</pre>\n";
                if ($more) {
                    print $cgi->p("<strong>Внимание:</strong> количество найденных строк превышает лимит $LIMIT — отображены только первые $LIMIT записей.");
                }
            }
        }

        print $cgi->end_html;
    }
}

my $server = MyWebServer->new($port);
$server->host('0.0.0.0');
print "Starting server on port $port...\n";
$server->run;
