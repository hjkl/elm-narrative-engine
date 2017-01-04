module Engine.Manifest
    exposing
        ( init
        , character
        , characterIsInLocation
        , getAttributes
        , getCharactersInLocation
        , getItemsInLocation
        , getItemsInInventory
        , getLocations
        , isCharacter
        , isItem
        , isLocation
        , item
        , itemIsInInventory
        , itemIsInLocation
        , location
        , update
        )

import Types exposing (..)
import Dict exposing (Dict)


-- Model


init :
    { items : List ( String, Attributes )
    , locations : List ( String, Attributes )
    , characters : List ( String, Attributes )
    }
    -> Manifest
init { items, locations, characters } =
    let
        insertFn interactableConstructor ( id, attrs ) acc =
            Dict.insert id (interactableConstructor attrs) acc

        foldFn interactableConstructor interactableList acc =
            List.foldr (insertFn interactableConstructor) acc interactableList
    in
        Dict.empty
            |> foldFn item items
            |> foldFn location locations
            |> foldFn character characters


item : Attributes -> Interactable
item attrs =
    Item False ItemOffScreen attrs


location : Attributes -> Interactable
location attrs =
    Location False attrs


character : Attributes -> Interactable
character attrs =
    Character CharacterOffScreen attrs


getAttributes : String -> Manifest -> Maybe Attributes
getAttributes id manifest =
    let
        getAttrs interactable =
            case interactable of
                Item _ _ attrs ->
                    attrs

                Location _ attrs ->
                    attrs

                Character _ attrs ->
                    attrs
    in
        Dict.get id manifest
            |> Maybe.map getAttrs


getItemsInInventory : Manifest -> List ( String, Attributes )
getItemsInInventory manifest =
    let
        isInInventory ( id, interactable ) =
            case interactable of
                Item _ ItemInInventory attrs ->
                    Just ( id, attrs )

                _ ->
                    Nothing
    in
        Dict.toList manifest
            |> List.filterMap isInInventory


getLocations : Manifest -> List ( String, Attributes )
getLocations manifest =
    let
        isShownLocation ( id, interactable ) =
            case interactable of
                Location True attrs ->
                    Just ( id, attrs )

                _ ->
                    Nothing
    in
        Dict.toList manifest
            |> List.filterMap isShownLocation


getCharactersInLocation : String -> Manifest -> List ( String, Attributes )
getCharactersInLocation locationId manifest =
    let
        isInLocation ( id, interactable ) =
            case interactable of
                Character (CharacterInLocation location) attrs ->
                    if location == locationId then
                        Just ( id, attrs )
                    else
                        Nothing

                _ ->
                    Nothing
    in
        Dict.toList manifest
            |> List.filterMap isInLocation


getItemsInLocation : String -> Manifest -> List ( String, Attributes )
getItemsInLocation locationId manifest =
    let
        isInLocation ( id, interactable ) =
            case interactable of
                Item _ (ItemInLocation location) attrs ->
                    if location == locationId then
                        Just ( id, attrs )
                    else
                        Nothing

                _ ->
                    Nothing
    in
        Dict.toList manifest
            |> List.filterMap isInLocation


isItem : String -> Manifest -> Bool
isItem id manifest =
    Dict.get id manifest
        |> \interactable ->
            case interactable of
                Just (Item _ _ _) ->
                    True

                _ ->
                    False


isLocation : String -> Manifest -> Bool
isLocation id manifest =
    Dict.get id manifest
        |> \interactable ->
            case interactable of
                Just (Location _ _) ->
                    True

                _ ->
                    False


isCharacter : String -> Manifest -> Bool
isCharacter id manifest =
    Dict.get id manifest
        |> \interactable ->
            case interactable of
                Just (Character _ _) ->
                    True

                _ ->
                    False



-- Update


update : ChangeWorldCommand -> Manifest -> Manifest
update change manifest =
    case change of
        MoveTo id ->
            Dict.update id addLocation manifest

        AddLocation id ->
            Dict.update id addLocation manifest

        RemoveLocation id ->
            Dict.update id removeLocation manifest

        MoveItemToInventory id ->
            Dict.update id moveItemToInventory manifest

        MoveItemToLocation itemId locationId ->
            Dict.update itemId (moveItemToLocation locationId) manifest

        MoveItemToLocationFixed itemId locationId ->
            Dict.update itemId (moveItemToLocationFixed locationId) manifest

        MoveItemOffScreen id ->
            Dict.update id moveItemOffScreen manifest

        MoveCharacterToLocation characterId locationId ->
            Dict.update characterId (moveCharacterToLocation locationId) manifest

        MoveCharacterOffScreen id ->
            Dict.update id moveCharacterOffScreen manifest

        _ ->
            manifest


addLocation : Maybe Interactable -> Maybe Interactable
addLocation interactable =
    case interactable of
        Just (Location _ attrs) ->
            Just (Location True attrs)

        _ ->
            interactable


removeLocation : Maybe Interactable -> Maybe Interactable
removeLocation interactable =
    case interactable of
        Just (Location _ attrs) ->
            Just (Location False attrs)

        _ ->
            interactable


moveItemToInventory : Maybe Interactable -> Maybe Interactable
moveItemToInventory interactable =
    case interactable of
        Just (Item False _ attrs) ->
            Just (Item False ItemInInventory attrs)

        _ ->
            interactable


moveItemOffScreen : Maybe Interactable -> Maybe Interactable
moveItemOffScreen interactable =
    case interactable of
        Just (Item _ _ attrs) ->
            Just (Item False ItemOffScreen attrs)

        _ ->
            interactable


moveItemToLocationFixed : String -> Maybe Interactable -> Maybe Interactable
moveItemToLocationFixed locationId interactable =
    case interactable of
        Just (Item _ _ attrs) ->
            Just (Item True (ItemInLocation locationId) attrs)

        _ ->
            interactable


moveItemToLocation : String -> Maybe Interactable -> Maybe Interactable
moveItemToLocation locationId interactable =
    case interactable of
        Just (Item _ _ attrs) ->
            Just (Item False (ItemInLocation locationId) attrs)

        _ ->
            interactable


moveCharacterToLocation : String -> Maybe Interactable -> Maybe Interactable
moveCharacterToLocation locationId interactable =
    case interactable of
        Just (Character _ attrs) ->
            Just (Character (CharacterInLocation locationId) attrs)

        _ ->
            interactable


moveCharacterOffScreen : Maybe Interactable -> Maybe Interactable
moveCharacterOffScreen interactable =
    case interactable of
        Just (Character _ attrs) ->
            Just (Character CharacterOffScreen attrs)

        _ ->
            interactable


itemIsInInventory : String -> Manifest -> Bool
itemIsInInventory id manifest =
    getItemsInInventory manifest
        |> List.any (Tuple.first >> (==) id)


characterIsInLocation : String -> String -> Manifest -> Bool
characterIsInLocation character currentLocation manifest =
    getCharactersInLocation currentLocation manifest
        |> List.any (Tuple.first >> (==) character)


itemIsInLocation : String -> String -> Manifest -> Bool
itemIsInLocation item currentLocation manifest =
    getItemsInLocation currentLocation manifest
        |> List.any (Tuple.first >> (==) item)
