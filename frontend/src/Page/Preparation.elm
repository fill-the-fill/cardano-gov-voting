module Page.Preparation exposing (Model, update, view)

import Bytes.Comparable as Bytes exposing (Bytes)
import Cardano exposing (CredentialWitness(..))
import Cardano.Address as Address exposing (Address, Credential(..), CredentialHash)
import Cardano.Cip30 as Cip30
import Cardano.Gov exposing (ActionId)
import Cardano.Transaction exposing (Transaction)
import Cardano.Utxo as Utxo exposing (Output)
import Dict exposing (Dict)
import Html exposing (Html, div, text)
import Html.Attributes as HA
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Url



-- ###################################################################
-- MODEL
-- ###################################################################


type alias Model =
    { proposals : List ActiveProposal
    , voterStep : Step VoterPreparationForm {} VoterIdentified
    , pickProposalStep : Step {} {} ActiveProposal
    , rationaleCreationStep : Step RationaleForm {} Rationale
    , rationaleSignatureStep : Step (Dict String (Maybe AuthorWitness)) {} (Dict String AuthorWitness)
    , permanentStorageStep : Step StoragePrep {} Storage
    , feeProviderStep : Step FeeProviderForm FeeProviderTemp FeeProvider
    , buildTxStep : Step {} {} Transaction
    }


type Step prep validating done
    = Preparing prep
    | Validating prep validating
    | Done done



-- Voter Step


type alias VoterPreparationForm =
    { voterType : VoterType
    , voterCred : VoterCredForm
    , error : Maybe String
    }


type VoterType
    = CcVoter
    | DrepVoter
    | SpoVoter


type VoterCredForm
    = StakeKeyVoter String
    | ScriptVoter { scriptHash : String, utxoRef : String }


type alias VoterIdentified =
    { voterType : VoterType
    , voterCred : CredentialWitness
    }



-- Pick Proposal Step


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



-- Rationale Step


type alias RationaleForm =
    { authors : List AuthorForm
    , summary : MarkdownForm
    , rationaleStatement : MarkdownForm
    , precedentDiscussion : MarkdownForm
    , counterargumentDiscussion : MarkdownForm
    , conclusion : MarkdownForm
    , internalVote : InternalVote
    , references : ReferencesForm
    }


type alias AuthorForm =
    {}


type alias MarkdownForm =
    {}


type alias InternalVote =
    { constitutional : Int
    , unconstitutional : Int
    , abstain : Int
    , didNotVote : Int
    }


type alias ReferencesForm =
    {}


type alias Rationale =
    { authors : Dict String (Maybe AuthorWitness)
    , summary : String
    , rationaleStatement : String
    , precedentDiscussion : String
    , counterargumentDiscussion : String
    , conclusion : String
    , internalVote : InternalVote
    , references : List Reference
    }


type alias AuthorWitness =
    {}


type alias Reference =
    {}



-- Storage Step


type alias StoragePrep =
    {}


type alias Storage =
    {}



-- Fee Provider Step


type FeeProviderForm
    = ConnectedWalletFeeProvider { error : String }
    | ExternalFeeProvider { endpoint : String, error : String }


type alias FeeProviderTemp =
    { address : Maybe Address
    , utxos : Maybe (Utxo.RefDict Output)
    }


type alias FeeProvider =
    { address : Address
    , utxos : Utxo.RefDict Output
    }



-- ###################################################################
-- UPDATE
-- ###################################################################


type Msg
    = NoMsg
      -- Voter Step
    | VoterTypeSelected VoterType
    | VoterCredentialUpdated VoterCredForm
    | ValidateVoterFormButtonClicked
      -- Fee Provider Step
    | FeeProviderUpdated FeeProviderForm
    | ValidateFeeProviderFormButtonClicked
    | ReceivedFeeProviderUtxos FeeProvider


type alias UpdateContext msg =
    { wrapMsg : Msg -> msg
    , loadedWallet : Maybe LoadedWallet
    , feeProviderAskUtxosCmd : Cmd msg
    }


type alias LoadedWallet =
    { wallet : Cip30.Wallet
    , changeAddress : Address
    , utxos : Utxo.RefDict Output
    }


update : UpdateContext msg -> Msg -> Model -> ( Model, Cmd msg )
update ctx msg model =
    case msg of
        NoMsg ->
            ( model, Cmd.none )

        --
        -- Voter Step
        --
        VoterTypeSelected voterType ->
            ( updateVoterForm (\form -> { form | voterType = voterType }) model
            , Cmd.none
            )

        VoterCredentialUpdated voterCredForm ->
            ( updateVoterForm (\form -> { form | voterCred = voterCredForm }) model
            , Cmd.none
            )

        ValidateVoterFormButtonClicked ->
            case model.voterStep of
                Preparing form ->
                    ( { model | voterStep = confirmVoter form }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        --
        -- Fee Provider Step
        --
        FeeProviderUpdated feeProviderForm ->
            ( updateFeeProviderForm feeProviderForm model
            , Cmd.none
            )

        ValidateFeeProviderFormButtonClicked ->
            case model.feeProviderStep of
                Preparing form ->
                    case validateFeeProviderForm ctx.loadedWallet form of
                        (Validating _ _) as validating ->
                            ( { model | feeProviderStep = validating }
                            , ctx.feeProviderAskUtxosCmd
                            )

                        validated ->
                            ( { model | feeProviderStep = validated }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ReceivedFeeProviderUtxos feeProvider ->
            case model.feeProviderStep of
                Validating _ _ ->
                    ( { model | feeProviderStep = Done feeProvider }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )



-- Voter Step


updateVoterForm : (VoterPreparationForm -> VoterPreparationForm) -> Model -> Model
updateVoterForm f ({ voterStep } as model) =
    case voterStep of
        Preparing form ->
            { model | voterStep = Preparing (f form) }

        _ ->
            model


confirmVoter : VoterPreparationForm -> Step VoterPreparationForm {} VoterIdentified
confirmVoter form =
    case validateVoterCredForm form.voterCred of
        Ok voterCred ->
            Done
                { voterType = form.voterType
                , voterCred = voterCred
                }

        Err error ->
            Preparing { form | error = Just error }


validateVoterCredForm : VoterCredForm -> Result String CredentialWitness
validateVoterCredForm voterCredForm =
    case voterCredForm of
        StakeKeyVoter str ->
            stakeKeyHashFromStr str
                |> Result.map WithKey

        ScriptVoter { scriptHash, utxoRef } ->
            -- Result.map2 (\hash utxo -> WithScript hash <| )
            -- (scriptHashFromStr scriptHash)
            -- (utxoRefFromStr utxoRef)
            Debug.todo "validateVoterCredForm"


stakeKeyHashFromStr : String -> Result String (Bytes CredentialHash)
stakeKeyHashFromStr str =
    -- Try to extract the stake key hash from a string that can either be:
    --  * garbage
    --  * directly a valid stake key hash in hex
    --  * a stake key address in hex
    --  * a stake key address in bech32
    if String.length str == 56 then
        -- Can only be a credential hash directly if 28 bytes
        Bytes.fromHex str
            |> Result.fromMaybe ("Invalid Hex of credential hash: " ++ str)

    else
        Address.fromString str
            |> Result.fromMaybe ("Invalid credential hash or stake address: " ++ str)
            |> Result.andThen
                (\address ->
                    case address of
                        Address.Reward stakeAddress ->
                            case stakeAddress.stakeCredential of
                                VKeyHash cred ->
                                    Ok cred

                                ScriptHash _ ->
                                    Err "This is a script address, not a Key address"

                        _ ->
                            Err "This is a full address, please use a stake (reward) address instead"
                )



-- Fee Provider Step


updateFeeProviderForm : FeeProviderForm -> Model -> Model
updateFeeProviderForm form model =
    case model.feeProviderStep of
        Preparing _ ->
            { model | feeProviderStep = Preparing form }

        _ ->
            model


{-| Check if the external endpoint seems legit.
-}
validateFeeProviderForm : Maybe LoadedWallet -> FeeProviderForm -> Step FeeProviderForm FeeProviderTemp FeeProvider
validateFeeProviderForm maybeWallet feeProviderForm =
    case ( maybeWallet, feeProviderForm ) of
        ( Nothing, ConnectedWalletFeeProvider _ ) ->
            Preparing (ConnectedWalletFeeProvider { error = "No wallet connected, please connect a wallet first." })

        ( Just { changeAddress, utxos }, ConnectedWalletFeeProvider _ ) ->
            Done { address = changeAddress, utxos = utxos }

        ( _, ExternalFeeProvider { endpoint } ) ->
            case Url.fromString endpoint of
                Just _ ->
                    Validating feeProviderForm { address = Nothing, utxos = Nothing }

                Nothing ->
                    Preparing (ConnectedWalletFeeProvider { error = "The endpoint does not look like a valid URL: " ++ endpoint })



-- ###################################################################
-- VIEW
-- ###################################################################


type alias ViewContext msg =
    { wrapMsg : Msg -> msg
    }


view : ViewContext msg -> Model -> Html msg
view ctx model =
    div []
        [ Html.h2 [] [ text "Vote Preparation" ]
        , viewVoterIdentificationStep ctx model.voterStep
        , Html.hr [] []
        , viewProposalSelectionStep ctx model
        , Html.hr [] []
        , viewRationaleStep ctx model.rationaleCreationStep
        , Html.hr [] []
        , viewPermanentStorageStep ctx model.permanentStorageStep
        , Html.hr [] []
        , viewFeeProviderStep ctx model.feeProviderStep
        , Html.hr [] []
        , viewBuildTxStep ctx model.buildTxStep
        ]



--
-- Voter Identification Step
--


viewVoterIdentificationStep : ViewContext msg -> Step VoterPreparationForm {} VoterIdentified -> Html msg
viewVoterIdentificationStep ctx step =
    case step of
        Preparing form ->
            div []
                [ Html.h3 [] [ text "Voter Identification" ]
                , Html.map ctx.wrapMsg <| viewVoterTypeSelector form.voterType
                , Html.map ctx.wrapMsg <| viewVoterCredentialsForm form.voterCred
                ]

        Validating _ _ ->
            div []
                [ Html.h3 [] [ text "Voter Identification" ]
                , Html.p [] [ text "validating voter information ..." ]
                ]

        Done voter ->
            div []
                [ Html.h3 [] [ text "Voter Identified" ]
                , Html.map ctx.wrapMsg <| viewIdentifiedVoter voter
                ]


viewVoterTypeSelector : VoterType -> Html Msg
viewVoterTypeSelector currentType =
    div []
        [ Html.h4 [] [ text "Select Voter Type" ]
        , div []
            [ viewVoterTypeOption CcVoter "Constitutional Committee" (currentType == CcVoter)
            , viewVoterTypeOption DrepVoter "DRep" (currentType == DrepVoter)
            , viewVoterTypeOption SpoVoter "SPO" (currentType == SpoVoter)
            ]
        ]


viewVoterTypeOption : VoterType -> String -> Bool -> Html Msg
viewVoterTypeOption voterType label isSelected =
    div []
        [ Html.input
            [ HA.type_ "radio"
            , HA.name "voter-type"
            , HA.checked isSelected
            , onClick (VoterTypeSelected voterType)
            ]
            []
        , Html.label [] [ text label ]
        ]


viewCredTypeOption : VoterCredForm -> String -> Bool -> Html Msg
viewCredTypeOption voterCredType label isSelected =
    div []
        [ Html.input
            [ HA.type_ "radio"
            , HA.name "cred-type"
            , HA.checked isSelected
            , onClick (VoterCredentialUpdated voterCredType)
            ]
            []
        , Html.label [] [ text label ]
        ]


viewVoterCredentialsForm : VoterCredForm -> Html Msg
viewVoterCredentialsForm credForm =
    let
        isStakeKeyVoter =
            case credForm of
                StakeKeyVoter _ ->
                    True

                _ ->
                    False
    in
    div []
        [ Html.h4 [] [ text "Voter Credentials" ]
        , div []
            [ viewCredTypeOption (StakeKeyVoter "") "Stake Key Voter" isStakeKeyVoter
            , viewCredTypeOption (ScriptVoter { scriptHash = "", utxoRef = "" }) "(WIP) Script Voter" (not isStakeKeyVoter)
            ]
        , case credForm of
            StakeKeyVoter key ->
                div []
                    [ Html.label [] [ text "Stake key hash (or stake address)" ]
                    , Html.input
                        [ HA.type_ "text"
                        , HA.value key
                        , Html.Events.onInput (\s -> VoterCredentialUpdated (StakeKeyVoter s))
                        ]
                        []
                    ]

            ScriptVoter { scriptHash, utxoRef } ->
                div []
                    [ Html.label [] [ text "Script Hash" ]
                    , Html.input
                        [ HA.type_ "text"
                        , HA.value scriptHash
                        , Html.Events.onInput
                            (\s -> VoterCredentialUpdated (ScriptVoter { scriptHash = s, utxoRef = utxoRef }))
                        ]
                        []
                    , Html.label [] [ text "UTxO Reference" ]
                    , Html.input
                        [ HA.type_ "text"
                        , HA.value utxoRef
                        , Html.Events.onInput
                            (\s -> VoterCredentialUpdated (ScriptVoter { scriptHash = scriptHash, utxoRef = s }))
                        ]
                        []
                    ]
        ]


viewIdentifiedVoter : VoterIdentified -> Html Msg
viewIdentifiedVoter voter =
    text "TODO viewIdentifiedVoter"



--
-- Proposal Selection Step
--


viewProposalSelectionStep : ViewContext msg -> Model -> Html msg
viewProposalSelectionStep ctx model =
    text "TODO viewProposalSelectionStep"



--
-- Rationale Step
--


viewRationaleStep : ViewContext msg -> Step RationaleForm {} Rationale -> Html msg
viewRationaleStep ctx step =
    text "TODO viewRationaleStep"



--
-- Storage Step
--


viewPermanentStorageStep : ViewContext msg -> Step StoragePrep {} Storage -> Html msg
viewPermanentStorageStep ctx step =
    text "TODO viewPermanentStorageStep"



--
-- Fee Provider Step
--


viewFeeProviderStep : ViewContext msg -> Step FeeProviderForm FeeProviderTemp FeeProvider -> Html msg
viewFeeProviderStep ctx step =
    case step of
        Preparing form ->
            div []
                [ Html.h3 [] [ text "Fee Provider" ]
                , Html.map ctx.wrapMsg <| viewFeeProviderForm form
                ]

        Validating _ _ ->
            div []
                [ Html.h3 [] [ text "Fee Provider" ]
                , Html.p [] [ text "validating fee provider information ..." ]
                ]

        Done feeProvider ->
            div []
                [ Html.h3 [] [ text "Fee Provider" ]
                , Html.p [] [ text "TODO: display address and utxos" ]
                ]


viewFeeProviderForm : FeeProviderForm -> Html Msg
viewFeeProviderForm feeProviderForm =
    let
        isUsingWalletForFees =
            case feeProviderForm of
                ConnectedWalletFeeProvider _ ->
                    True

                _ ->
                    False
    in
    div []
        [ Html.h4 [] [ text "Fee Provider (TODO: split from voter type)" ]
        , div []
            [ viewFeeProviderOption
                (ConnectedWalletFeeProvider { error = "" })
                "Use connected wallet"
                isUsingWalletForFees
            , viewFeeProviderOption
                (ExternalFeeProvider { endpoint = "", error = "" })
                "(WIP) Use external fee provider"
                (not isUsingWalletForFees)
            , case feeProviderForm of
                ExternalFeeProvider { endpoint, error } ->
                    div []
                        [ Html.label [] [ text "External Provider Endpoint" ]
                        , Html.input
                            [ HA.type_ "text"
                            , HA.value endpoint
                            , Html.Events.onInput
                                (\s -> FeeProviderUpdated (ExternalFeeProvider { endpoint = s, error = error }))
                            ]
                            []
                        ]

                _ ->
                    text ""
            ]
        ]


viewFeeProviderOption : FeeProviderForm -> String -> Bool -> Html Msg
viewFeeProviderOption feeProviderForm label isSelected =
    div []
        [ Html.input
            [ HA.type_ "radio"
            , HA.name "fee-provider"
            , HA.checked isSelected
            , onClick (FeeProviderUpdated feeProviderForm)
            ]
            []
        , Html.label [] [ text label ]
        ]



--
-- Tx Building Step
--


viewBuildTxStep : ViewContext msg -> Step {} {} Transaction -> Html msg
viewBuildTxStep ctx step =
    text "TODO viewBuildTxStep"
