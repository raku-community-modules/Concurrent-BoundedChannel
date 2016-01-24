# Concurrent::BoundedChannel

A standard Perl 6 `Iterator` should only be consumed from one thread at a time.
`Concurrent::Iterator` allows any Iterable to be iterated concurrently.

## Synopsis

    use Concurrent::BoundedChannel;

    # Construct a BoundedChannel with 20 entries
    my $bc = BoundedChannel.new(limit=>5);

    $bc.send('x');          # will block if $bc is full
    my $val = $bc.receive;  # returns 'x'

    my $oval=$bc.offer('y');  # non-blocking send - returns the offered value
                              # ('y' in this case), or Nil if $bc is full

    $val=$bc.poll;

## Overview

The normal Perl 6 Channel class is an unbounded queue.  It will grow
indefinitely as long as values are fed in and not removed.  In some cases
that may not be desirable.  BoundedChannel is a subclass of Channel
with a set size limit.  It behaves just like Channel, with two exceptions:

* The send method will block, if the Channel is already populated with
the maximum number of elements.
* There is a new offer method, which is the send equivalent of poll - i.e. a
non-blocking send.  It returns Nil if the Channel is full, otherwise it
returns the offered value.

## BoundedChannel

The constructor takes one parameter (limit), which can be anwhere from
zero to as large as you wish.  A zero limit BoundedChannel behaves similar
to a UNIX pipe - a send will block unless a receive is already waiting for
value, and a receive will block unless a send is already waiting.
