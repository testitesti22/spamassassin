#!/usr/bin/perl -T

use lib '.'; use lib 't';
use SATest; sa_t_init("all_modules");

use Test::More;
plan tests => 6;

# ---------------------------------------------------------------------------

my $plugins = '';

if (eval { require BSD::Resource; }) {
    $plugins .= "loadplugin Mail::SpamAssassin::Plugin::ResourceLimits\n"
}

tstpre ("
  loadplugin Mail::SpamAssassin::Plugin::RelayCountry
  loadplugin Mail::SpamAssassin::Plugin::URIDNSBL
  loadplugin Mail::SpamAssassin::Plugin::SPF
  loadplugin Mail::SpamAssassin::Plugin::DCC
  loadplugin Mail::SpamAssassin::Plugin::Pyzor
  loadplugin Mail::SpamAssassin::Plugin::Razor2
  loadplugin Mail::SpamAssassin::Plugin::SpamCop
  loadplugin Mail::SpamAssassin::Plugin::AntiVirus
  loadplugin Mail::SpamAssassin::Plugin::AWL
  loadplugin Mail::SpamAssassin::Plugin::AutoLearnThreshold
  loadplugin Mail::SpamAssassin::Plugin::TextCat
  loadplugin Mail::SpamAssassin::Plugin::AccessDB
  loadplugin Mail::SpamAssassin::Plugin::WhiteListSubject
  loadplugin Mail::SpamAssassin::Plugin::MIMEHeader
  loadplugin Mail::SpamAssassin::Plugin::ReplaceTags
  loadplugin Mail::SpamAssassin::Plugin::DKIM
  loadplugin Mail::SpamAssassin::Plugin::Check
  loadplugin Mail::SpamAssassin::Plugin::HTTPSMismatch
  loadplugin Mail::SpamAssassin::Plugin::URIDetail
  loadplugin Mail::SpamAssassin::Plugin::Shortcircuit
  loadplugin Mail::SpamAssassin::Plugin::Bayes
  loadplugin Mail::SpamAssassin::Plugin::BodyEval
  loadplugin Mail::SpamAssassin::Plugin::DNSEval
  loadplugin Mail::SpamAssassin::Plugin::HTMLEval
  loadplugin Mail::SpamAssassin::Plugin::HeaderEval
  loadplugin Mail::SpamAssassin::Plugin::MIMEEval
  loadplugin Mail::SpamAssassin::Plugin::RelayEval
  loadplugin Mail::SpamAssassin::Plugin::URIEval
  loadplugin Mail::SpamAssassin::Plugin::WLBLEval
  loadplugin Mail::SpamAssassin::Plugin::VBounce
  loadplugin Mail::SpamAssassin::Plugin::Rule2XSBody
  loadplugin Mail::SpamAssassin::Plugin::ASN
  loadplugin Mail::SpamAssassin::Plugin::ImageInfo
  loadplugin Mail::SpamAssassin::Plugin::PhishTag
  loadplugin Mail::SpamAssassin::Plugin::FreeMail
  loadplugin Mail::SpamAssassin::Plugin::AskDNS
  loadplugin Mail::SpamAssassin::Plugin::TxRep
  loadplugin Mail::SpamAssassin::Plugin::URILocalBL
  loadplugin Mail::SpamAssassin::Plugin::PDFInfo
  loadplugin Mail::SpamAssassin::Plugin::HashBL
  loadplugin Mail::SpamAssassin::Plugin::FromNameSpoof
  loadplugin Mail::SpamAssassin::Plugin::Phishing
  loadplugin Mail::SpamAssassin::Plugin::AuthRes
  loadplugin Mail::SpamAssassin::Plugin::Esp
  loadplugin Mail::SpamAssassin::Plugin::ExtractText
  $plugins
");

tstprefs("
  use_bayes 1
  spf_timeout 2
  use_razor2 1
  razor_timeout 2
  razor_fork 1
  use_dcc 1
  dcc_timeout 2
  use_pyzor 1
  pyzor_timeout 2
  pyzor_fork 1
");

%patterns = (
        q{ timing: total }, 'ok',
            );

%anti_patterns = (
        q{ Insecure dependency }, 'tainted',
        q{ Syntax error }, 'syntax',
        q{ Use of uninitialized }, 'uninitialized',
        q{ warn: }, 'warn',
        q{ SpamAssassin failed to parse line }, 'parse',
            );

if (conf_bool('run_net_tests')) {
    # sometimes trips on URIBL_BLOCKED, ignore..
    sarun ("-D -t < data/nice/001 2>&1 | grep -v dns_block_rule", \&patterns_run_cb);
    ok_all_patterns();
} else {
    sarun ("-D -L -t < data/nice/001 2>&1", \&patterns_run_cb);
    ok_all_patterns();
}
