{-# LANGUAGE MagicHash #-}
{-# LANGUAGE TypeApplications #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}
--  C->Haskell Compiler: Marshalling library
--
--  Copyright (c) [1999...2005] Manuel M T Chakravarty
--
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions are met:
--
--  1. Redistributions of source code must retain the above copyright notice,
--     this list of conditions and the following disclaimer.
--  2. Redistributions in binary form must reproduce the above copyright
--     notice, this list of conditions and the following disclaimer in the
--     documentation and/or other materials provided with the distribution.
--  3. The name of the author may not be used to endorse or promote products
--     derived from this software without specific prior written permission.
--
--  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
--  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
--  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
--  NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
--  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
--  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
--  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
--  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
--  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
--- Description ---------------------------------------------------------------
--
--  Language: Haskell 98
--
--  This module provides the marshaling routines for Haskell files produced by
--  C->Haskell for binding to C library interfaces.  It exports all of the
--  low-level FFI (language-independent plus the C-specific parts) together
--  with the C->HS-specific higher-level marshalling routines.
--

module Foreign.CUDA.Internal.C2HS (

  -- * Composite marshalling functions
  withCStringLenIntConv, peekCStringLenIntConv, withIntConv, withFloatConv,
  peekIntConv, peekFloatConv, withBool, peekBool, withEnum, peekEnum,
  peekArrayWith,

  -- * Conditional results using 'Maybe'
  nothingIf, nothingIfNull,

  -- * Bit masks
  combineBitMasks, containsBitMask, extractBitMasks,

  -- * Conversion between C and Haskell types
  cIntConv, cFloatConv, cToBool, cFromBool, cToEnum, cFromEnum
) where


import Foreign
import Foreign.C
import Control.Monad                                    ( liftM )

import GHC.Int
import GHC.Word
import GHC.Base


-- Composite marshalling functions
-- -------------------------------

-- Strings with explicit length
--
withCStringLenIntConv :: String -> (CStringLen -> IO a) -> IO a
withCStringLenIntConv s f = withCStringLen s $ \(p, n) -> f (p, cIntConv n)

peekCStringLenIntConv :: CStringLen -> IO String
peekCStringLenIntConv (s, n) = peekCStringLen (s, cIntConv n)

-- Marshalling of numerals
--

withIntConv :: (Storable b, Integral a, Integral b) => a -> (Ptr b -> IO c) -> IO c
withIntConv = with . cIntConv

withFloatConv :: (Storable b, RealFloat a, RealFloat b) => a -> (Ptr b -> IO c) -> IO c
withFloatConv = with . cFloatConv

peekIntConv :: (Storable a, Integral a, Integral b) => Ptr a -> IO b
peekIntConv = liftM cIntConv . peek

peekFloatConv :: (Storable a, RealFloat a, RealFloat b) => Ptr a -> IO b
peekFloatConv = liftM cFloatConv . peek

-- Passing Booleans by reference
--

withBool :: (Integral a, Storable a) => Bool -> (Ptr a -> IO b) -> IO b
withBool = with . fromBool

peekBool :: (Integral a, Storable a) => Ptr a -> IO Bool
peekBool = liftM toBool . peek


-- Read and marshal array elements
--

peekArrayWith :: Storable a => (a -> b) -> Int -> Ptr a -> IO [b]
peekArrayWith f n p = map f `fmap` peekArray n p


-- Passing enums by reference
--

withEnum :: (Enum a, Integral b, Storable b) => a -> (Ptr b -> IO c) -> IO c
withEnum = with . cFromEnum

peekEnum :: (Enum a, Integral b, Storable b) => Ptr b -> IO a
peekEnum = liftM cToEnum . peek


{-
-- Storing of 'Maybe' values
-- -------------------------

instance Storable a => Storable (Maybe a) where
  sizeOf    _ = sizeOf    (undefined :: Ptr ())
  alignment _ = alignment (undefined :: Ptr ())

  peek p = do
             ptr <- peek (castPtr p)
             if ptr == nullPtr
               then return Nothing
               else liftM Just $ peek ptr

  poke p v = do
               ptr <- case v of
                        Nothing -> return nullPtr
                        Just v' -> new v'
               poke (castPtr p) ptr
-}


-- Conditional results using 'Maybe'
-- ---------------------------------

-- Wrap the result into a 'Maybe' type.
--
-- * the predicate determines when the result is considered to be non-existing,
--   ie, it is represented by `Nothing'
--
-- * the second argument allows to map a result wrapped into `Just' to some
--   other domain
--
nothingIf :: (a -> Bool) -> (a -> b) -> a -> Maybe b
nothingIf p f x = if p x then Nothing else Just $ f x

-- |Instance for special casing null pointers.
--
nothingIfNull :: (Ptr a -> b) -> Ptr a -> Maybe b
nothingIfNull = nothingIf (== nullPtr)


-- Support for bit masks
-- ---------------------

-- Given a list of enumeration values that represent bit masks, combine these
-- masks using bitwise disjunction.
--
combineBitMasks :: (Enum a, Num b, Bits b) => [a] -> b
combineBitMasks = foldl (.|.) 0 . map (fromIntegral . fromEnum)

-- Tests whether the given bit mask is contained in the given bit pattern
-- (i.e., all bits set in the mask are also set in the pattern).
--
containsBitMask :: (Num a, Bits a, Enum b) => a -> b -> Bool
bits `containsBitMask` bm = let bm' = fromIntegral . fromEnum $ bm
                            in
                            bm' .&. bits == bm'

-- |Given a bit pattern, yield all bit masks that it contains.
--
-- * This does *not* attempt to compute a minimal set of bit masks that when
--   combined yield the bit pattern, instead all contained bit masks are
--   produced.
--
extractBitMasks :: (Num a, Bits a, Enum b, Bounded b) => a -> [b]
extractBitMasks bits =
  [bm | bm <- [minBound..maxBound], bits `containsBitMask` bm]


-- Conversion routines
-- -------------------

-- |Integral conversion
--
{-# INLINE [1] cIntConv #-}
cIntConv :: (Integral a, Integral b) => a -> b
cIntConv  = fromIntegral

-- This is enough to fix the missing specialisation for mallocArray, but perhaps
-- we should implement a more general solution which avoids the use of
-- fromIntegral entirely (in particular, without relying on orphan instances).
--
{-# RULES
  "fromIntegral/Int->CInt"     fromIntegral = toEnum @CInt;
  "fromIntegral/Int->CLLong"   fromIntegral = \(I# i#) -> CLLong (I64# i#) ;
 #-}
{-# RULES
  "fromIntegral/Int->CUInt"    fromIntegral = toEnum @CUInt;
  "fromIntegral/Int->CULLong"  fromIntegral = \(I# i#) -> CULLong (W64# (int2Word# i#)) ;
 #-}

  -- The C 'long' type might be 32- or 64-bits wide
  --
  -- "fromIntegral/Int->CLong"    fromIntegral = \(I# i#) -> CLong (I64# i#) ;
  -- "fromIntegral/Int->CULong"   fromIntegral = \(I# i#) -> CULong (W64# (int2Word# i#)) ;

-- |Floating conversion
--
{-# INLINE [1] cFloatConv #-}
cFloatConv :: (RealFloat a, RealFloat b) => a -> b
cFloatConv  = realToFrac

-- As this conversion by default goes via `Rational', it can be very slow...
{-# RULES
  "realToFrac/Float->Float"    realToFrac = \(x::Float) -> x ;
  "realToFrac/Float->CFloat"   realToFrac = \(x::Float) -> CFloat x ;
  "realToFrac/CFloat->Float"   realToFrac = \(CFloat x) -> x ;
 #-}
{-# RULES
  "realToFrac/Double->Double"  realToFrac = \(x::Double) -> x;
  "realToFrac/Double->CDouble" realToFrac = \(x::Double) -> CDouble x ;
  "realToFrac/CDouble->Double" realToFrac = \(CDouble x) -> x ;
 #-}

-- |Obtain C value from Haskell 'Bool'.
--
{-# INLINE [1] cFromBool #-}
cFromBool :: Num a => Bool -> a
cFromBool  = fromBool

-- |Obtain Haskell 'Bool' from C value.
--
{-# INLINE [1] cToBool #-}
cToBool :: (Eq a, Num a) => a -> Bool
cToBool  = toBool

-- |Convert a C enumeration to Haskell.
--
{-# INLINE [1] cToEnum #-}
cToEnum :: (Integral i, Enum e) => i -> e
cToEnum  = toEnum . cIntConv

-- |Convert a Haskell enumeration to C.
--
{-# INLINE [1] cFromEnum #-}
cFromEnum :: (Enum e, Integral i) => e -> i
cFromEnum  = cIntConv . fromEnum
