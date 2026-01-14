# Contacts Filter & Segments Architecture Study

This document details the architecture of the Contacts filtering and segmentation system in Starchat (Chatwoot), as requested. It serves as a reference for refactoring the Pipedrive integration to support robust, saved filters (segments) and advanced searching.

## 1. Overview

The Contacts system uses a **generic filtering engine**. Instead of hardcoded parameters (e.g., `?phone=...&email=...`), it relies on a structure named **Custom Views** (or Segments) and a dynamic **Filter Service**.

- **Frontend:** Generates a standardized JSON payload describing the filters (Attribute, Operator, Value, Query Operator).
- **Backend:** Interprets this JSON payload to dynamically construct SQL queries using ActiveRecord.
- **Persistence:** Saved filters are stored as "Segments" in the `CustomFilter` model.

## 2. Frontend Architecture

### 2.1. Components

- **`ContactsListLayout.vue`**: The main layout orchestrator. It handles the display of the contact list, pagination, and the filter header. It listens for `apply-filter` events.
- **`ContactListHeaderWrapper.vue`**: Manages the "Filter" button and the "Segments" dropdown. It contains the logic to open the `ContactsFilter` modal.
- **`ContactsFilter.vue`**: The UI component for building the filter query.
  - It renders a list of `ConditionRow` components.
  - It uses `contactFilterItems/index.js` to know which attributes are available (e.g., Name, Email, Country) and their types.
- **`filterQueryGenerator.js`**: A critical helper that transforms the UI state (Vue reactive objects) into the standardized JSON payload expected by the backend. It handles things like splitting comma-separated values and formatting arrays.

### 2.2. State Management (Vuex)

- **`contacts.js`**: Manages the list of contacts.
  - Action `filter`: Accepts the filter payload and sends it to the `POST /api/v1/accounts/:id/contacts/filter` endpoint.
- **`customViews.js`**: Manages "Segments" (Saved Filters).
  - Action `get`: Fetches saved segments from `/api/v1/accounts/:id/segments`.
  - Action `create`/`update`: Saves the current filter payload to the backend to create a new Segment.

### 2.3. Filter Payload Structure

The frontend sends a JSON payload structured like this:

```json
{
  "payload": [
    {
      "attribute_key": "email",
      "filter_operator": "contains",
      "values": ["example"],
      "query_operator": "and"
    },
    {
      "attribute_key": "phone_number",
      "filter_operator": "equal_to",
      "values": ["+123456789"]
    }
  ]
}
```

## 3. Backend Architecture

### 3.1. Routes

- `POST /contacts/filter` -> `ContactsController#filter`: endpoint for applying temporary filters (search).
- `resources :custom_filters, path: 'segments'` -> `CustomFiltersController`: CRUD for saved segments.

### 3.2. Controllers

- **`Api::V1::Accounts::ContactsController`**:
  - `filter` action: Instantiates `::Contacts::FilterService` with the request `params`. Calls `perform()` to get results and renders them.
- **`Api::V1::Accounts::CustomFiltersController`**:
  - Manages the `CustomFilter` model. When creating a segment, it saves the `query` (the JSON payload) into the database.

### 3.3. Models

- **`CustomFilter`**: Stores the definition of a segment.
  - Attributes: `name`, `filter_type` (e.g., 'conversation', 'contact'), `query` (JSONB column storing the payload).

### 3.4. Services (The Core Logic)

- **`FilterService` (Base Class)**:
  - Located in `app/services/filter_service.rb`.
  - Parsing logic: Iterates through the JSON payload.
  - SQL Generation: Has methods like `equals_to_filter_string`, `ilike_filter_string`, `lt_gt_filter_values`.
  - It dynamically builds ActiveRecord queries (e.g., `where("email ILIKE ?", "%value%")`).
  - It handles basic attributes (text, date) and **Custom Attributes** (JSONB querying within Postgres).
- **`Contacts::FilterService`**:
  - Inherits from `FilterService`.
  - Located in `app/services/contacts/filter_service.rb`.
  - Sets the `base_relation` to `Current.account.contacts`.
  - Handles specifics like normalizing phone numbers before searching.

## 4. How Pipedrive Compares & What Needs to Change

### Current Pipedrive Implementation

- **Frontend:** `DealsIndex.vue` manually maps active filters to specific API parameters (`user_id`, `status`).
- **Backend:** `BrowseResourcesService.rb` expects named arguments (`user_id: 123`) and passes them directly to the Pipedrive Ruby Client.
- **Limitation:** It cannot support complex queries (e.g., "Email contains X AND Created At > Y") because it relies on the simple Pipedrive API endpoints that accept flat parameters.

### Recommendations for Pipedrive Refactoring

To achieve "Contact-like" segmentation for Pipedrive:

1.  **Frontend:**

    - Adopt the `ContactsFilter` generic approach.
    - Generate a "Rich Payload" (JSON) that describes the query fully, rather than crushing it into simple key-values immediately.
    - Store this full JSON in the `CustomFilter` model (or similar) when saving a segment.

2.  **Backend:**

    - **Choice A (Ideal but Hard):** Implement a `Pipedrive::FilterService` that translates the generic JSON payload into Pipedrive's specific "Filter API" (creating a filter on Pipedrive side via API) or doing client-side filtering (fetching all deals and filtering in Ruby - slow).
    - **Choice B (Pragmatic):** Keep the backend using Pipedrive API parameters, BUT update `BrowseResourcesService` to accept a structured `filters` hash.
    - **Choice C (Search):** Use Pipedrive's `/deals/search` endpoint which might support more advanced queries, or the `/filters` endpoint.

    _Crucially_, if we want to support "Segments" that work exactly like Contacts, we must save the _definition_ of the filter (the JSON) and re-apply it. Since we can't run SQL on Pipedrive, we need a translator:
    `Generic JSON Payload` -> `Translator` -> `Pipedrive API Parameters`.

    The `DealsIndex.vue` update I did earlier started this (mapping rich payload to specific params), but to fully emulate Contacts, we need to formalize this "Translator" layer, likely in the backend service, so that a saved Segment (which is just a JSON blob) can be passed to `BrowseResourcesService` and correctly "unpacked" into Pipedrive API calls.
