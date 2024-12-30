export const jsonLdContexts = {
  ccCip136Context: {
    "@language": "en-us",
    CIP100:
      "https://github.com/cardano-foundation/CIPs/blob/master/CIP-0100/README.md#",
    CIP136:
      "https://github.com/cardano-foundation/CIPs/blob/master/CIP-0136/README.md#",
    hashAlgorithm: "CIP100:hashAlgorithm",
    body: {
      "@id": "CIP136:body",
      "@context": {
        references: {
          "@id": "CIP100:references",
          "@container": "@set",
          "@context": {
            GovernanceMetadata: "CIP100:GovernanceMetadataReference",
            Other: "CIP100:OtherReference",
            label: "CIP100:reference-label",
            uri: "CIP100:reference-uri",
            RelevantArticles: "CIP136:RelevantArticles",
          },
        },
        summary: "CIP136:summary",
        rationaleStatement: "CIP136:rationaleStatement",
        precedentDiscussion: "CIP136:precedentDiscussion",
        counterargumentDiscussion: "CIP136:counterargumentDiscussion",
        conclusion: "CIP136:conclusion",
        internalVote: {
          "@id": "CIP136:internalVote",
          "@container": "@set",
          "@context": {
            constitutional: "CIP136:constitutional",
            unconstitutional: "CIP136:unconstitutional",
            abstain: "CIP136:abstain",
            didNotVote: "CIP136:didNotVote",
          },
        },
      },
    },
    authors: {
      "@id": "CIP100:authors",
      "@container": "@set",
      "@context": {
        did: "@id",
        name: "http://xmlns.com/foaf/0.1/name",
        witness: {
          "@id": "CIP100:witness",
          "@context": {
            witnessAlgorithm: "CIP100:witnessAlgorithm",
            publicKey: "CIP100:publicKey",
            signature: "CIP100:signature",
          },
        },
      },
    },
  },
};
