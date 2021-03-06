module Actor.Component.TransformComponent exposing
    ( calculateCompletionPercentage
    , getMovingTowardsData
    , getNewPosition
    , isActorMoving
    , isMoving
    , isMovingAt
    , isMovingDown
    , isNotMoving
    , isNotMovingAt
    , movingTicks
    , startMovingTowards
    , updateTransformComponent
    )

import Actor.Actor as Actor
    exposing
        ( Actor
        , Component(..)
        , Level
        , MovingState(..)
        , MovingTowardsData
        , TransformComponentData
        )
import Actor.Common as Common
import Data.Direction as Direction exposing (Direction)
import Data.Position as Position exposing (Position)
import Dict
import Maybe.Extra


movingTicks : Int
movingTicks =
    4


updateTransformComponent : TransformComponentData -> Actor -> Level -> Level
updateTransformComponent transformData actor level =
    getMovingTowardsData transformData
        |> Maybe.andThen
            (\towardsData ->
                if towardsData.tickCountLeft > 0 then
                    -- Still moving
                    Dict.insert
                        "transform"
                        (TransformComponent
                            { transformData
                                | movingState =
                                    MovingTowards
                                        { towardsData
                                            | tickCountLeft = towardsData.tickCountLeft - 1
                                            , completionPercentage = calculateCompletionPercentage towardsData.totalTickCount towardsData.tickCountLeft
                                        }
                            }
                        )
                        actor.components
                        |> Common.updateComponents actor
                        |> Common.updateActor level.actors
                        |> Common.updateActors level
                        |> Just

                else
                    -- Finished moving
                    Dict.insert
                        "transform"
                        (TransformComponent
                            { position = towardsData.position
                            , movingState = NotMoving
                            }
                        )
                        actor.components
                        |> Common.updateComponents actor
                        |> Common.updateActor level.actors
                        |> Common.updateActors level
                        |> Common.removeActorFromIndexByPosition transformData.position actor.id
                        |> Common.addActorToIndex towardsData.position actor.id
                        |> Just
            )
        |> Maybe.withDefault level


calculateCompletionPercentage : Int -> Int -> Float
calculateCompletionPercentage totalTickCount tickCountLeft =
    100 / toFloat totalTickCount * toFloat (totalTickCount - tickCountLeft)


getMovingTowardsData : TransformComponentData -> Maybe MovingTowardsData
getMovingTowardsData transformData =
    case transformData.movingState of
        MovingTowards towardsData ->
            Just towardsData

        NotMoving ->
            Nothing


isActorMoving : Actor -> Bool
isActorMoving actor =
    Common.getTransformComponent actor
        |> Maybe.map isMoving
        |> Maybe.withDefault False


isMoving : TransformComponentData -> Bool
isMoving transformData =
    getMovingTowardsData transformData
        |> Maybe.Extra.isJust


isNotMoving : TransformComponentData -> Bool
isNotMoving transformComponent =
    isMoving transformComponent |> not


isMovingAt : Position -> Level -> Bool
isMovingAt position level =
    Common.getActorsByPosition position level
        |> List.map Common.getTransformComponent
        |> Maybe.Extra.values
        |> List.filter isMoving
        |> List.isEmpty
        |> not


isNotMovingAt : Position -> Level -> Bool
isNotMovingAt position level =
    isMovingAt position level
        |> not


getNewPosition : Direction -> TransformComponentData -> ( TransformComponentData, Position )
getNewPosition direction transformData =
    ( transformData, Position.addPosition transformData.position (Position.getOffsetFromDirection direction) )


isMovingDown : TransformComponentData -> Bool
isMovingDown transformData =
    getMovingTowardsData transformData
        |> Maybe.Extra.filter
            (\towardsData ->
                Position.addPosition transformData.position (Position.getOffsetFromDirection Direction.Down) == towardsData.position
            )
        |> Maybe.Extra.isJust


startMovingTowards : Actor -> TransformComponentData -> Position -> Direction -> Level -> Level
startMovingTowards actor transformData newPosition direction level =
    Dict.insert
        "transform"
        (TransformComponent
            { transformData
                | movingState =
                    MovingTowards
                        { position = newPosition
                        , totalTickCount = movingTicks
                        , tickCountLeft = movingTicks
                        , completionPercentage = 0.0
                        , direction = direction
                        }
            }
        )
        actor.components
        |> Common.updateComponents actor
        |> Common.updateActor level.actors
        |> Common.updateActors level
