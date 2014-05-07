{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Control.Effect.State (
    EffectState, State, runState,
    evalState, execState,
    get, gets, put,
    modify, modify',
    state, withState
) where

import Control.Applicative ((<$>))
import Control.Monad.Effect (Effect, Member, send, handle, eliminate, relay)

data State s a = State (s -> (s, a))

type EffectState s es = (Member (State s) es, s ~ StateType es)
type family StateType es where
    StateType (State s ': es) = s
    StateType (e ': es) = StateType es

get :: EffectState s es => Effect es s
get = send $ State $ \s -> (s, s)

gets :: EffectState s es => (s -> s) -> Effect es s
gets f = f <$> get

put :: EffectState s es => s -> Effect es ()
put x = send $ State $ const (x, ())

modify :: EffectState s es => (s -> s) -> Effect es ()
modify f = get >>= put . f

modify' :: EffectState s es => (s -> s) -> Effect es ()
modify' f = do
    x <- get
    put $! f x

state :: EffectState s es => (s -> (s, a)) -> Effect es a
state = send . State

withState :: EffectState s es => (s -> s) -> Effect es a -> Effect es a
withState f x = modify f >> x

runState :: s -> Effect (State s ': es) a -> Effect es (s, a)
runState = flip $
    handle (\x s -> return (s, x))
    $ eliminate (\k (State f) s -> let (s', x) = f s in k x s')
    $ relay (\k x s -> do
        x' <- send x
        k x' s)

evalState :: s -> Effect (State s ': es) a -> Effect es a
evalState s = fmap snd . runState s

execState :: s -> Effect (State s ': es) a -> Effect es s
execState s = fmap fst . runState s
