{-# LANGUAGE ScopedTypeVariables, QuasiQuotes, TemplateHaskell, OverloadedStrings #-}
module TestPerfOdbc where
import Database.ODBC.SQLServer
import Database.ODBC.TH
import System.IO
import qualified Data.List.Split as SP
import Control.Monad
import Control.Exception 
import TestConnectionString (connstr)
import qualified Data.Text as T
import Data.String
import qualified Data.ByteString.Char8 as B
import Data.ByteString (ByteString)
import Helper (time)

createTable :: String -> IO ()
createTable tab = do
  putStrLn $ "create table " ++ tab
  bracket (connect $ T.pack connstr) close $ \conn -> do
    exec conn 
    $ fromString 
    $ concat ["IF OBJECT_ID('dbo." ++ tab ++ "', 'U') IS NOT NULL DROP TABLE dbo." ++ tab ++ ";"
             ,"create table " ++ tab ++ " (a int, b varchar(1000), c float)"]
 
perf :: FilePath -> IO ()  
perf fn = do
  createTable "OdbcTH" 
  createTable "OdbcRaw" 
  createTable "OdbcRawCommit" 
  time "odbc TH" $ testOdbcTH fn  
  time "odbc raw" $ testOdbcRaw fn 
  time "odbc raw commit" $ testOdbcRawCommit fn 
  
testOdbcTH :: FilePath -> IO ()  
testOdbcTH fn = do
  xs <- readFile fn
  bracket (connect $ T.pack connstr) close $ \conn -> do
    forM_ (zip [1::Int ..] (SP.splitOn "\t" <$> lines xs)) $ \(n,[i,s,d]) -> do
      let ii :: Int = read i
      let dd :: Double = read d
      let ss :: ByteString = B.pack s
      exec conn [sql|insert into OdbcTH values ($ii,$ss,$dd)|]

testOdbcRaw :: FilePath -> IO ()  
testOdbcRaw fn = do
  xs <- readFile fn
  bracket (connect (T.pack connstr)) close $ \conn -> do
    forM_ (zip [1::Int ..] (SP.splitOn "\t" <$> lines xs)) $ \(n,[i,s,d]) -> do
      exec conn (fromString ("insert into OdbcRaw values(" ++ i ++ ",'" ++ s ++ "'," ++ d ++ ")"))

testOdbcRawCommit :: FilePath -> IO ()  
testOdbcRawCommit fn = do
  xs <- readFile fn
  bracket (connect (T.pack connstr)) close $ \conn -> do
    exec conn "set implicit_transactions off"
    forM_ (zip [1::Int ..] (SP.splitOn "\t" <$> lines xs)) $ \(n,[i,s,d]) -> do
      exec conn (fromString ("insert into OdbcRawCommit values(" ++ i ++ ",'" ++ s ++ "'," ++ d ++ ")"))
