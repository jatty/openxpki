use strict;
use warnings;
use English;
use lib 't/20_webserver/lib';

use OpenXPKI::Client::HTML::Mason::Test::Server;
use WWW::Mechanize;
use URI::Escape;

use Test::More;
plan tests => 17;

my $TEST_PORT = 8099;
if ($ENV{MASON_TEST_PORT}) {
    # just in case someone wants to overwrite the test webserver port
    # for some reason
    $TEST_PORT = $ENV{MASON_TEST_PORT};
}

diag("Start page and login");

my $server = OpenXPKI::Client::HTML::Mason::Test::Server->new($TEST_PORT);
$server->started_ok('Webserver start');
my $mech = WWW::Mechanize->new();

# login as anonymous
my $index_page = $mech->get("http://127.0.0.1:$TEST_PORT/")->content();
unlike($index_page, qr/I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED/, 'No connection failed error on start page') or diag "Index: $index_page";
like($index_page, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_GET_AUTHENTICATION_STACK_TITLE/, 'Correct title');

$mech->form_name('OpenXPKI');
$mech->field('auth_stack', 'Anonymous');
$mech->click('submit');
is($mech->response->code(), '200', 'HTTP 200 OK received');
like($mech->response->content, qr/meta http-equiv="refresh"/, 'Redirect page received');

my ($session_id) = ($mech->response->content =~ m{__session_id=([0-9a-f]+)}xms);
if ($ENV{DEBUG}) {
    diag "Session ID: $session_id";
}

# go to redirect page
$mech->get("http://127.0.0.1:$TEST_PORT/service/index.html?__session_id=$session_id&__role=");
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_TITLE/, 'Correct title');

# SPKAC
ok($mech->follow_link(text => 'I18N_OPENXPKI_HTML_MENU_REQUEST', n => '1'), 'Followed link');
ok($mech->follow_link(text => 'I18N_OPENXPKI_HTML_MENU_CERTIFICATE_SIGNING_REQUEST', n => '1'), 'Followed link');
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_CREATE_CSR_GET_ROLE_TITLE/, 'Role selection on first page');
$mech->form_name('OpenXPKI');
$mech->field('role', 'Web Server');
$mech->click('__submit');
like($mech->response->content, qr/18N_OPENXPKI_CLIENT_HTML_MASON_CREATE_CSR_GET_SUBJECT_STYLE_TITLE/, 'Style selection');

$mech->form_name('OpenXPKI');
$mech->field('subject_style', '00_tls_basic_style');
$mech->field('role', 'Web Server');
$mech->click('__submit');
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_CREATE_CSR_GET_KEYGEN_TITLE/, 'Key generation method');

$mech->form_name('OpenXPKI');
$mech->field('keygen', 'SPKAC');
$mech->field('subject_style', '00_tls_basic_style');
$mech->field('role', 'Web Server');
$mech->click('__submit');
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_CREATE_CSR_GET_SUBJECT_TITLE/, 'Subject');

$mech->form_name('OpenXPKI');
$mech->field('cert_subject_hostname', 'example1.example.com');
$mech->field('cert_subject_port', '1234');
$mech->field('keygen', 'SPKAC');
$mech->field('subject_style', '00_tls_basic_style');
$mech->field('role', 'Web Server');
$mech->click('__submit');
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_CREATE_CSR_GET_INFO_TITLE/, 'Additional information');

$mech->form_name('OpenXPKI');
$mech->field('additional_info_phone', '1234');
$mech->field('keygen', 'SPKAC');
$mech->field('additional_info_comment', 'comment');
$mech->field('cert_subject_hostname', 'example1.example.com');
$mech->field('cert_subject_port', '1234');
$mech->field('subject_style', '00_tls_basic_style');
$mech->field('role', 'Web Server');
$mech->click('__submit');
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_CREATE_CSR_GET_SPKAC_TITLE/, 'SPKAC');

$mech->form_name('OpenXPKI');
$mech->field('additional_info_phone', '1234');
$mech->field('keygen', 'SPKAC');
$mech->field('cert_subject_hostname', 'example1.example.com');
$mech->field('additional_info_comment', 'comment');
$mech->field('role', 'Web Server');
$mech->field('cert_subject_port', '1234');
$mech->field('subject_style', '00_tls_basic_style');
$mech->field('spkac', 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAuFFVwc++peZNaZvY+FBcmutydLJ25gXuqpCV8FdQyCyUGl5mEUSBJmp0T4TvskHHhTKu8duUvs+8LhlPXs+DyPVyCgRAvm7WzzGV9oeC6xt+cM4JYpgeQslaoSg4rEm9zDr24lQaAfLEwqNmK/MBsU6E/TR0INpaex+cnN9v1u0CAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAFBT/SJFfRuQs+Sp2j0Bj0Fn7vhXZdmhzb8KJ4ZZSrqmUYjQtK8qZJEujce7QJfC5Uk/GjgHjPLG2Mp0+O8y0MQyhBMlOzYLytseZjz5UsdeRMYkqFwpieeT9dR0WDrj53sZpr7UQoVTO3J9+pwGsDlGE91x7+VeBlOwqfR6a8Nn');
$mech->click('__submit');
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_CREATE_CSR_RECEIPT_CONFIRMATION_TITLE/, 'CSR received');
like($mech->response->content, qr/I18N_OPENXPKI_PROFILE_TLS_SERVER/, 'TLS server profile');
like($mech->response->content, qr/CN=example1.example.com:1234,DC=Test\ Deployment,DC=OpenXPKI,DC=org/, 'Certificate subject');

