package StackTrace::Auto;
use Moo::Role;
use Sub::Quote ();
use MooX::Types::MooseLike::Base qw(Str ArrayRef);
use Module::Runtime 'require_module';

# ABSTRACT: a role for generating stack traces during instantiation

=head1 SYNOPSIS

First, include StackTrace::Auto in a Moose class...

  package Some::Class;
  use Moose;
  with 'StackTrace::Auto';

...then create an object of that class...

  my $obj = Some::Class->new;

...and now you have a stack trace for the object's creation.

  print $obj->stack_trace->as_string;

=attr stack_trace

This attribute will contain an object representing the stack at the point when
the error was generated and thrown.  It must be an object performing the
C<as_string> method.

=attr stack_trace_class

This attribute may be provided to use an alternate class for stack traces.  The
default is L<Devel::StackTrace|Devel::StackTrace>.

In general, you will not need to think about this attribute.

=cut

has stack_trace => (
  is       => 'ro',
  isa      => Sub::Quote::quote_sub(q{
    require Scalar::Util;
    die "stack_trace must be have an 'as_string' method!" unless
       Scalar::Util::blessed($_[0]) && $_[0]->can('as_string')
  }),
  builder  => '_build_stack_trace',
  init_arg => undef,
);

has stack_trace_class => (
  is      => 'ro',
  isa     => Str,
  coerce  => Sub::Quote::quote_sub(q{
    use Module::Runtime 'require_module';
    require_module($_[0]);
    $_[0];
  }),
  lazy    => 1,
  builder => '_build_stack_trace_class',
);

=attr stack_trace_args

This attribute is an arrayref of arguments to pass when building the stack
trace.  In general, you will not need to think about it.

=cut

has stack_trace_args => (
  is      => 'ro',
  isa     => ArrayRef,
  lazy    => 1,
  builder => '_build_stack_trace_args',
);

sub _build_stack_trace_class {
  require_module('Devel::StackTrace'); # Moo bug
  return 'Devel::StackTrace';
}

sub _build_stack_trace_args {
  my ($self) = @_;
  my $found_mark = 0;
  my $uplevel = 3; # number of *raw* frames to go up after we found the marker
  return [
    frame_filter => sub {
      my ($raw) = @_;
      if ($found_mark) {
          return 1 unless $uplevel;
          return !$uplevel--;
      }
      else {
        $found_mark = scalar $raw->{caller}->[3] =~ /__stack_marker$/;
        return 0;
    }
    },
  ];
}

sub _build_stack_trace {
  my ($self) = @_;
  return $self->stack_trace_class->new(
    @{ $self->stack_trace_args },
  );
}

around new => sub {
  my $next = shift;
  my $self = shift;
  return $self->__stack_marker($next, @_);
};

sub __stack_marker {
  my $self = shift;
  my $next = shift;
  return $self->$next(@_);
}

no Moo::Role;
1;
