package Mojolicious::Plugin::Config;
use Mojo::Base 'Mojolicious::Plugin';

use File::Basename 'basename';
use File::Spec::Functions 'file_name_is_absolute';
use Mojo::Util 'decamelize';

sub load {
  my ($self, $file, $conf, $app) = @_;
  $app->log->debug(qq{Reading config file "$file".});

  # Slurp UTF-8 file
  open my $handle, "<:encoding(UTF-8)", $file
    or die qq{Couldn't open config file "$file": $!};
  my $content = do { local $/; <$handle> };

  # Process
  return $self->parse($content, $file, $conf, $app);
}

sub parse {
  my ($self, $content, $file, $conf, $app) = @_;

  # Run Perl code
  my $config = eval 'package Mojolicious::Plugin::Config::Sandbox;'
    . "no warnings; sub app { \$app }; use Mojo::Base -strict; $content";
  die qq{Couldn't load configuration from file "$file": $@} if !$config && $@;
  die qq{Config file "$file" did not return a hash reference.\n}
    unless ref $config eq 'HASH';

  return $config;
}

sub register {
  my ($self, $app, $conf) = @_;

  # Config file
  my $file = $conf->{file} || $ENV{MOJO_CONFIG};
  unless ($file) {

    # Class or executable
    $file
      = $ENV{MOJO_APP} ? decamelize($ENV{MOJO_APP}) : basename($ENV{MOJO_EXE});

    # Replace ".pl" and ".t" with default extension
    $file =~ s/\.(?:pl|t)$//i;
    $file .= '.' . ($conf->{ext} || 'conf');
  }

  # Mode specific config file
  my $mode = $file =~ /^(.*)\.([^.]+)$/ ? join('.', $1, $app->mode, $2) : '';

  # Absolute paths
  my $home = $app->home;
  $file = $home->rel_file($file) unless file_name_is_absolute $file;
  $mode = $home->rel_file($mode) if $mode && !file_name_is_absolute $mode;
  $mode = undef unless $mode && -e $mode;

  # Read config file
  my $config = {};
  if (-e $file) { $config = $self->load($file, $conf, $app) }

  # Check for default and mode specific config file
  elsif (!$conf->{default} && !$mode) {
    die qq{Config file "$file" missing, maybe you need to create it?\n};
  }

  # Merge everything
  $config = {%$config, %{$self->load($mode, $conf, $app)}} if $mode;
  $config = {%{$conf->{default}}, %$config} if $conf->{default};
  my $current = $app->defaults(config => $app->config)->config;
  %$current = (%$current, %$config);

  return $current;
}

1;

=head1 NAME

Mojolicious::Plugin::Config - Perl-ish configuration plugin

=head1 SYNOPSIS

  # myapp.conf
  {
    foo       => "bar",
    music_dir => app->home->rel_dir('music')
  };

  # Mojolicious
  my $config = $self->plugin('Config');

  # Mojolicious::Lite
  my $config = plugin 'Config';

  # foo.html.ep
  %= $config->{foo}

  # The configuration is available application wide
  my $config = app->config;

  # Everything can be customized with options
  my $config = plugin Config => {file => '/etc/myapp.stuff'};

=head1 DESCRIPTION

L<Mojolicious::Plugin::Config> is a Perl-ish configuration plugin.

The application object can be accessed via C<$app> or the C<app> function,
L<strict>, L<warnings> and Perl 5.10 features are automatically enabled. You
can extend the normal configuration file C<myapp.conf> with C<mode> specific
ones like C<myapp.$mode.conf>. A default configuration filename will be
generated by decamelizing the application class with
L<Mojo::Util/"decamelize"> or from the application filename.

The code of this plugin is a good example for learning to build new plugins,
you're welcome to fork it.

=head1 OPTIONS

L<Mojolicious::Plugin::Config> supports the following options.

=head2 C<default>

  # Mojolicious::Lite
  plugin Config => {default => {foo => 'bar'}};

Default configuration, making configuration files optional.

=head2 C<ext>

  # Mojolicious::Lite
  plugin Config => {ext => 'stuff'};

File extension for generated configuration filenames, defaults to C<conf>.

=head2 C<file>

  # Mojolicious::Lite
  plugin Config => {file => 'myapp.conf'};
  plugin Config => {file => '/etc/foo.stuff'};

Full path to configuration file, defaults to the value of the C<MOJO_CONFIG>
environment variable or C<myapp.conf> in the application home directory.

=head1 METHODS

L<Mojolicious::Plugin::Config> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<load>

  $plugin->load($file, $conf, $app);

Loads configuration file and passes the content to C<parse>.

  sub load {
    my ($self, $file, $conf, $app) = @_;
    ...
    return $self->parse($content, $file, $conf, $app);
  }

=head2 C<parse>

  $plugin->parse($content, $file, $conf, $app);

Parse configuration file.

  sub parse {
    my ($self, $content, $file, $conf, $app) = @_;
    ...
    return $hash;
  }

=head2 C<register>

  my $config = $plugin->register(Mojolicious->new);
  my $config = $plugin->register(Mojolicious->new, {file => '/etc/app.conf'});

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
