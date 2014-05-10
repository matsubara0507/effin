{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Control.Effect.Lift (
    Lift, runLift, lift
) where

import Control.Monad.Effect
import Control.Monad (join, liftM)

-- | An effect described by a monad.
-- All monads are functors, but not all `Monad`s have `Functor` instances.
-- By wrapping a monad in the `Lift` effect, all monads can be used without
-- having to provide a `Functor` instance for each one.
newtype Lift m a = Lift { unLift :: m a }

instance Monad m => Functor (Lift m) where
    fmap f = Lift . liftM f . unLift

type EffectLift m es = (Member (Lift m) es, m ~ LiftType es, Monad m)
type family LiftType es where
    LiftType (Lift m ': es) = m
    LiftType (e ': es) = LiftType es

-- | Lifts a monadic value into an effect.
lift :: EffectLift m es => m a -> Effect es a
lift = send . Lift

-- | Converts a computation containing only monadic
-- effects into a monadic computation.
runLift :: Monad m => Effect '[Lift m] a -> m a
runLift =
    handle return
    $ eliminate (join . unLift)
    $ emptyRelay
