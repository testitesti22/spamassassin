# <@LICENSE>
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to you under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at:
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

=head1 NAME

Mail::SpamAssassin::Plugin::Shortcircuit - short-circuit evaluation for certain rules

=head1 SYNOPSIS

  loadplugin     Mail::SpamAssassin::Plugin::Shortcircuit

  report Content analysis details:   (_SCORE_ points, _REQD_ required, s/c _SCTYPE_)

  add_header all Status "_YESNO_, score=_SCORE_ required=_REQD_ tests=_TESTS_ shortcircuit=_SCTYPE_ autolearn=_AUTOLEARN_ version=_VERSION_"

=head1 DESCRIPTION

This plugin implements simple, test-based shortcircuiting.  Shortcircuiting a
test will force all other pending rules to be skipped, if that test is hit.

Recomended usage is to use C<priority> to set rules with strong S/O values (ie.
1.0) to be run first, and make instant spam or ham classification based on
that.

=cut

package Mail::SpamAssassin::Plugin::Shortcircuit;

use Mail::SpamAssassin::Plugin;
use Mail::SpamAssassin::Logger;
use strict;
use warnings;
use bytes;

use vars qw(@ISA);
@ISA = qw(Mail::SpamAssassin::Plugin);

sub new {
  my $class = shift;
  my $mailsaobject = shift;

  $class = ref($class) || $class;
  my $self = $class->SUPER::new($mailsaobject);
  bless ($self, $class);

  $self->set_config($mailsaobject->{conf});

  return $self;
}

sub set_config {
  my($self, $conf) = @_;
  my @cmds = ();

=head1 CONFIGURATION SETTINGS

The following configuration settings are used to control shortcircuiting:

=item shortcircuit SYMBOLIC_TEST_NAME {ham|spam|on|off}

Shortcircuiting a test will force all other pending rules to be skipped, if
that test is hit.

Recomended usage is to use C<priority> to set rules with strong S/O values (ie.
1.0) to be run first, and make instant spam or ham classification based on
that.

To override a test that uses shortcircuiting, you can set the classification
type to C<off>.

=over 4

=item on

Shortcircuits the rest of the tests, but does not make a strict classification
of spam or ham.  Rather, it uses the default score for the rule being
shortcircuited.  This would allow you, for example, to define a rule such as 
  
=over 4

  body TEST /test/
  describe TEST test rule that scores barely over spam threshold
  score TEST 5.5
  priority TEST -100
  shortcircuit TEST on

=back

The result of a message hitting the above rule would be a final score of 5.5,
as opposed to 100 (default) if it were classified as spam.

=item off

Disables shortcircuiting on said rule.

=item spam

Shortcircuit the rule using a set of defaults; override the default score of
this rule with the score from C<shortcircuit_spam_score>, set the
C<noautolearn> tflag, and set priority to C<-100>.  In other words,
equivalent to:

=over 4

  shortcircuit TEST on
  priority TEST -100
  score TEST 100
  tflags TEST noautolearn

=back

=item ham

Shortcircuit the rule using a set of defaults; override the default score of
this rule with the score from C<shortcircuit_ham_score>, set the C<noautolearn>
and C<nice> tflags, and set priority to C<-100>.   In other words, equivalent
to:

=over 4

  shortcircuit TEST on
  priority TEST -100
  score TEST -100
  tflags TEST noautolearn nice

=back

=back

=cut

  push (@cmds, {
    setting => 'shortcircuit',
    code => sub {
      my ($self, $key, $value, $line) = @_;
      my ($rule,$type);
      unless (defined $value && $value !~ /^$/) {
        return $Mail::SpamAssassin::Conf::MISSING_REQUIRED_VALUE;
      }
      if ($value =~ /^(\S+)\s+(\S+)$/) {
        $rule=$1;
        $type=$2;
      } else {
        return $Mail::SpamAssassin::Conf::INVALID_VALUE;
      }

      if ($type =~ m/^(?:spam|ham)$/) {
        dbg("shortcircuit: adding $rule using abbreviation $type");

        # set the defaults:
        $self->{shortcircuit}->{$rule} = $type;
        $self->{priority}->{$rule} = -100;

        my $tf = $self->{tflags}->{$rule};
        $self->{tflags}->{$rule} = ($tf ? $tf." " : "") .
                ($type eq 'ham' ? "nice " : "") .
                "noautolearn";
      }
      elsif ($type eq "on") {
        $self->{shortcircuit}->{$rule} = "on";
      }
      elsif ($type eq "off") {
        delete $self->{shortcircuit}->{$rule};
      }
      else {
        return $Mail::SpamAssassin::Conf::INVALID_VALUE;
      }
    }
  });

=item shortcircuit_spam_score n.nn (default: 100)

When shortcircuit is used on a rule, and the shortcircuit classification type
is set to C<spam>, this value should be applied in place of the default score
for that rule.

=cut

  push (@cmds, {
    setting => 'shortcircuit_spam_score',
    default => 100,
    type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
  });

=item shortcircuit_ham_score n.nn (default: -100)

When shortcircuit is used on a rule, and the shortcircuit classification type
is set to C<ham>, this value should be applied in place of the default score
for that rule.

=cut

  push (@cmds, {
    setting => 'shortcircuit_ham_score',
    default => -100,
    type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
  });

  $conf->{parser}->register_commands(\@cmds);
}

=head1 TAGS

The following tags are added to the set available for use in reports, headers
etc.:

  _SC_              shortcircuit status (classification and rule name)
  _SCRULE_          rulename that caused the shortcircuit 
  _SCTYPE_          shortcircuit classification ("spam", "ham", "default", "none")

=cut

sub hit_rule {
  my ($self, $params) = @_;

  my $scan = $params->{permsgstatus};
  my $rule = $params->{rulename};

  my $sctype = $scan->{conf}->{shortcircuit}->{$rule};
  return unless $sctype;

  my $conf = $scan->{conf};
  my $score = $params->{score};

  $scan->{shortcircuit_rule} = $rule;
  if ($sctype eq 'on') {  # guess by rule score
    dbg("shortcircuit: s/c due to $rule, using score of $score");
    $scan->{shortcircuit_type} = ($score < 0 ? 'ham' : 'spam');
  }
  else {
    $scan->{shortcircuit_type} = $sctype;
    if ($sctype eq 'ham') {
      $score = $conf->{shortcircuit_ham_score};
    } else {
      $score = $conf->{shortcircuit_spam_score};
    }
    dbg("shortcircuit: s/c $sctype due to $rule, using score of $score");
  }

  # I don't think we really need to do these...
  # undef $scan->{test_names_hit};       # reset rule hits
  # $scan->{score}                = 0;   # reset score
  # $scan->{tag_data}->{REPORT}   = '';  # reset tag data
  # $scan->{tag_data}->{SUMMARY}  = '';  # reset tag data
}

sub parsed_metadata {
  my ($self, $params) = @_;
  my $scan = $params->{permsgstatus};

  $scan->set_tag ('SC', sub {
      my $rule = $scan->{shortcircuit_rule};
      my $type = $scan->{shortcircuit_type};
      return "$rule ($type)" if ($rule);
      return "no";
    });

  $scan->set_tag ('SCRULE', sub {
      my $rule = $scan->{shortcircuit_rule};
      return ($rule || "none");
    });

  $scan->set_tag ('SCTYPE', sub {
      my $type = $scan->{shortcircuit_type};
      return ($type || "no");
    });

  $scan->set_spamd_result_item (sub {
          "shortcircuit=".$scan->get_tag("SCTYPE");
        }); 
}

sub have_shortcircuited {
  my ($self, $params) = @_;
  return (exists $params->{permsgstatus}->{shortcircuit_type}) ? 1 : 0;
}

1;

=head1 SEE ALSO

C<http://issues.apache.org/SpamAssassin/show_bug.cgi?id=3109>

=cut
