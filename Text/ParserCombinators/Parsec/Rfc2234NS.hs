{- |
   Module      :  Text.ParserCombinators.Parsec.Rfc2234
   Copyright   :  (c) 2013 Peter Simons
   License     :  BSD3

   Maintainer  :  phlummox2@gmail.com
   Stability   :  provisional
   Portability :  portable

   This module provides parsers for the grammar defined in
   RFC2234, \"Augmented BNF for Syntax Specifications:
   ABNF\", <http://www.faqs.org/rfcs/rfc2234.html>. The
   terminal called @char@ in the RFC is called 'character'
   here to avoid conflicts with Parsec's 'char' function.

   Addendum for Nonstandard Version:
   This module deviates from the RFC currently in 
        * none currently.

   These allowances are subject to change, and should not be
   used when parsing incoming messages, only for parsing messages
   that have been stored on disk. The goal of these nonstandard
   Parsers is to provide a higher probability of parsing _common_
   Headers (rather than only those explicitly defined in the RFC)
   as well as allowing for potential oddities / changes that may
   occur during storage of an email message. These parsers have
   be rebranded so as not to conflict with the standard parsers
   available from the excellent 'hsemail' package, upon which
   this package depends. For patches to this package only (namely
   'hsemail-ns', patches should be sent to <phlummox2@gmail.com>, 
   for patches to the Proper parsers, you can send them to the
   original maintainer. 
 -}

module Text.ParserCombinators.Parsec.Rfc2234NS where

import Text.ParserCombinators.Parsec
import Data.Char ( toUpper, chr, ord )
import Control.Monad ( liftM2 )

-- Customize hlint ...
{-# ANN module "HLint: ignore Use camelCase" #-}

----------------------------------------------------------------------
-- * Parser Combinators
----------------------------------------------------------------------

-- |Case-insensitive variant of Parsec's 'char' function.

caseChar        :: Char -> CharParser st Char
caseChar c       = satisfy (\x -> toUpper x == toUpper c)

-- |Case-insensitive variant of Parsec's 'string' function.

caseString      :: String -> CharParser st ()
caseString cs    = mapM_ caseChar cs <?> cs

-- |Match a parser at least @n@ times.

manyN           :: Int -> GenParser a b c -> GenParser a b [c]
manyN n p
    | n <= 0     = return []
    | otherwise  = liftM2 (++) (count n p) (many p)

-- |Match a parser at least @n@ times, but no more than @m@ times.

manyNtoM        :: Int -> Int -> GenParser a b c -> GenParser a b [c]
manyNtoM n m p
    | n < 0      = return []
    | n > m      = return []
    | n == m     = count n p
    | n == 0     = foldr (<|>) (return []) (map (\x -> try $ count x p) (reverse [1..m]))
    | otherwise  = liftM2 (++) (count n p) (manyNtoM 0 (m-n) p)

-- |Helper function to generate 'Parser'-based instances for
-- the 'Read' class.

parsec2read :: Parser a -> String -> [(a, String)]
parsec2read f x  = either (error . show) id (parse f' "" x)
  where
  f' = do { a <- f; res <- getInput; return [(a,res)] }


----------------------------------------------------------------------
-- * Primitive Parsers
----------------------------------------------------------------------

-- |Match any character of the alphabet.

alpha           :: CharParser st Char
alpha            = satisfy (\c -> c `elem` (['A'..'Z'] ++ ['a'..'z']))
                   <?> "alphabetic character"

-- |Match either \"1\" or \"0\".

bit             :: CharParser st Char
bit              = oneOf "01"   <?> "bit ('0' or '1')"

-- |Match any 7-bit US-ASCII character except for NUL (ASCII value 0, that is).

character       :: CharParser st Char
character        = satisfy (\c -> (c >= chr 1) && (c <= chr 127))
                   <?> "7-bit character excluding NUL"

-- |Match the carriage return character @\\r@.

cr              :: CharParser st Char
cr               = char '\r'    <?> "carriage return"

-- |Match returns the linefeed character @\\n@.

lf              :: CharParser st Char
lf               = char '\n'    <?> "linefeed"

-- |Match the Internet newline @\\r\\n@.

crlf            :: CharParser st String
crlf             = do c <- cr
                      l <- lf
                      return [c,l]
                   <?> "carriage return followed by linefeed"

-- | Non-standard newline - matches any of crlf, lfcr, cr, lf
-- (in that order)
crlfNS          :: CharParser st String
crlfNS          = (choice . map try) [cr >> lf, lf >> cr, cr, lf] >>= 
                      return . return 
                      <?> "eol sequence"

-- |Match any US-ASCII control character. That is
-- any character with a decimal value in the range of [0..31,127].

ctl             :: CharParser st Char
ctl              = satisfy (\c -> ord c `elem` ([0..31] ++ [127]))
                   <?> "control character"

-- |Match the double quote character \"@\"@\".

dquote          :: CharParser st Char
dquote           = char (chr 34)    <?> "double quote"

-- |Match any character that is valid in a hexadecimal number;
-- [\'0\'..\'9\'] and [\'A\'..\'F\',\'a\'..\'f\'] that is.

hexdig          :: CharParser st Char
hexdig           = hexDigit    <?> "hexadecimal digit"

-- |Match the tab (\"@\\t@\") character.

htab            :: CharParser st Char
htab             = char '\t'    <?> "horizontal tab"

-- |Match \"linear white-space\". That is any number of consecutive
-- 'wsp', optionally followed by a 'crlf' and (at least) one more
-- 'wsp'.

lwsp            :: CharParser st String
lwsp             = do r <- choice
                           [ many1 wsp
                           , try (liftM2 (++) crlfNS (many1 wsp))
                           ]
                      rs <- option [] lwsp
                      return (r ++ rs)
                   <?> "linear white-space"

-- |Match /any/ character.
octet           :: CharParser st Char
octet            = anyChar    <?> "any 8-bit character"

-- |Match the space.

sp              :: CharParser st Char
sp               = char ' '    <?> "space"

-- |Match any printable ASCII character. (The \"v\" stands for
-- \"visible\".) That is any character in the decimal range of
-- [33..126].

vchar           :: CharParser st Char
vchar            = satisfy (\c -> (c >= chr 33) && (c <= chr 126))
                   <?> "printable character"

-- |Match either 'sp' or 'htab'.

wsp             :: CharParser st Char
wsp              = sp <|> htab    <?> "white-space"


-- ** Useful additions

-- |Match a \"quoted pair\". Any characters (excluding CR and
-- LF) may be quoted.

quoted_pair     :: CharParser st String
quoted_pair      = do _ <- char '\\'
                      r <- noneOf "\r\n"
                      return ['\\',r]
                   <?> "quoted pair"

-- |Match a quoted string. The specials \"@\\@\" and
-- \"@\"@\" must be escaped inside a quoted string; CR and
-- LF are not allowed at all.

quoted_string   :: CharParser st String
quoted_string    = do _ <- dquote
                      r <- many qcont
                      _ <- dquote
                      return ("\"" ++ concat r ++ "\"")
                   <?> "quoted string"
  where
  qtext = noneOf "\\\"\r\n"
  qcont = many1 qtext <|> quoted_pair
