{-# LANGUAGE NamedFieldPuns #-}
module Network.VCR
    ( server
    ) where

import           Control.Exception          (SomeException)
import qualified Data.ByteString.Char8      as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Network.HTTP.Client        as HC
import qualified Network.HTTP.Conduit       as HC
import qualified Network.HTTP.Proxy         as HProxy (Request (..),
                                                       Settings (..),
                                                       defaultProxySettings,
                                                       httpProxyApp)
import qualified Network.HTTP.Types         as HT
import qualified Network.Wai                as Wai
import qualified Network.Wai.Handler.Warp   as Warp



import           Control.Applicative        ((<**>))
import           Network.VCR.Middleware     (die, middleware)
import           Network.VCR.Types          (Options (..), parseOptions)
import           Options.Applicative        (execParser, fullDesc, header,
                                             helper, info, progDesc)
import           System.Environment         (getArgs)


server :: IO ()
server = execParser opts >>= run
  where
    opts = info (parseOptions <**> helper)
      ( fullDesc
     <> progDesc "Run the VCR proxy to replay or record API calls. Runs in replay mode by default."
     <> header "VCR Proxy" )

run :: Options -> IO ()
run Options { mode, cassettePath, port } = do
  putStrLn $ "Starting VCR proxy, mode: " <> show mode  <> ", cassette file: " <> cassettePath <>  ", listening on port: " <> show port
  mgr <- HC.newManager HC.tlsManagerSettings
  Warp.runSettings (warpSettings settings) $ middleware mode cassettePath $ HProxy.httpProxyApp settings mgr
    where
      settings = HProxy.defaultProxySettings { HProxy.proxyPort = port }


warpSettings :: HProxy.Settings -> Warp.Settings
warpSettings pset = Warp.setPort (HProxy.proxyPort pset)
    . Warp.setHost (HProxy.proxyHost pset)
    . Warp.setTimeout (HProxy.proxyTimeout pset)
    . Warp.setOnExceptionResponse defaultExceptionResponse
    $ Warp.setNoParsePath True Warp.defaultSettings

defaultExceptionResponse :: SomeException -> Wai.Response
defaultExceptionResponse e =
        Wai.responseLBS HT.badGateway502
                [ (HT.hContentType, "text/plain; charset=utf-8") ]
                $ LBS.fromChunks [BS.pack $ show e]


