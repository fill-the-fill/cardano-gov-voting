// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// https://typst.app/universe/package/cmarker
#import "@preview/cmarker:0.1.1"

// JSON data
#let data = json("metadata.json")

// Title
#align(center, text(22pt)[
  *Vote Rationale*
])

// Authors (extracted from the 'authors' field of the JSON)
#if "authors" in data and data.authors.len() > 0 [
  #align(center, grid(
    columns: calc.min(2, data.authors.len()),
    row-gutter: 10pt,
    column-gutter: 35pt,
    ..data.authors.map(author => [
      #author.name
    ])
  ))
  #v(1em)
]

#v(1em) // add some vertical space

This document is automatically generated from the CIP-0136 JSON file attached to the vote.

#set par(justify: true)

= Summary

#cmarker.render(data.body.summary)

= Rationale Statement

#cmarker.render(data.body.rationaleStatement)

// Optional Precedent Discussion
#if "precedentDiscussion" in data.body [
  = Precedent Discussion

  #cmarker.render(data.body.precedentDiscussion)
]

// Optional Counter-argument Discussion
#if "counterargumentDiscussion" in data.body [
  = Counter-argument Discussion

  #cmarker.render(data.body.counterargumentDiscussion)
]

// Optional Conclusion
#if "conclusion" in data.body [
  = Conclusion

  #cmarker.render(data.body.conclusion)
]

// Optional Internal Vote
#if "internalVote" in data.body [
  = Internal Vote

  - Constitutional: #data.body.internalVote.constitutional
  - Unconstitutional: #data.body.internalVote.unconstitutional
  - Abstain: #data.body.internalVote.abstain
  - Did not vote: #data.body.internalVote.didNotVote
]

// Optional References
#if "references" in data.body [
  = References

  #show link: underline

  #for reference in data.body.references [
    - #reference.at("@type"): #link(reference.uri)[#reference.label]
  ]
]
