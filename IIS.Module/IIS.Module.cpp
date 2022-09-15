#include "pch.h"
#include <httpserv.h>

class IISModule;

typedef REQUEST_NOTIFICATION_STATUS(__stdcall* CallBackFunction)(IISModule*);

enum class ServerStringVariable
{
   ssvMethod,
   ssvProtocol,
   ssvURL,
   ssvQueryString,
   ssvPathInfo,
   ssvPathTranslated,
   ssvHTTPCacheControl,
   ssvHTTPDate,
   ssvHTTPAccept,
   ssvHTTPFrom,
   ssvHTTPHost,
   ssvHTTPIfModifiedSince,
   ssvHTTPReferer,
   ssvHTTPUserAgent,
   ssvHTTPContentEncoding,
   ssvContentType,
   ssvContentLength,
   ssvHTTPContentVersion,
   ssvHTTPDerivedFrom,
   ssvHTTPExpires,
   ssvHTTPTitle,
   ssvRemoteAddress,
   ssvRemoteHost,
   ssvScriptName,
   ssvServerPort,
   ssvNotDefined,
   ssvHTTPConnection,
   ssvHTTPCookie,
   ssvHTTPAuthorization
};

class IISModule : public CHttpModule
{
   private:
      CallBackFunction CallBack;

      IHttpContext* HTTPContext = 0;

      IMapPathProvider* Event = 0;

   public:
      IISModule(CallBackFunction Func) :
         CallBack(Func)
      {

      }

      REQUEST_NOTIFICATION_STATUS OnMapPath(_In_ IHttpContext* pHttpContext, _In_ IMapPathProvider* pProvider)
      {
         Event = pProvider;
         HTTPContext = pHttpContext;
         return CallBack(this);
      }

      PCSTR GetRequestHeader(PCSTR HeaderName, USHORT* ValueSize)
      {
         return HTTPContext->GetRequest()->GetHeader(HeaderName, ValueSize);
      }

      const PCSTR GetServerVariableName(ServerStringVariable Variable)
      {
         switch (Variable)
         {
            case ServerStringVariable::ssvMethod:
            {
               return "REQUEST_METHOD";
            }
            case ServerStringVariable::ssvURL:
            {
               return "URL";
            }
            case ServerStringVariable::ssvQueryString:
            {
               return "QUERY_STRING";
            }
            case ServerStringVariable::ssvContentLength:
            {
               return "CONTENT_LENGTH";
            }
            case ServerStringVariable::ssvContentType:
            {
               return "CONTENT_TYPE";
            }
            case ServerStringVariable::ssvPathInfo:
            {
               return "PATH_INFO";
            }
            case ServerStringVariable::ssvPathTranslated:
            {
                return "PATH_TRANSLATED";
            }
            case ServerStringVariable::ssvProtocol:
            {
               return "SERVER_PROTOCOL";
            }
            case ServerStringVariable::ssvHTTPCacheControl:
            {
               return "HTTP_CACHE_CONTROL";
            }
            case ServerStringVariable::ssvHTTPDate:
            {
               return "HTTP_DATE";
            }
            case ServerStringVariable::ssvHTTPAccept:
            {
               return "HTTP_ACCEPT";
            }
            case ServerStringVariable::ssvHTTPFrom:
            {
               return "HTTP_FROM";
            }
            case ServerStringVariable::ssvHTTPHost:
            {
               return "HTTP_HOST";
            }
            case ServerStringVariable::ssvHTTPIfModifiedSince:
            {
               return "HTTP_IF_MODIFIED_SINCE";
            }
            case ServerStringVariable::ssvHTTPReferer:
            {
               return "HTTP_REFERER";
            }
            case ServerStringVariable::ssvHTTPContentVersion:
            {
               return "HTTP_CONTENT_VERSION";
            }
            case ServerStringVariable::ssvHTTPDerivedFrom:
            {
               return "HTTP_DERIVED_FROM";
            }
            case ServerStringVariable::ssvHTTPExpires:
            {
               return "HTTP_EXPIRES";
            }
            case ServerStringVariable::ssvHTTPTitle:
            {
               return "HTTP_TITLE";
            }
            case ServerStringVariable::ssvHTTPContentEncoding:
            {
               return "HTTP_CONTENT_ENCODING";
            }
            case ServerStringVariable::ssvRemoteAddress:
            {
               return "REMOTE_ADDR";
            }
            case ServerStringVariable::ssvRemoteHost:
            {
               return "REMOTE_HOST";
            }
            case ServerStringVariable::ssvScriptName:
            {
               return "SCRIPT_NAME";
            }
            case ServerStringVariable::ssvServerPort:
            {
               return "SERVER_PORT";
            }
            case ServerStringVariable::ssvHTTPConnection:
            {
               return "HTTP_CONNECTION";
            }
            case ServerStringVariable::ssvHTTPAuthorization:
            {
               return "HTTP_AUTHORIZATION";
            }
            case ServerStringVariable::ssvHTTPCookie:
            {
               return "HTTP_COOKIE";
            }
         }

        return nullptr;
      }

      const void* GetServerVariable(ServerStringVariable Variable)
      {
         PCWSTR Buffer = nullptr;
         DWORD BufferSize = 0;

         HTTPContext->GetServerVariable(GetServerVariableName(Variable), &Buffer, &BufferSize);

         if (BufferSize)
            return Buffer;
         else
            return nullptr;
      }

      HRESULT ReadContent(void* Buffer, DWORD BufferSize, DWORD* BytesReaded)
      {
         BOOL Flag = 0;

         auto Request = HTTPContext->GetRequest();

         return Request->ReadEntityBody(Buffer, BufferSize, false, BytesReaded, &Flag);
      }

      void SetStatusCode(USHORT StatusCode, PCSTR Reason)
      {
         HTTPContext->GetResponse()->Clear();

         HTTPContext->GetResponse()->SetStatus(StatusCode, Reason, 0, S_OK, nullptr, TRUE);
      }

      void WriteHeader(PCSTR HeaderName, PCSTR Value, USHORT ValueSize)
      {
         HTTPContext->GetResponse()->SetHeader(HeaderName, Value, ValueSize, false);
      }

      void AppendEntityChunk(void *Buffer, DWORD Size)
      {
         BOOL Completed = 0;
         HTTP_DATA_CHUNK Chunk = {};
         Chunk.DataChunkType = HttpDataChunkFromMemory;
         Chunk.FromMemory.pBuffer = Buffer;
         Chunk.FromMemory.BufferLength = Size;

         HTTPContext->GetResponse()->WriteEntityChunks(&Chunk, 1, false, true, &Size, &Completed);
      }

      void Flush()
      {
         DWORD Size;
         BOOL Completed;

         HTTPContext->GetResponse()->Flush(false, false, &Size, &Completed);
      }
};

class ModuleFactory : public IHttpModuleFactory
{
   private:
      CallBackFunction CallBack;
   public:
      ModuleFactory(CallBackFunction Func) :
         CallBack(Func)
      {

      }

      HRESULT GetHttpModule(OUT CHttpModule** ppModule, IN IModuleAllocator* pAllocator)
      {
         UNREFERENCED_PARAMETER(pAllocator);

         auto pModule = new IISModule(CallBack);

         if (!pModule)
            return HRESULT_FROM_WIN32(ERROR_NOT_ENOUGH_MEMORY);
         else
         {
            *ppModule = pModule;

            return S_OK;
         }
      }

      void Terminate()
      {
         delete this;
      }
};

extern "C" __declspec(dllexport) HRESULT __stdcall RegisterModuleImplementation(IHttpModuleRegistrationInfo * pModuleInfo, CallBackFunction Func)
{
   return pModuleInfo->SetRequestNotifications(new ModuleFactory(Func), RQ_MAP_PATH, 0);
}

extern "C" __declspec(dllexport) const void __stdcall SetStatusCode(IISModule * Module, USHORT StatusCode, PCSTR Reason)
{
   Module->SetStatusCode(StatusCode, Reason);
}

extern "C" __declspec(dllexport) const void __stdcall WriteHeader(IISModule * Module, PCSTR HeaderName, PCSTR Value, USHORT ValueSize)
{
   Module->WriteHeader(HeaderName, Value, ValueSize);
}

extern "C" __declspec(dllexport) const void* __stdcall GetServerVariable(IISModule * Module, ServerStringVariable Variable)
{
   return Module->GetServerVariable(Variable);
}

extern "C" __declspec(dllexport) const void __stdcall AppendEntityChunk(IISModule * Module, void* Buffer, DWORD Size)
{
   Module->AppendEntityChunk(Buffer, Size);
}

extern "C" __declspec(dllexport) const void __stdcall Flush(IISModule *Module)
{
   Module->Flush();
}

extern "C" __declspec(dllexport) const HRESULT __stdcall ReadContent(IISModule * Module, void* Buffer, DWORD BufferSize, DWORD* BytesReaded)
{
   return Module->ReadContent(Buffer, BufferSize, BytesReaded);
}

extern "C" __declspec(dllexport) const PCSTR __stdcall ReadHeader(IISModule * Module, PCSTR HeaderName, USHORT* ValueSize)
{
   return Module->GetRequestHeader(HeaderName, ValueSize);
}

extern "C" __declspec(dllexport) const DWORD __stdcall WriteClient(IISModule * Module, void* Buffer, DWORD Size, bool MoreChunkToSend)
{
   Module->AppendEntityChunk(Buffer, Size);

   Module->Flush();

   return Size;
}
