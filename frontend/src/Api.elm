module Api exposing (ActiveProposal, ApiProvider, ProposalMetadata, ProtocolParams, defaultApiProvider)

import Bytes.Comparable as Bytes exposing (Bytes)
import Cardano.Gov exposing (ActionId, CostModels)
import Cardano.Transaction as Transaction exposing (Transaction)
import Cardano.Utxo exposing (TransactionId)
import Dict exposing (Dict)
import Http
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE
import Natural exposing (Natural)
import RemoteData exposing (WebData)


type alias ApiProvider msg =
    { loadProtocolParams : (Result Http.Error ProtocolParams -> msg) -> Cmd msg
    , loadGovProposals : (Result Http.Error (List ActiveProposal) -> msg) -> Cmd msg
    , retrieveTxs : List (Bytes TransactionId) -> (Result Http.Error (Dict String Transaction) -> msg) -> Cmd msg
    }



-- Protocol Parameters


type alias ProtocolParams =
    { costModels : CostModels
    , drepDeposit : Natural
    }


protocolParamsDecoder : Decoder ProtocolParams
protocolParamsDecoder =
    JD.map4
        (\v1 v2 v3 drepDeposit ->
            { costModels = CostModels (Just v1) (Just v2) (Just v3)
            , drepDeposit = drepDeposit
            }
        )
        (JD.at [ "result", "plutusCostModels", "plutus:v1" ] <| JD.list JD.int)
        (JD.at [ "result", "plutusCostModels", "plutus:v2" ] <| JD.list JD.int)
        (JD.at [ "result", "plutusCostModels", "plutus:v3" ] <| JD.list JD.int)
        (JD.at [ "result", "delegateRepresentativeDeposit", "ada", "lovelace" ] <| JD.map Natural.fromSafeInt JD.int)



-- Governance Proposals


type alias ActiveProposal =
    { id : ActionId
    , actionType : String
    , metadata : WebData ProposalMetadata
    }


type alias ProposalMetadata =
    { title : String
    , abstract : String
    , rawJson : String
    }


proposalsDecoder : Decoder (List ActiveProposal)
proposalsDecoder =
    JD.field "result" <|
        JD.list <|
            JD.map3 ActiveProposal
                (JD.map2
                    (\id index ->
                        { transactionId = Bytes.fromHexUnchecked id
                        , govActionIndex = index
                        }
                    )
                    (JD.at [ "proposal", "transaction", "id" ] JD.string)
                    (JD.at [ "proposal", "index" ] JD.int)
                )
                (JD.at [ "action", "type" ] JD.string)
                (JD.succeed RemoteData.Loading)



-- Retrieve Txs


koiosTxCborDecoder : Decoder (Dict String Transaction)
koiosTxCborDecoder =
    let
        singleTxDecoder : Decoder ( String, Transaction )
        singleTxDecoder =
            JD.map2 Tuple.pair
                (JD.field "tx_hash" JD.string)
                (JD.field "cbor" JD.string)
                |> JD.andThen
                    (\( hashHex, cborHex ) ->
                        case Bytes.fromHex cborHex |> Maybe.andThen Transaction.deserialize of
                            Just tx ->
                                JD.succeed ( hashHex, tx )

                            Nothing ->
                                JD.fail <| "Failed to deserialize Tx: " ++ cborHex
                    )
    in
    JD.list singleTxDecoder
        |> JD.map Dict.fromList



-- Default API Provider


defaultApiProvider : ApiProvider msg
defaultApiProvider =
    -- Get protocol parameters via Koios
    { loadProtocolParams =
        \toMsg ->
            Http.post
                { url = "https://preview.koios.rest/api/v1/ogmios"
                , body =
                    Http.jsonBody
                        (JE.object
                            [ ( "jsonrpc", JE.string "2.0" )
                            , ( "method", JE.string "queryLedgerState/protocolParameters" )
                            ]
                        )
                , expect = Http.expectJson toMsg protocolParamsDecoder
                }

    -- Get governance proposals via Koios
    , loadGovProposals =
        \toMsg ->
            Http.post
                { url = "https://preview.koios.rest/api/v1/ogmios"
                , body =
                    Http.jsonBody
                        (JE.object
                            [ ( "jsonrpc", JE.string "2.0" )
                            , ( "method", JE.string "queryLedgerState/governanceProposals" )
                            ]
                        )
                , expect = Http.expectJson toMsg proposalsDecoder
                }

    -- Retrieve transactions via Koios by proxying with the server (to avoid CORS errors)
    , retrieveTxs =
        \txIds toMsg ->
            Http.post
                { url = "/proxy/json"
                , body =
                    Http.jsonBody
                        (JE.object
                            [ ( "url", JE.string "https://preview.koios.rest/api/v1/tx_cbor" )
                            , ( "method", JE.string "POST" )
                            , ( "body", JE.object [ ( "_tx_hashes", JE.list (JE.string << Bytes.toHex) txIds ) ] )
                            ]
                        )
                , expect = Http.expectJson toMsg koiosTxCborDecoder
                }
    }
