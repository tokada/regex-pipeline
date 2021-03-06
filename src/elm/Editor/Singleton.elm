module Editor.Singleton exposing (Model, Msg(..), Section, applyRegex, by, getAt, init, initConcatenated, initSection, matchingSections, onChange, replace, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, targetValue)
import Json.Decode as JD
import Regex



--main =
--    Browser.sandbox { init = init, update = update, view = view }
-- MODEL


type alias Model =
    { domain : String
    , sections : List Section
    , concatenated : String
    }


type alias Section =
    { codomain : String
    , pattern : String
    , index : Int
    }


init : Model
init =
    { domain = ""
    , sections = [ initSection ]
    , concatenated = initConcatenated
    }


initSection =
    { codomain = ""
    , pattern = ""
    , index = 0
    }


initConcatenated =
    "Concatenated string comes here."



-- UPDATE


type Msg
    = OnDomain String
    | OnRegex Int String
    | OnIndex Int String
    | OnAddPrev Int
    | OnAddNext Int
    | Open


update : Msg -> Model -> Model
update msg model =
    let
        pivotMatched pattern_ index_ text_ =
            if String.length pattern_ > 0 then
                case getAt index_ <| applyRegex pattern_ text_ of
                    Just s ->
                        s

                    Nothing ->
                        ""

            else
                text_

        concatenate sections domain =
            let
                strings =
                    List.map (\s -> s.codomain) sections
            in
            if String.isEmpty domain then
                initConcatenated

            else if List.all (\s -> s == domain) strings then
                domain

            else
                List.foldr (++) "" <| List.filter (\s -> s /= domain) strings

        initSection_ =
            { initSection | codomain = model.domain }
    in
    case msg of
        OnDomain t ->
            let
                newSections =
                    List.map
                        (\sec ->
                            let
                                match =
                                    pivotMatched sec.pattern sec.index t
                            in
                            { codomain = match
                            , pattern = sec.pattern
                            , index = sec.index
                            }
                        )
                        model.sections
            in
            { model | domain = t, sections = newSections, concatenated = concatenate newSections t }

        OnRegex n p ->
            let
                targetSec =
                    getAt n model.sections
            in
            case targetSec of
                Just s ->
                    let
                        match =
                            pivotMatched p s.index model.domain

                        newTargetSec =
                            { s | codomain = match, pattern = p }

                        newSections =
                            replace n newTargetSec model.sections
                    in
                    { model | sections = newSections, concatenated = concatenate newSections model.domain }

                Nothing ->
                    model

        OnIndex n index ->
            let
                targetSec =
                    getAt n model.sections

                index_ =
                    case String.toInt index of
                        Just i_ ->
                            i_

                        Nothing ->
                            0
            in
            case targetSec of
                Just s ->
                    let
                        match =
                            pivotMatched s.pattern index_ model.domain

                        newTargetSec =
                            { s | codomain = match, index = index_ }

                        newSections =
                            replace n newTargetSec model.sections
                    in
                    { model | sections = newSections, concatenated = concatenate newSections model.domain }

                Nothing ->
                    model

        OnAddPrev n ->
            { model | sections = insertAt n initSection_ model.sections }

        OnAddNext n ->
            { model | sections = insertAt (n + 1) initSection_ model.sections }

        Open -> model


getAt : Int -> List a -> Maybe a
getAt i xs =
    List.head <| List.drop i xs


insertAt : Int -> a -> List a -> List a
insertAt i y xs =
    if i < 0 then
        xs

    else
        List.take i xs ++ (y :: List.drop i xs)



-- WARNING: It's NOT tail-recursive!


replace : Int -> a -> List a -> List a
replace target y xs =
    case xs of
        [] ->
            []

        h :: t ->
            if target < 0 then
                xs

            else if target > List.length xs then
                xs

            else if target == 0 then
                y :: t

            else
                h :: replace (target - 1) y t


applyRegex : String -> String -> List String
applyRegex pattern domain =
    let
        matches =
            Regex.find (by pattern) domain
    in
    List.map (\m -> m.match) matches


by : String -> Regex.Regex
by pattern =
    Maybe.withDefault Regex.never <| Regex.fromString pattern



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ div []
            [ h1 [] [ text "Regex & Concatenation" ]
            , hr [] []
            ]
        , div []
            [ h2 [] [ text "Original Text" ]
            , textarea [ cols 100, rows 10, onInput OnDomain ] [ text model.domain ]
            , hr [] []
            ]
        , div []
            [ h2 [] [ text "Concatenated Text" ]
            , p [] [ text model.concatenated ]
            , hr [] []
            ]
        , div [] <| matchingSections model
        ]


onChange : (String -> msg) -> Html.Attribute msg
onChange tagger =
    on "change" (JD.map tagger targetValue)


matchingSections : Model -> List (Html Msg)
matchingSections model =
    List.indexedMap
        (\n ->
            \sec ->
                div []
                    [ button [ onClick (OnAddPrev n) ] [ text "add prev" ]
                    , h2 [] [ text <| "Regex Pattern " ++ String.fromInt (n + 1) ]
                    , div []
                        [ input [ placeholder "regex", value sec.pattern, onInput (OnRegex n) ] [] ]
                    , div []
                        [ input [ placeholder "index (default: 0)", value <| String.fromInt sec.index, onInput (OnIndex n) ] [] ]
                    , div []
                        [ textarea [ placeholder "after", cols 100, rows 5 ] [ text sec.codomain ] ]
                    , div []
                        [ button [ onClick (OnAddNext n) ] [ text "add next" ] ]
                    , hr [] []
                    ]
        )
        model.sections
