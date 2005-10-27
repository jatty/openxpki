## OpenXPKI::Crypto::Backend::OpenSSL::Command::create_dsa
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::create_dsa;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

    $self->{ENC_ALG} = "aes256" if (not exists $self->{ENC_ALG});
    if (not exists $self->{RANDOM_FILE})
    {
        $self->{RANDOM_FILE} = $self->{TMP}."/.rand_${$}";
        $self->{CLEANUP}->{FILE}->{RANDOM} = $self->{RANDOM_FILE};
    }
    $self->{PARAMFILE} = $self->{TMP}."/${$}_param.pem";
    $self->{CLEANUP}->{FILE}->{PARAM} = $self->{PARAMFILE};

    ## ENGINE key: no parameters
    ## normal key: engine (optional), passwd

    my ($engine, $keyform, $passwd) = ("", "", undef);
    if ($self->{PASSWD})
    {
        ## external key generation
        $passwd = $self->{PASSWD};
        $engine = $self->{ENGINE}->get_engine() if ($self->{USE_ENGINE});
        $self->{OUTFILE} = $self->{TMP}."/${$}_dsa.pem";
        $self->{CLEANUP}->{FILE}->{OUT} = $self->{OUTFILE};
    } else {
        ## token key generation
        $engine  = $self->{ENGINE}->get_engine();
        $keyform = $self->{ENGINE}->get_keyform();
        $passwd  = $self->{ENGINE}->get_passwd();
        $self->{OUTFILE} = $self->{ENGINE}->get_keyfile();
    }

    ## check parameters

    if ($self->{ENC_ALG} ne "aes256" and
        $self->{ENC_ALG} ne "aes192" and
        $self->{ENC_ALG} ne "aes128" and
        $self->{ENC_ALG} ne "idea" and
        $self->{ENC_ALG} ne "des3" and
        $self->{ENC_ALG} ne "des")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_DSA_WRONG_ENC_ALG");
    }
    if ($self->{KEY_LENGTH} != 512 and
        $self->{KEY_LENGTH} != 768 and
        $self->{KEY_LENGTH} != 1024 and
        $self->{KEY_LENGTH} != 2048 and
        $self->{KEY_LENGTH} != 4096)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_DSA_WRONG_KEY_LENGTH");
    }
    if ($keyform ne "engine" and not defined $passwd)
    {
        ## missing passphrase
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CREATE_DSA_MISSING_PASSWD");
    }

    ## build the dsa parameter file

    my $param_command = "dsaparam";
    $param_command .= " -out ".$self->{PARAMFILE};
    $param_command .= " -engine $engine" if ($engine);
    $param_command .= " -rand ".$self->{RANDOM_FILE};
    $param_command .= " ".$self->{KEY_LENGTH};

    ## build the command

    my $command  = "gendsa";
    $command .= " -engine $engine" if ($engine);
    $command .= " -keyform $keyform" if ($keyform);
    $command .= " -".$self->{ENC_ALG};
    $command .= " -out ".$self->{OUTFILE};
    $command .= " -rand ".$self->{RANDOM_FILE};

    if (defined $passwd)
    {
        $command .= " -passout env:pwd";
	$ENV{'pwd'} = $passwd;
        $self->{CLEANUP}->{ENV}->{PWD} = "pwd";
    }

    $command .= " ".$self->{PARAMFILE};

    return [ $param_command, $command ];
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 1;
}

sub get_result
{
    my $self = shift;
    return $self->read_file ($self->{OUTFILE});
}

1;
__END__

=head1 Functions

=head2 get_command

If you want to create a key for the used engine then you have
only to specify the ENC_ALG and KEY_LENGTH. Perhaps you can specify
the RANDOM_FILE too.

If you want to create a normal key then you must specify at minimum
a passwd and perhaps USE_ENGINE if you want to use the engine of the
token too.

=over

=item * ENC_ALG

=item * KEY_LENGTH

=item * RANDOM_FILE

=item * USE_ENGINE

=item * PASSWD

=back

=head2 hide_output

returns true

=head2 key_usage

returns true

=head2 get_result

returns the new encrypted DSA key