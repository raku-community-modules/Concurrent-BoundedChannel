unit module Concurrent::BoundedChannel;

class X::Concurrent::BoundedChannel::LimitOutOfBounds is Exception {
    has $.limit is required;

    method message {
        "Got limit $!limit, but limit can't be negative.";
    }
}

class BoundedChannel is Channel is export {
    has $!limit;
    has $!bclock;
    has $!sendwait;
    has $!sendwaiters;
    has $!receivewait;
    has $!receivewaiters;
    has $!count;
    has $!closed;

    submethod BUILD (Int :$limit is required) {
        die X::Concurrent::BoundedChannel::LimitOutOfBounds.new(limit=>$limit) if $limit < 0;
        $!limit          = $limit;
        $!bclock         = Lock.new;
        $!sendwait       = $!bclock.condition;
        $!sendwaiters    = 0;
        $!receivewait    = $!bclock.condition;
        $!receivewaiters = 0;
        $!count          = 0;
        $!closed         = False;
    }

    method send(Channel:D: \item) {
        my $z;
        my $p;
        $!bclock.lock;

        while $!count >= $!limit && ! $!closed {
            last if $!limit == 0 && $!receivewaiters > 0;
            $!sendwaiters++;
            $!sendwait.wait;
            $!sendwaiters--;
        }

        $!receivewait.signal;

        $!count++;
        try {
            $z:=callsame;
            CATCH {
                $!bclock.unlock;
                .throw;
            }
        }
        $!bclock.unlock;
        $z
    }

    method offer(Channel:D: \item) {
        $!bclock.lock;
        if ($!count >= $!limit && $!limit != 0)
          || ($!limit == 0 && $!receivewaiters == 0) {
            $!bclock.unlock;
            return Nil;
        }

        $!receivewait.signal;

        self.Channel::send(item);
        $!count++;
        $!bclock.unlock;
        item
    }

    method receive(Channel:D:) {
        my $x;
        $!bclock.lock;

        $!sendwait.signal;

        while $!count == 0 && !$!closed {
            $!receivewaiters++;
            $!receivewait.wait;
            $!receivewaiters--;
        }
        try {
            $x:=callsame;
            CATCH {
                $!bclock.unlock;
                .throw;
            }
        }
        $!count--;
        $!bclock.unlock;
        $x
    }

    method poll(Channel:D:) {
        my $x;
        $!bclock.lock;
        $!sendwait.signal;
        if $!limit == 0 && $!sendwaiters > 0 {
            $!receivewaiters++;
            $!receivewait.wait;
            $!receivewaiters--;
        }
        try {
            $x := callsame;
            CATCH {
                $!bclock.unlock;
                .throw;
            }
        }
        $!count-- with $x;


        $!bclock.unlock;
        $x
    }

    method close(Channel:D:) {
        $!bclock.lock;
        $!closed=True;
        $!receivewait.signal_all;
        $!sendwait.signal_all;
        my $x := callsame;
        $!bclock.unlock;
        $x
    }

    method fail(Channel:D: $error) {
        $!bclock.lock;
        $!closed=True;
        $!receivewait.signal_all;
        $!sendwait.signal_all;
        my $x := callsame;
        $!bclock.unlock;
        $x
    }
}

=begin pod

=head1 NAME

Concurrent::BoundedChannel - A Channel with limited number of elements

=head1 SYNOPSIS

=begin code :lang<raku>

use Concurrent::BoundedChannel;

# Construct a BoundedChannel with 20 entries
my $bc = BoundedChannel.new(limit=>20);

$bc.send('x');          # will block if $bc is full
my $val = $bc.receive;  # returns 'x'

my $oval=$bc.offer('y');  # non-blocking send - returns the offered value
                          # ('y' in this case), or Nil if $bc is full

$val=$bc.poll;

$bc.close;

# OR

$bc.fail(X::SomeException.new);

=end code

=head1 DESCRIPTION

The normal Raku L<C<Channel>|https://docs.raku.org/type/Channel> is an
unbounded queue.  This subclass offers an alternative with size limits.

=head2 OVERVIEW

The normal Raku C<Channel> class is an unbounded queue.  It will
grow indefinitely as long as values are fed in and not removed.

In some cases that may not be desirable.  C<BoundedChannel> is a
subclass of C<Channel> with a set size limit.  It behaves just
like C<Channel>, with some exceptions:

=item The send method will block, if the Channel is already
populated with the maximum number of elements.
=item There is a new C<offer> method, which is the send equivalent
of poll - i.e. a non-blocking send.  It returns C<Nil> if the
Channel is full, otherwise it returns the offered value.
=item If one or more threads is blocking on a send, and the
channel is closed, those send calls will throw exceptions, just
as if send had been called on a closed normal Channel.

The C<fail> method is an exception to the C<BoundedChannel> limit.
If the BoundedChannel is full, and C<fail> is called, the exception
specified will still be placed at the end of the queue, even if
that would violate the limit.  This was deemed acceptable to avoid
having a fail contend with blocking send calls.

=head3 BoundedChannel

The constructor takes one parameter (limit), which can be anwhere
from zero to as large as you wish.  A zero limit C<BoundedChannel>
behaves similar to a UNIX pipe - a send will block unless a receive
is already waiting for value, and a receive will block unless a
send is already waiting.

=head1 AUTHOR

gotoexit

=head1 COPYRIGHT AND LICENSE

Copyright 2016 - 2017 gotoexit

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
