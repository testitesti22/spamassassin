#!/usr/bin/perl -w -T

use strict;

use lib '.'; use lib 't';
use SATest; sa_t_init("get_headers");
use Mail::SpamAssassin;

use Test::More tests => 22;

##############################################

# initialize SpamAssassin
my $sa = create_saobj({'dont_copy_prefs' => 1});
$sa->init(0);
my $mail = $sa->parse( get_raw_headers()."\n\nBlah\n" );
my $msg = Mail::SpamAssassin::PerMsgStatus->new($sa, $mail);

sub try {
  my ($try, $expect) = @_;
  my $result = $msg->get($try);

  # undef might be valid in some situations, so deal with it...
  if (!defined $expect) {
    return !defined $result;
  }
  elsif (!defined $result) {
    return 0;
  }

  if ($expect eq $result) {
    return 1;
  } else {
    my $le=$expect;$le=~s/\t/\\t/gs;$le =~s/\n/\\n/gs;
    my $lr=$result;$lr=~s/\t/\\t/gs;$lr =~s/\n/\\n/gs;
    warn "try: '$try' failed! expect: '$le' got: '$lr'\n";
    return 0;
  }
}

##############################################

sub get_raw_headers {
  return q{To1: <jm@foo>
To2: jm@foo
To3: jm@foo (Foo Blah)
To4: jm@foo, jm@bar
To5: display: jm@foo (Foo Blah), jm@bar ;
To6: Foo Blah <jm@foo>
To7: "Foo Blah" <jm@foo>
To8: "'Foo Blah'" <jm@foo>
To9: "_$B!z8=6b$=$N>l$GEv$?$j!*!zEv_(B_$B$?$k!*!)$/$8!z7|>^%\%s%P!<!z_(B" <jm@foo>
To10: "Some User" <"Another User"@foo>
To11: "Some User"@foo
To12: "Some User <jm@bar>" <jm@foo>
To13: "Some User <\"Some User\"@bar>" <jm@foo>
Hdr1:    foo  
  bar
	baz 
  
To_bug5201_a: =?ISO-2022-JP?B?GyRCQjw+ZRsoQiAbJEI1V0JlGyhC?= <jm@foo>
To_bug5201_b: =?ISO-2022-JP?B?GyRCNiVHTyM3JSQlcyU1JSQlQCE8PnBKcxsoQg==?= <jm@foo>
To_bug5201_c: "joe+<blah>@example.com"
};
}

##############################################

ok(try('To1:addr', 'jm@foo'));
ok(try('To2:addr', 'jm@foo'));
ok(try('To3:addr', 'jm@foo'));
ok(try('To4:addr', 'jm@foo'));
ok(try('To5:addr', 'jm@foo'));
ok(try('To6:addr', 'jm@foo'));
ok(try('To7:addr', 'jm@foo'));
ok(try('To8:addr', 'jm@foo'));
ok(try('To9:addr', 'jm@foo'));
ok(try('To10:addr', '"Another User"@foo'));
ok(try('To10:name', 'Some User'));
ok(try('To11:addr', '"Some User"@foo'));
ok(try('To11:name', ''));
ok(try('To12:addr', 'jm@foo'));
ok(try('To12:name', 'Some User <jm@bar>'));
ok(try('To13:addr', 'jm@foo'));
ok(try('To13:name', 'Some User <"Some User"@bar>'));
ok(try('Hdr1', "foo   bar baz\n"));
ok(try('Hdr1:raw', "    foo  \n  bar\n\tbaz \n  \n"));
ok(try('To_bug5201_a:addr', 'jm@foo'));
ok(try('To_bug5201_b:addr', 'jm@foo'));
ok(try('To_bug5201_c:addr', '"joe+<blah>@example.com"'));

