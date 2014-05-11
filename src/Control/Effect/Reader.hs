{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

#if MTL
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
#endif

module Control.Effect.Reader (
	EffectReader, Reader, runReader,
    ask, asks, local
) where

import Control.Monad.Effect

#ifdef MTL
import qualified Control.Monad.Reader.Class as R

instance EffectReader r es => R.MonadReader r (Effect es) where
    ask = ask
    local = local
    reader = asks
#endif

-- | An effect that describes an implicit environment.
newtype Reader r a = Reader (r -> a)
  deriving Functor

type EffectReader r es = (Member (Reader r) es, r ~ ReaderType es)
type family ReaderType es where
    ReaderType (Reader r ': es) = r
    ReaderType (e ': es) = ReaderType es

-- | Retrieves the current environment.
ask :: EffectReader r es => Effect es r
ask = asks id

-- | Retrieves a value that is a function of the current environment.
asks :: EffectReader r es => (r -> a) -> Effect es a
asks = send . Reader

-- | Runs a computation with a modified environment.
local :: EffectReader r es => (r -> r) -> Effect es a -> Effect es a
local f effect = do
    env <- asks f
    run env effect
  where
    run env =
        handle return
        $ intercept (bind env)
        $ defaultRelay

-- | Completely handes a `Reader` effect by providing an
-- environment value to be used throughout the computation.
runReader :: r -> Effect (Reader r ': es) a -> Effect es a
runReader env =
    handle return
    $ eliminate (bind env)
    $ defaultRelay

bind :: r -> Reader r (Effect es b) -> Effect es b
bind env (Reader k) = k env
