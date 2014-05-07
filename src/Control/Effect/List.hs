{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Control.Effect.List (
    EffectList, List, runList,
    choose, never, select,

    EffectCut, Cut,
    cut, runCut
) where

import Control.Arrow (second)
import Control.Applicative (Alternative (..), (<$>))
import Control.Monad (MonadPlus (..), (<=<), join)
import Control.Monad.Effect (Effect, Member, send, handle, eliminate, intercept, defaultRelay)

newtype List a = List [a]

type EffectList = Member List

choose :: EffectList es => [a] -> Effect es a
choose = send . List

never :: EffectList es => Effect es a
never = choose []

select :: EffectList es => [Effect es a] -> Effect es a
select = join . choose

runList :: Effect (List ': es) a -> Effect es [a]
runList =
    handle (\x -> return [x])
    $ eliminate (\k (List xs) -> concat <$> mapM k xs)
    $ defaultRelay

instance EffectList es => Alternative (Effect es) where
    empty = never
    x <|> y = select [x, y]

instance EffectList es => MonadPlus (Effect es) where
    mzero = empty
    mplus = (<|>)

data Cut a = Cut

type EffectCut = Member Cut

cut :: (EffectList es, EffectCut es) => Effect es a
cut = send Cut

runCut :: EffectList es => Effect (Cut ': es) a -> Effect es a
runCut = choose . snd <=< reifyCut
  where
    -- Gather the results of a computation into a list (like in runList), but
    -- also return a Bool indicating whether a cut was performed in the
    -- computation. When we intercept the List effect, we get a continuation and
    -- a list of values. If we map the continuation to the list of values, then
    -- we get a list of computations. We can now execute each computation one by
    -- one, and inspect the Bool after each computation to determine when we
    -- should stop.
    reifyCut :: EffectList es => Effect (Cut ': es) a -> Effect es (Bool, [a])
    reifyCut =
        handle (\x -> return (False, [x]))
        $ eliminate (\_ Cut -> return (True, []))
        $ intercept (\k (List xs) -> runAll (map k xs))
        $ defaultRelay

    runAll [] = return (False, [])
    runAll (x:xs) = do
        (cutRequested, x') <- x
        if cutRequested
        then return (True, x')
        else second (x' ++) <$> runAll xs
