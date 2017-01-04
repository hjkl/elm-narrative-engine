module Engine
    exposing
        ( Model
        , Msg
        , interactMsg
        , init
        , update
        , getCurrentLocation
        , getItemsInCurrentLocation
        , getCharactersInCurrentLocation
        , getItemsInInventory
        , getLocations
        , getStoryLine
        , getEnding
        , Rule
        , InteractionMatcher
        , withItem
        , withLocation
        , withCharacter
        , withAnything
        , withAnyItem
        , withAnyLocation
        , withAnyCharacter
        , Condition
        , characterIsNotInLocation
        , characterIsInLocation
        , currentLocationIs
        , currentLocationIsNot
        , itemIsInInventory
        , itemIsNotInInventory
        , itemIsNotInLocation
        , itemIsInLocation
        , ChangeWorldCommand
        , addLocation
        , endStory
        , loadScene
        , moveCharacterToLocation
        , moveCharacterOffScreen
        , moveItemToLocation
        , moveItemToLocationFixed
        , moveItemOffScreen
        , moveItemToInventory
        , moveTo
        , removeLocation
        )

{-| The story engine handles storing and advancing your story state by running through your story rules on each interaction.  It allows the client code to handle building the story world, story rules, and display layer.

# Embedding the story engine

The story engine is designed to be embedded in your own Elm app, allowing for maximum flexibility and customization.

You can base your app on the [interactive story starter repo](https://github.com/jschomay/elm-interactive-story-starter.git).

@docs Model, Msg, interactMsg, init, update, getCurrentLocation, getItemsInCurrentLocation, getCharactersInCurrentLocation, getItemsInInventory, getLocations, getStoryLine, getEnding

# Defining your story world

TODO

# Defining story rules

Rules are how you progress the story.  They are made up of conditions to match against and commands to perform if the rule matches.  Rules are grouped into "scenes" for better control and organization.  The engine will run through the active scene from the beginning, looking for the first matching rule, then run it.  If no rules match, the framework will perform a default command, which is usually just to narrate the description of what was interacted with, or to move you to that location or take that item.


A rule has four parts:

1. A matcher against what interactable story element the user clicked on
2. A list of conditions that all must match for the rule to match
3. A list of changes to make if the rule matches
4. Narration to add to the story line if the rule matches (note that you can use markdown)

TODO - UPDATE THIS!!!!!!!!!!

    scene1 : List Engine.Rule
    scene1 =
        [ { interaction = withCharacter Harry
          , conditions = [ currentLocationIs Garden ]
          , changes = [ moveCharacterToLocation Harry Marsh, addInventory NoteFromHarry ]
          , narration = [ "He gives you a note, then runs off.", "I wonder what he wants?" ]
          }
        , { interaction = itemIsInInventory NoteFromHarry
          , conditions = []
          , changes = [ addLocation Marsh ]
          , narration = [ "It says, \"*Meet me in the marsh.*\"" ]
          }
        ]

When a rule matches multiple times (a player clicks the same story element multiple times), it will run through the list of narrations in order, one per click, repeating the final one when it reaches the end.

@docs Rule

## Interaction matchers

The following interaction matchers can be used in the `interaction` part of the rule record.

@docs InteractionMatcher, withItem, withLocation, withCharacter, withAnything, withAnyItem, withAnyLocation, withAnyCharacter


## Conditions

The following condition matchers can be used in the `conditions` part of the rule record.

@docs  Condition, itemIsInInventory , characterIsInLocation , itemIsInLocation , currentLocationIs, itemIsNotInInventory , characterIsNotInLocation , itemIsNotInLocation , currentLocationIsNot


## Changing the story world

You cannot change the story directly, but you can supply "commands" describing how the story state should change.

@docs ChangeWorldCommand, moveTo, addLocation, removeLocation, moveItemToInventory, moveCharacterToLocation, moveCharacterOffScreen, moveItemToLocation, moveItemToLocationFixed, moveItemOffScreen, loadScene, endStory

-}

import Types exposing (..)
import Types exposing (..)
import Engine.Manifest exposing (..)
import Engine.Scenes exposing (..)


-- Model


{-| A interactable story element -- and item, location, or character in your story that can be displayed and interacted with.
-}
type alias Interactable =
    Types.Interactable


{-| You'll need this type if you embed the engine in your own app.
-}
type Model
    = Model Types.Story


{-| This too
-}
type alias Msg =
    Types.Msg


{-| Initialize the `Model` for use when embedding in your own app.
-}
init :
    { items : List ( String, Attributes )
    , locations : List ( String, Attributes )
    , characters : List ( String, Attributes )
    }
    -> List ( String, List ( String, Rule ) )
    -> List ChangeWorldCommand
    -> Model
init manifest scenes setup =
    Model
        { history = []
        , manifest = Engine.Manifest.init manifest
        , scenes = Engine.Scenes.init scenes
        , currentScene = ""
        , currentLocation = ""
        , storyLine = []
        , theEnd = Nothing
        }
        |> changeWorld setup


{-| Get the current location to display
-}
getCurrentLocation :
    Model
    -> Maybe ( String, Attributes )
getCurrentLocation (Model story) =
    Engine.Manifest.getAttributes story.currentLocation story.manifest
        |> Maybe.map (\attrs -> ( story.currentLocation, attrs ))


{-| Get a list of the items in the current location to display
-}
getItemsInCurrentLocation :
    Model
    -> List ( String, Attributes )
getItemsInCurrentLocation (Model story) =
    Engine.Manifest.getItemsInLocation story.currentLocation story.manifest


{-| Get a list of the characters in the current location to display
-}
getCharactersInCurrentLocation :
    Model
    -> List ( String, Attributes )
getCharactersInCurrentLocation (Model story) =
    Engine.Manifest.getCharactersInLocation story.currentLocation story.manifest


{-| Get a list of the items in your inventory to display
-}
getItemsInInventory :
    Model
    -> List ( String, Attributes )
getItemsInInventory (Model story) =
    Engine.Manifest.getItemsInInventory story.manifest


{-| Get a list of the known locations to display
-}
getLocations :
    Model
    -> List ( String, Attributes )
getLocations (Model story) =
    Engine.Manifest.getLocations story.manifest


{-| Get the story revealed so far as a list of narration items.
-}
getStoryLine :
    Model
    -> List Narration
getStoryLine (Model story) =
    story.storyLine


{-| Get the story ending, if it has ended.  (Set with `EndStory`)
-}
getEnding : Model -> Maybe String
getEnding (Model story) =
    story.theEnd



-- Update


{-| Construct a `Msg` letting the engine know the user interacted with something (item, location, or character)
-}
interactMsg : String -> Msg
interactMsg =
    Interact


{-| The update function you'll need if embedding the engine in your own app to progress the `Model`
-}
update :
    Msg
    -> Model
    -> Model
update msg (Model story) =
    case msg of
        NoOp ->
            Model story

        Interact interactableId ->
            let
                defaultUpdate : Story
                defaultUpdate =
                    let
                        changes =
                            if Engine.Manifest.isLocation interactableId story.manifest then
                                [ MoveTo interactableId ]
                            else if Engine.Manifest.isItem interactableId story.manifest then
                                [ MoveItemToInventory interactableId ]
                            else
                                []
                    in
                        Model story
                            |> changeWorld changes
                            |> \(Model story) -> addNarration Nothing Nothing story

                addNarration : Maybe String -> Maybe String -> Story -> Story
                addNarration ruleName narration nextStory =
                    let
                        newNarration =
                            ( story.currentScene, ruleName, Engine.Manifest.getAttributes interactableId story.manifest, narration )
                    in
                        { nextStory | storyLine = newNarration :: story.storyLine }

                addHistory : Story -> Story
                addHistory story =
                    { story | history = story.history ++ [ interactableId ] }

                updateScenes : String -> Story -> Story
                updateScenes ruleId nextStory =
                    let
                        newScenes =
                            Engine.Scenes.update story.currentScene ruleId story.scenes
                    in
                        { nextStory | scenes = newScenes }

                updateStory : Maybe ( String, LiveRule ) -> Story
                updateStory rule =
                    case rule of
                        Nothing ->
                            defaultUpdate

                        Just ( ruleId, rule ) ->
                            Model story
                                |> changeWorld rule.changes
                                |> (\(Model story) -> addNarration (Just ruleId) (Engine.Scenes.getNarration rule) story)
                                |> updateScenes ruleId
            in
                findMatchingRule
                    { interactableId = interactableId
                    , currentLocationId = story.currentLocation
                    , manifest = story.manifest
                    , rules = (Engine.Scenes.getCurrentScene story.currentScene story.scenes)
                    }
                    |> updateStory
                    |> addHistory
                    |> Model


changeWorld :
    List ChangeWorldCommand
    -> Model
    -> Model
changeWorld changes (Model story) =
    let
        doChange change story =
            case change of
                MoveTo location ->
                    { story | currentLocation = location }

                LoadScene sceneName ->
                    { story | currentScene = sceneName }

                EndStory ending ->
                    { story | theEnd = Just ending }

                _ ->
                    { story
                        | manifest = Engine.Manifest.update change story.manifest
                    }
    in
        List.foldr doChange story changes
            |> Model



-- API


{-| A declarative rule, describing how to advance your story and under what conditions.
-}
type alias Rule =
    Types.Rule


{-| -}
type alias InteractionMatcher =
    Types.InteractionMatcher


{-| Will only match the `interaction` part of a story rule if the player interacted with the specified item.
-}
withItem : String -> InteractionMatcher
withItem item =
    WithItem item


{-| Will only match the `interaction` part of a story rule if the player interacted with the specified location.
-}
withLocation : String -> InteractionMatcher
withLocation location =
    WithLocation location


{-| Will only match the `interaction` part of a story rule if the player interacted with the specified character.
-}
withCharacter : String -> InteractionMatcher
withCharacter character =
    WithCharacter character


{-| Will match the `interaction` part of a story rule if the player interacted with any item (be careful about the the order and conditions of your rules since this matcher is so broad).
-}
withAnyItem : InteractionMatcher
withAnyItem =
    WithAnyItem


{-| Will match the `interaction` part of a story rule if the player interacted with any location (be careful about the the order and conditions of your rules since this matcher is so broad).
-}
withAnyLocation : InteractionMatcher
withAnyLocation =
    WithAnyLocation


{-| Will match the `interaction` part of a story rule if the player interacted with any character (be careful about the the order and conditions of your rules since this matcher is so broad).
-}
withAnyCharacter : InteractionMatcher
withAnyCharacter =
    WithAnyCharacter


{-| Will match the `interaction` part of a story rule every time (be careful about the the order and conditions of your rules since this matcher is so broad).
-}
withAnything : InteractionMatcher
withAnything =
    WithAnything


{-| -}
type alias Condition =
    Types.Condition


{-| Will only match if the supplied item is in the inventory.
-}
itemIsInInventory : String -> Condition
itemIsInInventory =
    ItemIsInInventory


{-| Will only match if the supplied item is *not* in the inventory.
-}
itemIsNotInInventory : String -> Condition
itemIsNotInInventory =
    ItemIsNotInInventory


{-| Will only match if the supplied character is in the supplied location.

The first String is a character id, the second is a location id.

    characterIsInLocation "Harry" "Marsh"
-}
characterIsInLocation : String -> String -> Condition
characterIsInLocation =
    CharacterIsInLocation


{-| Will only match if the supplied character is not in the supplied location.

The first String is a character id, the second is a location id.

    characterIsNotInLocation "Harry" "Marsh"
-}
characterIsNotInLocation : String -> String -> Condition
characterIsNotInLocation =
    CharacterIsNotInLocation


{-| Will only match if the supplied item is in the supplied location.

The first String is a item id, the second is a location id.

    itemIsInLocation "Umbrella" "Marsh"
-}
itemIsInLocation : String -> String -> Condition
itemIsInLocation =
    ItemIsInLocation


{-| Will only match if the supplied item is not in the supplied location.

The first String is a item id, the second is a location id.

    itemIsNotInLocation "Umbrella" "Marsh"
-}
itemIsNotInLocation : String -> String -> Condition
itemIsNotInLocation =
    ItemIsNotInLocation


{-| Will only match when the supplied location is the current location.
-}
currentLocationIs : String -> Condition
currentLocationIs =
    CurrentLocationIs


{-| Will only match when the supplied location is *not* the current location.
-}
currentLocationIsNot : String -> Condition
currentLocationIsNot =
    CurrentLocationIsNot


{-| -}
type alias ChangeWorldCommand =
    Types.ChangeWorldCommand


{-| Changes the current location.  The current location will be highlighted in the list of known locations, and will also be displayed at the top of the page, highlighted in the color defined for that location.  Any items or characters that are in the current location will also be shown for the player to interact with.
-}
moveTo : String -> ChangeWorldCommand
moveTo =
    MoveTo


{-| Adds a location to your list of known locations.  Any location on this list is available for the player to click on at any time.  This avoids clunky spatial navigation mechanics, but does mean that you will need to make rules to prevent against going to locations that are inaccessible (with appropriate narration).
-}
addLocation : String -> ChangeWorldCommand
addLocation =
    AddLocation


{-| Removes a location from your list of known locations.  You probably don't need this since once you know about a location you would always know about it, and trying to go to a location that is inaccessible for some reason could just give some narration telling why.  But maybe you will find a good reason to use it.
-}
removeLocation : String -> ChangeWorldCommand
removeLocation =
    RemoveLocation


{-| Adds an item to your inventory (if it was previously in a location, it will be removed from there, as items can only be in one place at once).  If the item is "fixed" this will not move it (if you want to "unfix" an item, use `moveItemOffScreen` or `MoveItemToLocation` first).

-}
moveItemToInventory : String -> ChangeWorldCommand
moveItemToInventory =
    MoveItemToInventory


{-| Adds a character to a location, or moves a character to a different location (characters can only be in one location at a time, or off-screen).  (Use moveTo to move yourself between locations.)

The first String is a character id, the second is a location id.

    moveCharacterToLocation "Harry" "Marsh"
-}
moveCharacterToLocation : String -> String -> ChangeWorldCommand
moveCharacterToLocation =
    MoveCharacterToLocation


{-| Moves a character "off-screen".  The character will not show up in any locations until you use `moveCharacterToLocation` again.
-}
moveCharacterOffScreen : String -> ChangeWorldCommand
moveCharacterOffScreen =
    MoveCharacterOffScreen


{-| Move an item to a location and set it as "fixed."  Fixed items are like scenery, they can be interacted with, but they cannot be added to inventory.

If it was in another location or your inventory before, it will remove it from there, as items can only be in one place at once.

The first String is an item id, the second is a location id.

    MoveItemToLocationFixed "Umbrella" "Marsh"
-}
moveItemToLocationFixed : String -> String -> ChangeWorldCommand
moveItemToLocationFixed =
    MoveItemToLocationFixed


{-| Move an item to a location.  If it was in another location or your inventory before, it will remove it from there, as items can only be in one place at once.

The first String is an item id, the second is a location id.

    MoveItemToLocation "Umbrella" "Marsh"
-}
moveItemToLocation : String -> String -> ChangeWorldCommand
moveItemToLocation =
    MoveItemToLocation


{-| Moves an item "off-screen" (either from a location or the inventory).  The item will not show up in any locations or inventory until you use `placeItem` or `addInventory` again.
-}
moveItemOffScreen : String -> ChangeWorldCommand
moveItemOffScreen =
    MoveItemOffScreen


{-| Rules are grouped into "scenes" for better organization and control.  This is how you switch between scenes when you want a different rule set.  You may want to switch scenes at a "turning point" in your story to bring about new rules for the next objective.

    scene1 = [...rules here...]
    scene2 = [...rules here...]

    -- in the `changes` part of a rule in a scene1:
    loadScene scene2
-}
loadScene : String -> ChangeWorldCommand
loadScene =
    LoadScene


{-| Sets a flag that the story has ended.  The string you provide can be used to signify the "type" of story ending ("good", "bad", "heroic", etc), or how many moves it took to complete, or anything else you like.  This has no effect on the framework, but you can use it in your client code how ever you like (change the view, calculate a score, etc).
-}
endStory : String -> ChangeWorldCommand
endStory ending =
    EndStory ending
