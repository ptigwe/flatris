{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE MultiWayIf #-}

module Update where

import Control.Arrow
import Data.Function
import qualified Data.Map.Lazy as M
import Data.Monoid
import Miso
import qualified Miso.String as S

import Action
import Model
import Tetromino

foreign import javascript unsafe "$r = performance.now();" now ::
               IO Double

-- | Updates model, optionally introduces side effects
updateModel :: Action -> Model -> Effect Model Action
updateModel Resume model@Model {..} = noEff model {state = Playing}
updateModel Start model@Model {..} = noEff model {state = Playing}
updateModel Pause model@Model {..} = noEff model {state = Paused}
updateModel Rotate model@Model {..} = noEff model {rotation = newRotation}
  where
    newRotation = rotation {isActive = True}
updateModel MoveLeft model@Model {..} =
  noEff model {movement = newMovement, arrows = newArrows}
  where
    newMovement = movement {isActive = True}
    newArrows = (\(x, y) -> (-1, y)) arrows
updateModel MoveRight model@Model {..} =
  noEff model {movement = newMovement, arrows = newArrows}
  where
    newMovement = movement {isActive = True}
    newArrows = (\(x, y) -> (1, y)) arrows
updateModel (Time newTime) model = step newModel
  where
    newModel = model {delta = newTime - time model, time = newTime}
updateModel (GetArrows arr@Arrows {..}) model@Model {..} = step newModel
  where
    newModel = model {arrows = (arrowX, arrowY)} & checkArrows
updateModel Init model@Model {..} = model <# (Time <$> now)
updateModel _ model@Model {..} = noEff model

checkArrows :: Model -> Model
checkArrows model@Model {..} = model & checkMovement & checkRotation & checkDrop

checkMovement :: Model -> Model
checkMovement model@Model {..} = model {movement = newMovement}
  where
    newMovement = movement {isActive = isActive movement || fst arrows /= 0}

checkRotation :: Model -> Model
checkRotation model@Model {..} = model {rotation = newRotation}
  where
    newRotation = rotation {isActive = isActive rotation || snd arrows == 1}

checkDrop :: Model -> Model
checkDrop = id

step :: Model -> Effect Model Action
step model@Model {..} = k <# (Time <$> now)
  where
    k =
      model & updateAnimation & moveTetromino & rotateTetromino & dropTetromino &
      checkEndGame

updateAnimation :: Model -> Model
updateAnimation model@Model {..} =
  model {rotation = newRotation, movement = newMovement}
  where
    newRotation = updateAnimation_ time rotation
    newMovement = updateAnimation_ time movement

updateAnimation_ :: Double -> AnimationState -> AnimationState
updateAnimation_ time state@AnimationState {..} =
  state {ticks = newTicks, isAnimated = newAnimated}
  where
    newTicks = getTicks time delay
    newAnimated = newTicks /= ticks

getTicks :: Double -> Int -> Int
getTicks time delay = floor time `div` delay

moveTetromino :: Model -> Model
moveTetromino model@Model {..} = model {x = newX, movement = newMovement}
  where
    (newX, newisActive) = move_ movement x (fst arrows)
    newMovement = movement {isActive = newisActive}

move_ :: AnimationState -> Int -> Int -> (Int, Bool)
move_ state@AnimationState {..} x dir =
  if isAnimated && isActive
    then (min 7 . max (x + dir) $ 0, False)
    else (x, isActive)

rotateTetromino :: Model -> Model
rotateTetromino model@Model {..} =
  model {active = newActive, rotation = newRotation}
  where
    (newActive, newisActive) = rotate_ rotation active
    newRotation = rotation {isActive = newisActive}

rotate_ :: AnimationState -> [[Int]] -> ([[Int]], Bool)
rotate_ state@AnimationState {..} tetro =
  if isAnimated && isActive
    then (rotate tetro, False)
    else (tetro, isActive)

dropTetromino :: Model -> Model
dropTetromino = id

checkEndGame :: Model -> Model
checkEndGame = id
