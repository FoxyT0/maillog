FROM perl:slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN cpan App::cpanminus && cpanm --notest --verbose DBI DBD::Pg CGI HTTP::Server::Simple::CGI

WORKDIR /app
COPY script.pl /app/script.pl
COPY web.pl /app/web.pl
COPY runner.sh /app/runner.sh
RUN chmod +x /app/script.pl /app/web.pl /app/runner.sh

CMD ["/app/runner.sh"]
