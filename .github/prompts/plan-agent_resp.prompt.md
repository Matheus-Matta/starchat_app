## Plan: Responsible Agent Assignment

Add a responsible agent field to contacts and prioritize auto-assignment to that agent when eligible, with a safe fallback to the existing assignment policy. Implement via a DB column, update API payloads, wire frontend select/display, and add backend/frontend tests.

**Steps**
1. Schema and model: add `responsible_agent_id` column on contacts with FK to users, allow nulls, and add association/validation to ensure agent belongs to the same account. *Depends on migration.*
2. API and builders: permit `responsible_agent_id` in contact params; update contact JSON view to include `responsible_agent_id` and nested `responsible_agent` summary; ensure contact creation paths accept the new field.
3. Auto-assignment: in the Starchat/Chatwoot auto-assignment service, look up `conversation.contact.responsible_agent`, validate eligibility (exists, same account, can be assigned), then assign; otherwise fallback to existing policy. *Depends on steps 1-2.*
4. Frontend UI: add responsible agent select to contact form and contact details view, using agents list; allow clear; show current responsible agent display; wire to API update flow. *Parallel with step 3.*
5. Backend tests: controller/model/service specs for create/update/remove, cross-account restriction, and assignment behavior with valid/invalid responsible agent.
6. Frontend tests: component rendering, load existing responsible agent, save changes, clear value, and error handling.

**Relevant files**
- app/models/contact.rb — add association/validation
- app/controllers/api/v1/accounts/contacts_controller.rb — permit params
- app/views/api/v1/models/_contact.json.jbuilder — expose fields
- app/builders/contact_inbox_with_contact_builder.rb — allow field on create
- app/services/auto_assignment/assignment_service.rb
- starchat/app/services/starchat/auto_assignment/assignment_service.rb — add priority check
- app/javascript/dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue — form UI
- app/javascript/dashboard/components-next/Contacts/Pages/ContactDetails.vue — details display
- app/javascript/dashboard/store/modules/contacts/actions.js — update payload
- spec/controllers/api/v1/accounts/contacts_controller_spec.rb — controller tests
- spec/models/contact_spec.rb — model tests
- app/javascript/dashboard/api/specs/contacts.spec.js — API tests

**Verification**
1. Run backend specs for contacts and auto-assignment services.
2. Run frontend unit tests for contacts components and API.
3. Manual: create/edit contact with responsible agent; create new conversation; confirm assignment; clear responsible agent and confirm default assignment.

**Decisions**
- Use `responsible_agent_id` column with FK and allow nulls.
- UI edits in both contact form and contact details view.
