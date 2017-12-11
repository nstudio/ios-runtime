#include "DomainInspectorAgent.h"
#include "GlobalObjectInspectorController.h"
#include <JavaScriptCore/JSObject.h>

namespace NativeScript {
DomainInspectorAgent::DomainInspectorAgent(WTF::String domainName, JSC::JSCell* constructorFunction, Inspector::JSAgentContext& context)
    : Inspector::InspectorAgentBase(domainName)
    , m_context(context)
    , m_constructorFunction(m_context.inspectedGlobalObject.vm(), constructorFunction) {}

void DomainInspectorAgent::didCreateFrontendAndBackend(Inspector::FrontendRouter*, Inspector::BackendDispatcher* backendDispatcher) {
    if (!this->m_domainBackendDispatcher) {
        this->m_domainBackendDispatcher = DomainBackendDispatcher::create(this->domainName(), m_constructorFunction.get(), m_context);
    }
}

void DomainInspectorAgent::willDestroyFrontendAndBackend(Inspector::DisconnectReason) {
}

void DomainInspectorAgent::discardAgent() {
    m_constructorFunction.clear();
}
} // namespace NativeScript
