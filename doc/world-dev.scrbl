#lang scribble/base

@(require (for-label racket)
          (for-label "world-dev-exports.rkt")
          (for-label "ffi-exports.rkt")
          scribble/manual)

@title[#:tag "world-dev"]{World Development}

This API provides development tools to extend the world infrastructure and
create new configurations. Using the @secref["ffi"], this allows for external
javascript libraries to be installed as configurations in world programs.

@;-----------------------------------------------------------------------------

@section{Big Bang Info}

@defstruct[bb-info ([toplevel-node js-object?]
                    [change-world ((any/c . -> . any/c) . -> . void?)]
                    [call-with-pausing ((-> any/c) . -> . any/c)]
		    [unsafe-change-world ((any/c . -> . any/c) . -> . void?)])
                   #:inspector #f]{

The @racket[bb-info] struct is passed to procedures that need special access to
big bang internals. An instance of the @racket[bb-info] struct provides the
developer with access to the dom node representing the big bang and the ability
to change the world and pause the big bang.

It is important to note that, while a big bang is running, blocking calls (such
as @racket[js-big-bang]) and @racket[call/cc] cannot be called (if one is
called, an @racket[exn:fail] exception will be thrown). This is to prevent the
world from changing in unexpected ways while the a blocking call executes.
However, when a big bang is paused, such calls can be made.

@itemize[

 @item{The @racket[toplevel-node] field contains the toplevel dom node that
  represents the entire big bang on the page. For instance, any events
  listeners attached to the @racket[toplevel-node] will fire whenever the big
  bang has focus and the event occurs.}

 @item{The @racket[change-world] field contains a procedure that consumes a
  world to world procedure as an argument. It pauses the world (as with
  @racket[call-with-pausing]), then applies the procedure to the current world,
  then restarts the big bang, updates the world with the value the procedure
  returned, and finally returns @|void-const|. The @racket[change-world]
  procedure can be defined in terms of the other fields as
  @racketblock[
(define (change-world world-to-world)
  (unsafe-change-world
   (lambda (w) (call-with-pausing
                (lambda () (world-to-world w))))))
  ]
  This functionality allows the developer to change the value of the world
  safely and with a succinct and intuitive syntax without needing to worry
  about the end user making blocking calls.}

 @item{The @racket[call-with-pausing] procedure takes a thunk as an argument.
  It first pauses the big bang, thereby once again allowing blocking calls and
  @racket[call/cc]. Once the world is paused, it calls the thunk. When the
  thunk returns, it restarts the big bang and returns whatever value the thunk
  returned.

  If this procedure is called while the world is already paused, it will simply
  call the thunk and return whatever value the thunk returns. In this case it
  will ignore the big bang completely.

  Note that a the world cannot be changed (with either @racket[change-world] or
  @racket[unsafe-change-world]) while the world is paused. Any attempt to do so
  will result in an @racket[exn:fail] exception being thrown.}
 
 @item{The @racket[unsafe-change-world] field contains a procedure that
  consumes a world to world function as an argument. It applies the function to
  the current world, and then updates the world to reflect the return value of
  this application. This field makes these calls without first pausing the
  world. This means it will run faster than @racket[change-world], but if the
  world to world function attempts to make a blocking call it will error.}

]

Calling any of the procedures after the big bang has ended will result in an
@racket[exn:fail] exception being thrown.}

@;-----------------------------------------------------------------------------

@section{World Configurations}

World configurations are the basic unit that big-bang uses to recognize stimuli
and report them to the end user. For example, @racket[on-tick] is a world
configuration.

@defproc[(make-world-config [startup (bb-info? . -> . any/c)]
                            [shutdown (any/c . -> . any/c)]
                            [pauser (or/c #f (any/c . -> . any/c)) #f]
                            [restarter (or/c #f (bb-info? any/c . -> . any/c))
                                       #f])
         world-config?]{

Creates a new world configuration that can be passed to @racket[js-big-bang].
When the big bang starts, @racket[startup] will be applied to a
@racket[bb-info] whose values are specific to that paricular big bang. The
@racketidfont{world-config}'s shutdown argument will be set to the return value
of this application.

When the big bang ends (either from @racket[stop-when] or due to an exception
being thrown), @racket[startup] will be applied to the
@racketidfont{world-config}'s current shutdown argument.

When a big bang is paused, it will apply @racket[pauser] to th current shutdown
argument and then set the return value of the application to be the current
restart argument. If @racket[pauser] is @racket[#f], the big bang will instead
call @racket[shutdown] instead whenever the big bang needs to be paused.

When a big bang restarts after being paused, it will apply @racket[restarter]
to the same @racket[bb-info] that was passed to @racket[restarter] and the
current restart argument and then set the return value of this application to
be the current shutdown argument. If @racket[restarter] is @racket[#f], then,
whenever @racket[restarter] would be called, the big bang will instead call
@racket[startup] with the same @racket[bb-info], but completely ignore the
restart argument.

It is important to guarantee that the @racketidfont{world-config} will never
attempt to change the world while it is paused or after it is shut down. Also,
it should guarantee that the world is paused (with @racket[bb-info]'s
@racket[change-world] or @racket[call-with-pausing] field) before calling any
user-defined procedure that could potentially be blocking.}

@;-----------------------------------------------------------------------------

@section{Effects}

Some actions are single events, not ongoing ones, and cannot be reversed once
executed. For example, sending an an emailcannot be reversed since the sender
cannot cause the recipient to un-receive the message (or un-read it if it is
already read). Effects are designed to create an interface whereby a world
program can perform such actions while explicitly designating them as
effectful, and thereby non-reversable.

Effects are represented as special @tech{structure type}s. Effect types can be
defined in a very similar way to structs, but they are also given an
implementation to be called with the world is updated with the effect. This
implementation should be what actually performs the effectful operation.

@subsection{Effect Types}

@defproc[(make-effect-type [name symbol?]
                           [super-type effect-type?]
                           [field-cnt exact-nonnegative-integer?]
                           [implementation procedure?]
                           [guard (or/c procedure? #f) #f])
         (values effect-type?
                 struct-constructor-procedure?
                 struct-predicate-procedure?
                 struct-accessor-procedure?
                 struct-mutator-procedure?)]{

Creates a new effect type. The @racket[name] argument is used as the type name.
If @racket[super-type] is not @racket[#f], the resulting type is a subtype of
the corresponding effect type.

The resulting type has @racket[field-cnt] fields (in addition to any fields
from @racket[super-type]), and @racket[field-cnt] constructor arguments (in
addition to any from @racket[super-type]). The total field count (including
@racket[super-type] fields) cannot exceed 32768.

The @racket[implementation] argument is a procedure that takes @math{n}
arguments where @math{n} is the total number of fields in the new type (i.e.
@racket[field-cnt] plus the number of fields implied by @racket[super-type]).
When the world is updated with an instance of the new type as an effect,
@racket[implementation] will be applied with the fields as arguments and its
return value will be ignored. This procedure application is expected to be what
performs the effectful action. If @racket[super-type] is not @racket[#f], then
@racket[implementation] will override the implementation of
@racket[super-type], and only the subtype's implementation will be called.

The @racket[guard] argument is treated the same way as the @racket[guard]
argument in @racket[make-struct-type] for all purposes since an effect type is
just a special structure type.

The result of @racket[make-effect-type] is five values:

@itemize[

 @item{an effect type descriptor (which is also a @tech{structure type
  descriptor}),}

 @item{a @tech{constructor} procedure,}

 @item{a @tech{predicate} procedure,}
 
 @item{an @tech{accessor} procedure, which consumes a structure and a field
  index between @math{0} (inclusive) and @racket[init-field-cnt] (exclusive),
  and}

 @item{a @tech{mutator} procedure, which consumes a structure, a field index,
  and a field value.}

]}

@defproc[(effect-type? [x any/c]) boolean?]{
Returns @racket[#t] if @racket[x] is an effect type and @racket[#f] otherwise.}

@subsection{Using Effects}

Once effect types have been defined, they can be instantiated in the same
manner as structs. These effects can then be passed in to a big bang with the
world when the world changes which will cause the effects to be invoked.

@defproc[(effect? [x any/c]) boolean?]{
Returns @racket[#t] if @racket[x] is an instance of an effect type and
@racket[#f] otherwise.}

@defproc[(compound-effect? [x any/c]) boolean?]{

A compound effect is a recursive type. The @racket[compound-effect?] procedure
will return @racket[#t] if @racket[x] is either an effect (according to
@racket[effect?]), or a list of compound effects. So, @racket[compound-effect?]
can be defined recursively by
@racketblock[
(define (compound-effect? x)
  (or (effect? x)
      (and (list? x)
           (andmap compound-effect? x))))
]}

@defproc[(world-with-effects [effects compound-effect?] [world any/c]) any]{

Wraps a compound effect and a world into a single object that a big bang will
recognize. When the world is changed to the return value of
@racket[world-with-effects] using one of the @racketidfont{change-world}
procedures in a @racket[bb-info], @racket[effects] is flattened into a list of
effects. Those effects are then applied in order before the world is updated to
@racket[world].

The @racket[world-with-effects] procedure is meant to be used by the developer
to bundle the output from a world to compound-effect function and a world to
world procedure, both defined by the end user. This allows the developer to
provide the end user with a functional interface for effects even though the
effects themselves are not functional.}

@;-----------------------------------------------------------------------------

@section{Render Effects}

Sometimes a developer wants to make an effectful operation appear functional
when it would work equally well with a functional interface. However, in these
cases, it is often desirable for the effectful operation to happen only at
render time. Render effects provide an interface that allows for these types of
opertaions.

For example, with an API that allows the user to load and move Google maps, the
developer might wish to only move the map or add/remove markers at render time.
However, the procedures Google provides for these actions are imperative, so
the developer cannot simply update the map functionally and at render time.
Instead they must use a render effect which updates the map and will be invoked
at render time.

Render effects are represented as @tech{structure type}s in much the same way
as effects. The main difference is that their implementation is that they can
be inserted into a dom tree where their implementation will be called at render
time.

@defproc[(make-render-effect-type [name symbol?]
                                  [super-type render-effect-type?]
                                  [field-cnt exact-nonnegative-integer?]
                                  [implementation procedure?]
                                  [guard (or/c procedure? #f) #f])
         (values render-effect-type?
                 struct-constructor-procedure?
                 struct-predicate-procedure?
                 struct-accessor-procedure?
                 struct-mutator-procedure?)]{

The @racket[make-render-effect-type] procedure works much the same way as the
@racket[make-effect-type] procedure described above. The main difference is
that, while the @racket[implementation] argument of an effect is applied to the
fields when the world is updated with that effect, then @racket[implementation]
argument of a render effect is applied at render time just before the dom tree
is checked for correctness.

Note that a render effect is a valid element in a dom tree if and only if its
implementation produces a valid dom element when applied to its fields.}

@defproc[(render-effect-type? [x any/c]) boolean?]{
Returns @racket[#t] if @racket[x] is a render effect type and @racket[#f]
otherwise.}

@defproc[(render-effect? [x any/c]) boolean?]{
Returns @racket[#t] if @racket[x] is an instance of a render effect type and
@racket[#f] otherwise.}
