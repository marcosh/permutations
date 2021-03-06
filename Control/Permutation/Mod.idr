module Control.Permutation.Mod

import Prelude.Nat
import Data.List
import Data.Vect
import Control.Permutation.Types
import Data.Vect

%default total

%access public export

mutual
  even : Nat -> Bool
  even Z = True
  even (S k) = odd k

  odd : Nat -> Bool
  odd Z = False
  odd (S k) = even k

private
natToFin : (n : Nat) -> Fin (S n)
natToFin Z = FZ
natToFin (S k) = FS k' where k' = natToFin k

||| This permutation reverses a vector completely
reverse : Permutation n
reverse {n=Z} = []
reverse {n=S _} = last :: reverse

private
finiteL : (n : Nat) -> Vect (S n) (Fin (S n))
finiteL Z = FZ :: Nil
finiteL n@(S m) = natToFin n :: (map weaken $ finiteL m)

factorial : Nat -> Nat
factorial Z = S Z
factorial (S k) = (S k) * factorial k

combine : Vect m (a -> b) -> Vect n a -> Vect (m * n) b
combine {m} {n} fs xs = rewrite multCommutative m n in
                                concat $ map (g fs) xs
  where
    g : Vect m (a -> b) -> a -> Vect m b
    g fs x = fs <*> pure x

||| All permutations of a certain order.
export
enumerateStrict : Vect (factorial n) (Permutation n)
enumerateStrict {n=Z} = Nil :: Nil
enumerateStrict {n=S Z} = ((FZ :: Nil) :: Nil)
enumerateStrict {n=n@(S m)} = combine (map (::) (finiteL m)) enumerateStrict

||| Show where an integer is sent.
||| @p A permutation
||| @m The integer
fixNat : (p : Permutation n) -> (m : Fin n) -> Fin n
fixNat p m = index m $ (toVector p)
  where
    index : Fin l -> Lazy (Vect l e) -> e
    index FZ     (x::xs) = x
    index (FS k) (x::xs) = index k xs

||| Orbit generated by a given element.
||| @p A permutation
||| @i The starting point
orbit : (p : Permutation (S n)) -> (i : Fin (S n)) -> Stream (Fin (S n))
orbit p {n} i = i :: go i where
  go : Fin (S n) -> Stream (Fin (S n))
  go j = next :: go next where
    next : Fin (S n)
    next = fixNat p j

||| Return the orbit of some permutation.
finOrbit : Permutation (S n) -> Fin (S n) -> List (Fin (S n))
finOrbit p {n} i = nub $ take (S n) (orbit p i)

||| Return a list of disjoint cycles given a permutation. We use this for our
||| pretty-printer.
export
cycles : Permutation (S n) -> List (List (Fin (S n)))
cycles p {n} = nubBy g . map (finOrbit p) . enumFromTo 0 $ (natToFin n)
  where
    g : List (Fin (S n)) -> List (Fin (S n)) -> Bool
    g x y = and $ map (Delay . flip elem y) x

export
order : Permutation (S n) -> Nat
order = foldr lcm 1 . map length . cycles

private
checkId : String -> String
checkId "" = "id"
checkId x = x

implementation Show (Permutation (S n)) where
  show {n} p = checkId (concatMap (go n) (cycles p))
    where
      go : (Show a) => Nat -> List a -> String
      go _ l@(_::_::_) = if n <= 9
        then "(" ++ concatMap show l ++ ")"
        else "(" ++ concat ((intersperse "," . map show) l) ++ ")"
      go _ _ = ""

private
fill : Fin n -> Permutation n
fill FZ = neutral
fill (FS k) = FS (zeros k) :: fill k
  where zeros : Fin m -> Fin m
        zeros FZ = FZ
        zeros (FS _) = FZ

||| The permutation π_ij
export
pi : Fin n -> Fin n -> Permutation n
pi (FS j) (FS k) = FZ :: pi j k
pi (FS j) FZ = FS j :: fill j
pi FZ (FS k) = FS k :: fill k
pi FZ FZ = neutral

||| For S_4, (1234)
export
circulate : Permutation n
circulate {n=Z} = Nil
circulate {n=S Z} = FZ :: Nil
circulate {n=S (S m)} = foldl (<+>) neutral pis
  where
    pis : List (Permutation (S (S m)))
    pis = zipWith pi (enumFromTo 0 (weaken $ natToFin m)) (enumFromTo 1 (natToFin (S m)))

||| Factors a permutation into a product of swaps.
export
swaps : Permutation n -> List (Permutation n)
swaps {n=Z} _ = []
swaps {n=n@(S _)} p = go overlaps p
  where
    go : (List (Fin (S n)) -> List (Permutation (S n))) -> Permutation (S n) -> List (Permutation (S n))
    go f p = (>>= f) $ cycles p
    overlaps (x::xs@(y::ys)) = pi x y :: overlaps xs
    overlaps x = []

||| Test whether a permutation is even.
export
isEven : Permutation n -> Bool
isEven = even . length . swaps
