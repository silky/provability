module Modal where
import Control.Applicative hiding ((<|>))
import Data.List
import Data.Maybe
import Data.Map (Map)
import qualified Data.Map as M
import Text.Parsec
import Text.Parsec.Expr
import Text.Parsec.Language
import Text.Parsec.String
import Text.Parsec.Token

-- Example usage:
-- findGeneralGLFixpoint $ M.fromList [("a",read "~ [] b"), ("b", read "[] (a -> [] ~ b)")]
-- Alternatively:
-- findGeneralGLFixpoint $ makeEquivs [("a", "~ [] b"), ("b", "[] (a -> [] ~ b)")]


-- Modal Logic Formula data structure
data ModalFormula v = Val {value :: Bool}
                    | Var {variable :: v}
                    | Neg {contents :: ModalFormula v}
                    | And {left, right :: ModalFormula v}
                    | Or  {left, right :: ModalFormula v}
                    | Imp {left, right :: ModalFormula v}
                    | Iff {left, right :: ModalFormula v}
                    | Box {contents :: ModalFormula v}
                    | Dia {contents :: ModalFormula v}
                    deriving (Eq, Ord)

-- Syntactic Conveniences:
infixr   4 %=
(%=) :: ModalFormula v -> ModalFormula v -> ModalFormula v
(%=) = Iff

infixr   5 %>
(%>) :: ModalFormula v -> ModalFormula v -> ModalFormula v
(%>) = Imp

infixl   6 %|
(%|) :: ModalFormula v -> ModalFormula v -> ModalFormula v
(%|) = Or

infixl   7 %^
(%^) :: ModalFormula v -> ModalFormula v -> ModalFormula v
(%^) = And

ff :: ModalFormula v
ff = Val False

tt :: ModalFormula v
tt = Val True

holdsk :: Int -> ModalFormula v -> ModalFormula v
holdsk 0 phi = phi
holdsk k phi = Neg (incon k) `Imp` phi
  where
    incon 0 = ff
    incon n = Box $ incon (n-1)

-- Operator like function that encodes "provable in S+Con^k(S)", where
-- "S" is the original system.
boxk :: Int -> ModalFormula v -> ModalFormula v
boxk k phi = Box (holdsk k phi)

diak :: Int -> ModalFormula v -> ModalFormula v
diak k phi = Dia (holdsk k phi)

-- Data structure to be mapped across a formula.
data ModalEvaluator v a = ModalEvaluator {
    handleVal :: Bool -> a ,
    handleVar :: v -> a,
    handleNeg :: a -> a,
    handleAnd :: a -> a -> a,
    handleOr  :: a -> a -> a,
    handleImp :: a -> a -> a,
    handleIff :: a -> a -> a,
    handleBox :: a -> a,
    handleDia :: a -> a}

idModalEvaluator :: ModalEvaluator v (ModalFormula v)
idModalEvaluator = ModalEvaluator {
  handleVar = Var, handleVal = Val, handleNeg = Neg,
  handleAnd = And, handleOr  = Or, handleImp = Imp, handleIff = Iff,
  handleBox = Box, handleDia = Dia }

-- And how to use it to map:
modalEval :: ModalEvaluator v a -> ModalFormula v -> a
modalEval m = f where
  f (Val v) = (handleVal m) v
  f (Var v) = (handleVar m) v
  f (Neg x) = (handleNeg m) (f x)
  f (And x y) = (handleAnd m) (f x) (f y)
  f (Or  x y) = (handleOr m) (f x) (f y)
  f (Imp x y) = (handleImp m) (f x) (f y)
  f (Iff x y) = (handleIff m) (f x) (f y)
  f (Box x) = (handleBox m) (f x)
  f (Dia x) = (handleDia m) (f x)

instance Show v => Show (ModalFormula v) where
  showsPrec _ (Val l) = showString $ if l then "T" else "F"
  showsPrec _ (Var v) = showString $ show v
  showsPrec p (Neg x) = showParen (p > 8) $ showString "~ " . showsPrec 8 x
  showsPrec p (And x y) = showParen (p > 7) $ showsPrec 7 x . showString " && " . showsPrec 8 y
  showsPrec p (Or  x y) = showParen (p > 6) $ showsPrec 6 x . showString " || " . showsPrec 7 y
  showsPrec p (Imp x y) = showParen (p > 5) $ showsPrec 6 x . showString " -> " . showsPrec 5 y
  showsPrec p (Iff x y) = showParen (p > 4) $ showsPrec 5 x . showString " <-> " . showsPrec 4 y
  showsPrec p (Box x) = showParen (p > 8) $ showString "[] " . showsPrec 8 x
  showsPrec p (Dia x) = showParen (p > 8) $ showString "<> " . showsPrec 8 x

--------------------------------------------------------------------------------

formulaParser :: Read v => Parser (ModalFormula v)
formulaParser = buildExpressionParser table term <?> "ModalFormula"
  where
    table = [ [prefix $ choice [ (m_reservedOp "~" >> return Neg)
                               , (m_reservedOp "[]" >> return Box)
                               , (m_reservedOp "[0]" >> return Box)
                               , (m_reservedOp "[1]" >> return (boxk 1))
                               , (m_reservedOp "[2]" >> return (boxk 2))
                               , (m_reservedOp "[3]" >> return (boxk 3))
                               , (m_reservedOp "[4]" >> return (boxk 4))
                               , (m_reservedOp "[5]" >> return (boxk 5))
                               , (m_reservedOp "[6]" >> return (boxk 6))
                               , (m_reservedOp "[7]" >> return (boxk 7))
                               , (m_reservedOp "[8]" >> return (boxk 8))
                               , (m_reservedOp "[9]" >> return (boxk 9))
                               , (m_reservedOp "<>" >> return Dia)
                               , (m_reservedOp "<0>" >> return Dia)
                               , (m_reservedOp "<1>" >> return (diak 1))
                               , (m_reservedOp "<2>" >> return (diak 2))
                               , (m_reservedOp "<3>" >> return (diak 3))
                               , (m_reservedOp "<4>" >> return (diak 4))
                               , (m_reservedOp "<5>" >> return (diak 5))
                               , (m_reservedOp "<6>" >> return (diak 6))
                               , (m_reservedOp "<7>" >> return (diak 7))
                               , (m_reservedOp "<8>" >> return (diak 8))
                               , (m_reservedOp "<9>" >> return (diak 9))
                               ] ]
            , [Infix (m_reservedOp "&&" >> return And) AssocLeft]
            , [Infix (m_reservedOp "||" >> return  Or) AssocLeft]
            , [Infix (m_reservedOp "->" >> return Imp) AssocRight]
            , [Infix (m_reservedOp "<->" >> return Iff) AssocRight]
            ]

    term = m_parens formulaParser
           <|> m_braces formulaParser
           <|> (m_reserved "T" >> return (Val True))
           <|> (m_reserved "F" >> return (Val False))
           <|> fmap (Var . read) m_identifier

    -- To work-around Parsec's limitation for prefix operators:
    prefix  p = Prefix  . chainl1 p $ return (.)

    TokenParser { parens = m_parens
                , braces = m_braces
                , identifier = m_identifier
                , reservedOp = m_reservedOp
                , reserved = m_reserved
                , semiSep1 = _
                , whiteSpace = _ } =
      makeTokenParser emptyDef { commentStart = "{-"
                               , commentEnd = "-}"
                               , identStart = letter
                               , identLetter = letter
                               , opStart = oneOf "~-<[&|"
                               , opLetter = oneOf "~-<>[]&|123456789"
                               , reservedOpNames = [ "~", "&&", "||", "->", "<->", "[]", "<>"
                                                   , "[1]", "[2]", "[3]", "[4]", "[5]", "[6]", "[7]", "[8]", "[9]"
                                                   , "<1>", "<2>", "<3>", "<4>", "<5>", "<6>", "<7>", "<8>", "<9>" ]
                               , reservedNames = ["T", "F"]
                               , caseSensitive = False
                               }

instance Read v => Read (ModalFormula v) where
  readsPrec _ s = case parse (formulaParser <* eof) "" s of
    Right result -> [(result,"")]
    -- We could just return the remaining string, but Parsec gives
    -- much nicer errors. So we ask it to consume the whole input and
    -- fail if it fails.
    Left err -> error $ show err

--------------------------------------------------------------------------------

-- Nesting Depth of Modal Operators
maxModalDepthHandler :: ModalEvaluator v Int
maxModalDepthHandler = ModalEvaluator {
    handleVal = const 0, handleVar = const 0,
    handleNeg = id,
    handleAnd = max, handleOr = max, handleImp = max, handleIff = max,
    handleBox = (1+), handleDia = (1+)}
maxModalDepth :: ModalFormula v -> Int
maxModalDepth = modalEval maxModalDepthHandler

-- Propositional evaluation of the modal formula

propositionalEvalHandler :: ModalEvaluator v (Maybe Bool)
propositionalEvalHandler = ModalEvaluator {
    handleVal = Just,
    handleVar = const Nothing,
    handleNeg = fmap not,
    handleAnd = liftA2 (&&),
    handleOr  = liftA2 (||),
    handleImp = liftA2 (<=),
    handleIff = liftA2 (==),
    handleBox = const Nothing,
    handleDia = const Nothing}

propositionalEval :: ModalFormula v -> Maybe Bool
propositionalEval = modalEval propositionalEvalHandler

-- Evaluate the modal formula assuming the soundness of the system

evalWithSoundnessHandler :: ModalEvaluator v (Maybe Bool)
evalWithSoundnessHandler = ModalEvaluator {
    handleVal = Just,
    handleVar = const Nothing,
    handleNeg = fmap not,
    handleAnd = liftA2 (&&),
    handleOr  = liftA2 (||),
    handleImp = liftA2 (<=),
    handleIff = liftA2 (==),
    handleBox = (\x -> if x == Just False then Just False else Nothing),
    handleDia = (\x -> if x == Just True then Just True else Nothing)}

evalWithSoundness :: ModalFormula v -> Maybe Bool
evalWithSoundness = modalEval evalWithSoundnessHandler

-- How to simplify modal formulas:
mapFormulaOutput :: (Bool -> Bool) -> ModalFormula v -> ModalFormula v
mapFormulaOutput f formula = g (f False) (f True)
  where
    g True True = (Val True)
    g False False = (Val False)
    g False True = formula
    g True False = (Neg formula)

simplifyBinaryOperator :: (ModalFormula v -> ModalFormula v -> ModalFormula v) ->
                          (Bool -> Bool -> Bool) ->
                          ModalFormula v -> ModalFormula v ->
                          ModalFormula v
simplifyBinaryOperator _  behavior (Val a) (Val b) = Val (behavior a b)
simplifyBinaryOperator _  behavior (Val a) formula =
  mapFormulaOutput (\b -> behavior a b) formula
simplifyBinaryOperator _  behavior formula (Val b) =
  mapFormulaOutput (\a -> behavior a b) formula
simplifyBinaryOperator op _ f1 f2 = op f1 f2

simplifyNeg :: ModalFormula v -> ModalFormula v
simplifyNeg (Val v) = (Val (not v))
simplifyNeg (Neg x) = x
simplifyNeg x = (Neg x)

simplifyBox :: ModalFormula v -> ModalFormula v
simplifyBox t@(Val True) = t
simplifyBox x = (Box x)

simplifyDia :: ModalFormula v -> ModalFormula v
simplifyDia f@(Val False) = f
simplifyDia x = (Dia x)


simplifyHandler :: ModalEvaluator v (ModalFormula v)
simplifyHandler =  ModalEvaluator {
    handleVal = Val,
    handleVar = Var,
    handleNeg = simplifyNeg,
    handleAnd = simplifyBinaryOperator And (&&),
    handleOr  = simplifyBinaryOperator Or (||),
    handleImp = simplifyBinaryOperator Imp (<=),
    handleIff = simplifyBinaryOperator Iff (==),
    handleBox = simplifyBox,
    handleDia = simplifyDia}

simplify :: ModalFormula v -> ModalFormula v
simplify = modalEval simplifyHandler

-- GL Eval in standard model
glEvalHandler :: ModalEvaluator v [Bool]
glEvalHandler = ModalEvaluator {
    handleVal = repeat,
    handleVar = error "Variables are not supported in GLEval.",
    handleNeg = fmap not,
    handleAnd = zipWith (&&),
    handleOr  = zipWith (||),
    handleImp = zipWith (<=),
    handleIff = zipWith (==),
    handleBox = scanl (&&) True,
    handleDia = scanl (||) False}

glEval :: ModalFormula v -> [Bool]
glEval = modalEval glEvalHandler

glEvalStandard :: ModalFormula v -> Bool
glEvalStandard formula = (glEval formula) !! (maxModalDepth formula)

simplifiedMaxDepth :: ModalFormula v -> Int
simplifiedMaxDepth formula =
  depth - (length $ (!!0) $ group $ reverse results) + 1 where
    results = take (depth+1) (glEval formula)
    depth = maxModalDepth formula

fixpointGLEval :: Eq v => v -> ModalFormula v -> [Bool]
fixpointGLEval var fi = result
  where
    evalHandler = glEvalHandler{handleVar = \var' ->
        if var == var' then result
        else error "Variable other than the fixpoint in fixpointGLEval"}
    result = modalEval evalHandler fi

generalFixpointGLEval :: Ord v => Map v (ModalFormula v) -> Map v [Bool]
generalFixpointGLEval formulaMap = evalMap
  where
    evalMap = M.map (modalEval evalHandler) formulaMap
    evalHandler = glEvalHandler{handleVar=(\var -> case M.lookup var evalMap of
        Just l -> l
        Nothing -> error "Unmapped variable in generalFixpointGLEval")}

-- Finding the fixedpoints

-- Check whether the length of a list is at least n without infinite looping.
lengthAtLeast :: Int -> [a] -> Bool
lengthAtLeast 0 _ = True
lengthAtLeast _ [] = False
lengthAtLeast n (_:xs) = lengthAtLeast (n-1) xs

-- Find the fixpoint of a list, given a length of run after which we should conclude we found it.
findFixpoint :: (Eq a) => Int -> [a] -> a
findFixpoint n xs = (!!0) $ fromJust $ find (lengthAtLeast n) $ group xs


-- Find the Fixpoint for a Modal formula
findGLFixpoint :: Eq v => v -> ModalFormula v -> Bool
findGLFixpoint var formula = findFixpoint (1+(maxModalDepth formula)) (fixpointGLEval var formula)

-- Find the Fixpoint for a collection of Modal formulas
makeEquivs :: Read v => [(String, String)] -> Map String (ModalFormula v)
makeEquivs = M.fromList . map (\(v, f) -> (v, read f))

generalGLEvalSeq :: Ord v => Map v (ModalFormula v)-> [Map v Bool]
generalGLEvalSeq formulaMap = map level [0..]
  where
    level n = M.map (!!n) result
    result = generalFixpointGLEval formulaMap

findGeneralGLFixpoint :: (Eq v, Ord v) => Map v (ModalFormula v) -> Map v Bool
findGeneralGLFixpoint formulaMap = findFixpoint (1+maxFormulaDepth) results where
  results = generalGLEvalSeq formulaMap
  maxFormulaDepth = maximum $ map maxModalDepth $ M.elems formulaMap
