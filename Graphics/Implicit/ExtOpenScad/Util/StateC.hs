-- Implicit CAD. Copyright (C) 2011, Christopher Olah (chris@colah.ca)
-- Copyright 2016, Julia Longtin (julial@turinglace.com)
-- Released under the GNU AGPLV3+, see LICENSE

-- Allow us to use explicit foralls when writing function type declarations.
{-# LANGUAGE ExplicitForAll #-}

-- FIXME: required. why?
{-# LANGUAGE KindSignatures, FlexibleContexts #-}
{-# LANGUAGE RankNTypes, ScopedTypeVariables #-}

module Graphics.Implicit.ExtOpenScad.Util.StateC (getVarLookup, modifyVarLookup, lookupVar, pushVals, getVals, putVals, withPathShiftedBy, getPath, getRelPath, errorC, mapMaybeM, StateC, CompState(CompState)) where

import Prelude(FilePath, IO, String, Maybe(Just, Nothing), Show, Monad, fmap, (.), ($), (++), return, putStrLn, show)

import Graphics.Implicit.ExtOpenScad.Definitions(VarLookup, OVal)

import Data.Map (lookup)
import Control.Monad.State (StateT, get, put, modify, liftIO)
import System.FilePath((</>))
import Control.Monad.IO.Class (MonadIO)
import Data.Kind (Type)

-- | This is the state of a computation. It contains a hash of variables, an array of OVals, and a path.
newtype CompState = CompState (VarLookup, [OVal], FilePath)

type StateC = StateT CompState IO

getVarLookup :: StateC VarLookup
getVarLookup = fmap (\(CompState (a,_,_)) -> a) get

modifyVarLookup :: (VarLookup -> VarLookup) -> StateC ()
modifyVarLookup = modify . (\f (CompState (a,b,c)) -> CompState (f a, b, c))

-- | Perform a variable lookup
lookupVar :: String -> StateC (Maybe OVal)
lookupVar name = do
    varlookup <- getVarLookup
    return $ lookup name varlookup

pushVals :: [OVal] -> StateC ()
pushVals vals = modify (\(CompState (a,b,c)) -> CompState (a, vals ++ b, c))

getVals :: StateC [OVal]
getVals = do
    (CompState (_,b,_)) <- get
    return b

putVals :: [OVal] -> StateC ()
putVals vals = do
    (CompState (a,_,c)) <- get
    put $ CompState (a,vals,c)

withPathShiftedBy :: FilePath -> StateC a -> StateC a
withPathShiftedBy pathShift s = do
    (CompState (a,b,path)) <- get
    put $ CompState (a, b, path </> pathShift)
    x <- s
    (CompState (a',b',_)) <- get
    put $ CompState (a', b', path)
    return x

-- | Return the path stored in the state.
getPath :: StateC FilePath
getPath = do
    (CompState (_,_,c)) <- get
    return c

getRelPath :: FilePath -> StateC FilePath
getRelPath relPath = do
    path <- getPath
    return $ path </> relPath

errorC :: forall (m :: Type -> Type) a. (Show a, MonadIO m) => a -> a -> String -> m ()
errorC lineN columnN err = liftIO $ putStrLn $ "On line " ++ show lineN ++ ", column " ++ show columnN ++ ": " ++ err
{-# INLINABLE errorC #-}

mapMaybeM :: forall t (m :: Type -> Type) a. Monad m => (t -> m a) -> Maybe t -> m (Maybe a)
mapMaybeM f (Just a) = do
    b <- f a
    return (Just b)
mapMaybeM _ Nothing = return Nothing
