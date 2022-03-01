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

   const void* GetServerVariable(ServerStringVariable Variable)
   {
      switch (Variable)
      {
      case ServerStringVariable::ssvMethod:
      {
         return HTTPContext->GetRequest()->GetHttpMethod();
      }
      case ServerStringVariable::ssvURL:
      {
         return Event->GetUrl();
      }
      case ServerStringVariable::ssvQueryString:
      {
         return HTTPContext->GetRequest()->GetRawHttpRequest()->CookedUrl.pQueryString;
      }
      case ServerStringVariable::ssvContentLength:
      {
         return HTTPContext->GetRequest()->GetHeader(HttpHeaderContentLength, nullptr);
      }
      case ServerStringVariable::ssvContentType:
      {
         return HTTPContext->GetRequest()->GetHeader(HttpHeaderContentType, nullptr);
      }
      case ServerStringVariable::ssvHTTPCookie:
      {
         return HTTPContext->GetRequest()->GetHeader(HttpHeaderCookie, nullptr);
      }
      case ServerStringVariable::ssvProtocol:
      case ServerStringVariable::ssvPathInfo:
      case ServerStringVariable::ssvPathTranslated:
      case ServerStringVariable::ssvHTTPCacheControl:
      case ServerStringVariable::ssvHTTPDate:
      case ServerStringVariable::ssvHTTPAccept:
      case ServerStringVariable::ssvHTTPFrom:
      case ServerStringVariable::ssvHTTPHost:
      case ServerStringVariable::ssvHTTPIfModifiedSince:
      case ServerStringVariable::ssvHTTPReferer:
      case ServerStringVariable::ssvHTTPContentVersion:
      case ServerStringVariable::ssvHTTPDerivedFrom:
      case ServerStringVariable::ssvHTTPExpires:
      case ServerStringVariable::ssvHTTPTitle:
      case ServerStringVariable::ssvHTTPContentEncoding:
      case ServerStringVariable::ssvRemoteAddress:
      case ServerStringVariable::ssvRemoteHost:
      case ServerStringVariable::ssvScriptName:
      case ServerStringVariable::ssvServerPort:
      case ServerStringVariable::ssvHTTPConnection:
      case ServerStringVariable::ssvHTTPAuthorization:
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

   void WriteClient(void* Buffer, DWORD* Size, bool MoreChunkToSend)
   {
      BOOL Completed;
      HTTP_DATA_CHUNK Chunk;
      Chunk.DataChunkType = HttpDataChunkFromMemory;
      Chunk.FromMemory.pBuffer = Buffer;
      Chunk.FromMemory.BufferLength = *Size;

      auto Result = HTTPContext->GetResponse()->WriteEntityChunks(&Chunk, 1, false, MoreChunkToSend, Size, &Completed);

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

extern "C" __declspec(dllexport) const DWORD __stdcall WriteClient(IISModule * Module, void* Buffer, DWORD Size, bool MoreChunkToSend)
{
   Module->WriteClient(Buffer, &Size, MoreChunkToSend);

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
