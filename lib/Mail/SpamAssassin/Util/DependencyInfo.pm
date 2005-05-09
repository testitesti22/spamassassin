# Helper code to debug dependencies and their versions.

# <@LICENSE>
# Copyright 2004 Apache Software Foundation
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

package Mail::SpamAssassin::Util::DependencyInfo;

use strict;
use warnings;
use bytes;

use vars qw (
  @MODULES @OPTIONAL_MODULES $EXIT_STATUS $WARNINGS
);

my @MODULES = (
{
  'module' => 'Digest::SHA1',
  'version' => '0.00',
  'desc' => 'The Digest::SHA1 module is used as a cryptographic hash for some
  tests and the Bayes subsystem.  It is also used by Razor2.',
},
{
  'module' => 'HTML::Parser',
  'version' => '3.24',
  'desc' => 'Version 3.31 or later is recommended.

  HTML is used for an ever-increasing amount of email so this dependency
  is unavoidable.  Run "perldoc -q html" for additional information.',
},
);

my @OPTIONAL_MODULES = (
{
  module => 'MIME::Base64',
  version => '0.00',
  desc => 'This module is highly recommended to increase the speed with which
  Base64 encoded messages/mail parts are decoded.',
},
{
  module => 'DB_File',
  version => '0.00',
  desc => 'Used to store data on-disk, for the Bayes-style logic and
  auto-whitelist.  *Much* more efficient than the other standard Perl
  database packages.  Strongly recommended.',
},
{
  module => 'Net::DNS',
  version => ($^O =~ /^(mswin|dos|os2)/oi ? '0.46' : '0.34'),
  desc => 'Used for all DNS-based tests (SBL, XBL, SpamCop, DSBL, etc.),
  perform MX checks, and is also used when manually reporting spam to
  SpamCop.  Recommended.

  If this is installed and you are using network tests of any variety
  (which is the default), then you need to make sure the Net::DNS
  version is sufficiently up-to-date:

  - version 0.34 or higher on Unix systems
  - version 0.46 or higher on Windows systems',
},
{
  'module' => 'Storable',
  'version' => '2.12',
  'desc' => 'This is a required module if you use spamd and allow user
  configurations to be used (ie: you don\'t use -x, -u, -q/--sql-config,
  -Q/--setuid-with-sql, --ldap-config, or --setuid-with-ldap).  Third
  party utilities may also require this module for the same
  functionality.  Storable is used to shift configuration when a spamd
  process switches between users. 

  If you plan to run SpamAssassin on a multiprocessor Linux machine, or one
  with a hyperthreaded CPU like a Pentium 4, it is strongly recommended that
  you ensure version 2.12 (or newer) is installed.  This fixes a bug that
  causes hangs under heavy load with that hardware configuration.',

},
{
  module => 'Net::SMTP',
  alt_name => 'libnet',
  version => '0.00',
  desc => 'Used when manually reporting spam to SpamCop with "spamassassin -r".',
},
{
  module => 'Mail::SPF::Query',
  version => '0.00',
  desc => 'Used to check DNS Sender Policy Framework (SPF) records to fight email
  address forgery and make it easier to identify spams.',
},
{
  module => 'IP::Country::Fast',
  alt_name => 'IP::Country',
  version => '0.00',
  desc => 'Used by the RelayCountry plugin (not enabled by default) to determine
  the domain country codes of each relay in the path of an email.',
},
{
  module => 'Razor2::Client::Agent',
  alt_name => 'Razor2',
  version => '2.61',
  desc => 'Used to check message signatures against Vipul\'s Razor collaborative
  filtering network. Razor has a large number of dependencies on CPAN
  modules. Feel free to skip installing it, if this makes you nervous;
  SpamAssassin will still work well without it.

  More info on installing and using Razor can be found
  at http://wiki.apache.org/spamassassin/InstallingRazor .',
},
{
  module => 'Net::Ident',
  version => '0.00',
  desc => 'If you plan to use the --auth-ident option to spamd, you will need
  to install this module.',
},
{
  module => 'IO::Socket::SSL',
  version => '0.00',
  desc => 'If you wish to use SSL encryption to communicate between spamc and
  spamd (the --ssl option to spamd), you need to install this
  module. (You will need the OpenSSL libraries and use the
  ENABLE_SSL="yes" argument to Makefile.PL to build and run an SSL
  compatibile spamc.)',
},
{
  module => 'Time::HiRes',
  version => '0.00',
  desc => 'If this module is installed, the processing times are logged/reported
  more precisely in spamd.',
},
{
  module => 'DBI',
  version => '0.00',
  desc => 'If you intend to use SpamAssassin with an SQL database backend for
  user configuration data, Bayes storage, or other storage, you will need
  to have these installed; both the basic DBI module and the driver for
  your database.',
},
{
  module => 'Getopt::Long',
  version => '2.32',        # min version was included in 5.8.0, which works
  desc => 'The "sa-stats.pl" script included in "tools", used to generate
  summary reports from spamd\'s syslog messages, requires this version
  of Getopt::Long or newer.',
},
);

###########################################################################

=item $f->debug_diagnostics ()

Output some diagnostic information, useful for debugging SpamAssassin
problems.

=cut

sub debug_diagnostics {
  my $out = "diag: perl platform: $] $^O\n";

  foreach my $moddef (sort (@MODULES, @OPTIONAL_MODULES)) {
    my $module = $moddef->{module};
    my $modver;
    if (eval ' require '.$module.'; $modver = $'.$module.'::VERSION; 1;')
    {
      $modver ||= '(undef)';
      $out .= "module installed: $module, version $modver\n";
    } else {
      $out .= "module not installed: $module ('require' failed)\n";
    }
  }
  return $out;
}

sub long_diagnostics {
  my $summary = "";

  print "checking module dependencies and their versions...\n";

  $EXIT_STATUS = 0;
  $WARNINGS = 0;
  foreach my $moddef (@MODULES) {
    try_module(1, $moddef, \$summary);
  }
  foreach my $moddef (@OPTIONAL_MODULES) {
    try_module(0, $moddef, \$summary);
  }

  print $summary;
  if ($EXIT_STATUS || $WARNINGS) {
    print "\nwarning: some functionality may not be available,\n".
            "please read the above report before continuing!\n\n";
  }
  return $EXIT_STATUS;
}

sub try_module {
  my ($required, $moddef, $summref) = @_;

  eval "use $moddef->{module} $moddef->{version};";
  if (!$@) {
    return;
  }

  my $not_installed = 0;
  eval "use $moddef->{module};";
  if ($@) {
    $not_installed = 1;
  }

  my $pretty_name = $moddef->{alt_name} || $moddef->{module};
  my $pretty_version = ($moddef->{version} > 0 ?
                "(version $moddef->{version}) " : "");
  my $desc = $moddef->{desc}; $desc =~ s/^(\S)/  $1/gm;

  my $errtype;
  if ($not_installed) {
    $errtype = "is not installed.";
  } else {
    $errtype = "is installed,\nbut is not an up-to-date version.";
  }

  print "\n", ("*" x 75), "\n";
  if ($required) {
    $EXIT_STATUS++;
    print "\aERROR: the required $pretty_name ${pretty_version}module $errtype";
    if ($not_installed) {
      $$summref .= "REQUIRED module missing: $pretty_name\n";
    } else {
      $$summref .= "REQUIRED module out of date: $pretty_name\n";
    }
  }
  else {
    $WARNINGS++;
    print "NOTE: the optional $pretty_name ${pretty_version}module $errtype";
    if ($not_installed) {
      $$summref .= "optional module missing: $pretty_name\n";
    } else {
      $$summref .= "optional module out of date: $pretty_name\n";
    }
  }

  print "\n\n".$desc."\n\n";
}
