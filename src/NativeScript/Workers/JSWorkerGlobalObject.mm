#include "JSWorkerGlobalObject.h"
#include "JSErrors.h"
#include "WorkerMessagingProxy.h"

#include "JSClientData.h"
#include <JavaScriptCore/runtime/JSMicrotask.h>
#include <JavaScriptCore/runtime/JSONObject.h>

using namespace JSC;

namespace NativeScript {

static EncodedJSValue JSC_HOST_CALL jsWorkerGlobalObjectClose(ExecState* execState) {
    JSWorkerGlobalObject* globalObject = jsCast<JSWorkerGlobalObject*>(execState->lexicalGlobalObject());
    globalObject->close();
    return JSValue::encode(jsUndefined());
}

static EncodedJSValue JSC_HOST_CALL jsWorkerGlobalObjectPostMessage(ExecState* exec) {
    JSWorkerGlobalObject* globalObject = jsCast<JSWorkerGlobalObject*>(exec->lexicalGlobalObject());
    auto scope = DECLARE_THROW_SCOPE(exec->vm());

    if (exec->argumentCount() < 1)
        return throwVMError(exec, scope, createError(exec, "postMessage function expects at least one argument."_s));

    JSValue message = exec->argument(0);
    JSArray* transferList = nullptr;

    if (exec->argumentCount() >= 2 && !exec->argument(1).isUndefinedOrNull()) {
        JSValue arg2 = exec->argument(1);
        if (!arg2.isCell() || !(transferList = jsDynamicCast<JSArray*>(exec->vm(), arg2.asCell()))) {
            return throwVMError(exec, scope, createError(exec, "The second parameter of postMessage must be array, null or undefined."_s));
        }
    }

    globalObject->postMessage(exec, message, transferList);
    return JSValue::encode(jsUndefined());
}

const ClassInfo JSWorkerGlobalObject::s_info = { "NativeScriptWorkerGlobal", &Base::s_info, nullptr, nullptr, CREATE_METHOD_TABLE(JSWorkerGlobalObject) };

void JSWorkerGlobalObject::finishCreation(VM& vm, WTF::String applicationPath) {
    Base::finishCreation(vm, applicationPath);

    _onmessageIdentifier = Identifier::fromString(&vm, "onmessage");

    auto& builtinNames = static_cast<JSVMClientData*>(vm.clientData)->builtinNames();

    this->putDirect(vm, Identifier::fromString(&vm, "self"), this->globalExec()->globalThisValue(), PropertyAttribute::DontEnum | PropertyAttribute::ReadOnly | PropertyAttribute::DontDelete);
    this->putDirectNativeFunction(vm, this, builtinNames.closePublicName(), 0, jsWorkerGlobalObjectClose, NoIntrinsic, PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);
    this->putDirectNativeFunction(vm, this, builtinNames.postMessagePublicName(), 2, jsWorkerGlobalObjectPostMessage, NoIntrinsic, PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);
}

void JSWorkerGlobalObject::postMessage(JSC::ExecState* exec, JSC::JSValue message, JSC::JSArray* transferList) {
    UNUSED_PARAM(transferList);
    auto scope = DECLARE_THROW_SCOPE(exec->vm());
    String strMessage = JSONStringify(exec, message, 0);
    if (scope.exception())
        return;
    _workerMessagingProxy->workerPostMessageToParent(strMessage);
}

void JSWorkerGlobalObject::onmessage(ExecState* exec, JSValue message) {
    JSValue onMessageCallback = this->get(exec, _onmessageIdentifier);

    CallData callData;
    CallType callType = JSC::getCallData(exec->vm(), onMessageCallback, callData);
    if (callType == JSC::CallType::None) {
        return;
    }
    JSGlobalObject* globalObject = exec->lexicalGlobalObject();
    Structure* emptyObjectStructure = exec->vm().structureCache.emptyObjectStructureForPrototype(globalObject, globalObject->objectPrototype(), JSFinalObject::defaultInlineCapacity());
    JSFinalObject* onMessageEvent = JSFinalObject::create(exec, emptyObjectStructure);
    onMessageEvent->putDirect(exec->vm(), Identifier::fromString(&exec->vm(), "data"), message);

    MarkedArgumentBuffer onMessageArguments;
    onMessageArguments.append(onMessageEvent);

    call(exec, onMessageCallback, callType, callData, jsUndefined(), onMessageArguments);
}

void JSWorkerGlobalObject::close() {
    _workerMessagingProxy->workerClose();
}

WorkerMessagingProxy* JSWorkerGlobalObject::workerMessagingProxy() {
    return _workerMessagingProxy.get();
}

void JSWorkerGlobalObject::uncaughtErrorReported(const WTF::String& message, const WTF::String& filename, int lineNumber, int colNumber) {
    this->workerMessagingProxy()->workerPostException(message, filename, lineNumber, colNumber);
}
}
