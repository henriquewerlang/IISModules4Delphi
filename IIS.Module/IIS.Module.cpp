#include "pch.h"
#include <httpserv.h>

class IISModule;

typedef REQUEST_NOTIFICATION_STATUS(__stdcall* CallBackFunction)(IISModule*);

enum class ServerStringVariable
{
   svMethod,
   svProtocol,
   svURL,
   svQueryString,
   svPathInfo,
   svPathTranslated,
   svHTTPCacheControl,
   svHTTPDate,
   svHTTPAccept,
   svHTTPFrom,
   svHTTPHost,
   svHTTPIfModifiedSince,
   svHTTPReferer,
   svHTTPUserAgent,
   svHTTPContentEncoding,
   svContentType,
   svContentLength,
   svHTTPContentVersion,
   svHTTPDerivedFrom,
   svHTTPExpires,
   svHTTPTitle,
   svRemoteAddress,
   svRemoteHost,
   svScriptName,
   svServerPort,
   svHTTPConnection,
   svHTTPCookie,
   svHTTPAuthorization
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

   const void* GetServerVariable(ServerStringVariable Variable)
   {
      switch (Variable)
      {
      case ServerStringVariable::svMethod:
      {
         return HTTPContext->GetRequest()->GetHttpMethod();
      }
      case ServerStringVariable::svURL:
      {
         return Event->GetUrl();
      }
      case ServerStringVariable::svQueryString:
      {
         return HTTPContext->GetRequest()->GetRawHttpRequest()->CookedUrl.pQueryString;
      }
      case ServerStringVariable::svContentLength:
      {
         return HTTPContext->GetRequest()->GetHeader(HttpHeaderContentLength, nullptr);
      }
      case ServerStringVariable::svContentType:
      {
         return HTTPContext->GetRequest()->GetHeader(HttpHeaderContentType, nullptr);
      }
      case ServerStringVariable::svProtocol:
      case ServerStringVariable::svPathInfo:
      case ServerStringVariable::svPathTranslated:
      case ServerStringVariable::svHTTPCacheControl:
      case ServerStringVariable::svHTTPDate:
      case ServerStringVariable::svHTTPAccept:
      case ServerStringVariable::svHTTPFrom:
      case ServerStringVariable::svHTTPHost:
      case ServerStringVariable::svHTTPIfModifiedSince:
      case ServerStringVariable::svHTTPReferer:
      case ServerStringVariable::svHTTPUserAgent:
      case ServerStringVariable::svHTTPContentVersion:
      case ServerStringVariable::svHTTPDerivedFrom:
      case ServerStringVariable::svHTTPExpires:
      case ServerStringVariable::svHTTPTitle:
      case ServerStringVariable::svHTTPContentEncoding:
      case ServerStringVariable::svRemoteAddress:
      case ServerStringVariable::svRemoteHost:
      case ServerStringVariable::svScriptName:
      case ServerStringVariable::svServerPort:
      case ServerStringVariable::svHTTPConnection:
      case ServerStringVariable::svHTTPCookie:
      case ServerStringVariable::svHTTPAuthorization:
      {
         return nullptr;
      }
      }

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

   void WriteClient(void* Buffer, DWORD* Size)
   {
      BOOL Completed;
      HTTP_DATA_CHUNK Chunk;
      Chunk.DataChunkType = HttpDataChunkFromMemory;
      Chunk.FromMemory.pBuffer = Buffer;
      Chunk.FromMemory.BufferLength = *Size;

      auto Result = HTTPContext->GetResponse()->WriteEntityChunks(&Chunk, 1, false, false, Size, &Completed);

      *Size = Chunk.FromMemory.BufferLength;

      if (Result != S_OK)
         Result = S_OK;
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

extern "C" __declspec(dllexport) const DWORD __stdcall WriteClient(IISModule * Module, void* Buffer, DWORD Size)
{
   Module->WriteClient(Buffer, &Size);

   return Size;
}

extern "C" __declspec(dllexport) const HRESULT __stdcall ReadContent(IISModule * Module, void* Buffer, DWORD BufferSize, DWORD* BytesReaded)
{
   return Module->ReadContent(Buffer, BufferSize, BytesReaded);
}

extern "C" __declspec(dllexport) const PCSTR __stdcall ReadHeader(IISModule * Module, PCSTR HeaderName, USHORT* ValueSize)
{
   return Module->GetRequestHeader(HeaderName, ValueSize);
}
