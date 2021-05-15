# multirx
Perl concept prototype for vertical-context regular expressions

The basic idea of "vertical context" is to apply pattern matching concepts over text that may span multiple "lines".

It does this by applying a set of normal regular expressions against a sequence of lines, each line checked against a particular regular expression.

The parts of the vertical regex is meant to mirror regular expression concepts itself, basically working as a "regex of regexes" where each 'character'
is in fact an entire line of text.

Thus, the vertical regular expression is a composition of several regular "horizontal" regular expressions, combined using regular-expression-like commands such
as juxtaposition (e.g. A "then" B), repetition (A "x-y times"), or alternation (A "or" B).

# Why?

Typical regular expressions generally see text as a single, linear, sequence of characters. For most common text searches this is enough, and even when
describing structured grammars (such as XML or JSON), one typically does so by disregarding whitespace entirely.

However, in some cases you have text that usually relies on its specific arrangement to carry information. Not only "horizontally" as text is read left-to-right
or right-to-left, but also "vertically": additional context is created by juxtaposing text in one line against text in the line(s) before and/or after.
Examples of this type of text include ASCII art (especially, for example, text-rendered QR barcodes), text arranged in tables, or Python.

With traditional "horizontal-only" regular expressions, capturing and conveying context across lines may be cumbersome at best, or impossible at worst. For
example, while Perl makes it possible to query that two lines begin with the same prefix, it may not be possible to instead ask "two lines start with the same
number of characters - without regard whatsoever to the characters themselves".