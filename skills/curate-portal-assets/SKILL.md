---
name: curate-portal-assets
description: |
  Curate API assets in an API Experience Hub portal. Use when an admin needs to
  publish Exchange assets to a portal, adjust which minor versions are visible
  to consumers, or remove assets from a portal. Covers discovery of unpublished
  assets, publishing, visibility configuration and removal.
---

# Curate Portal Assets

## Overview

Curates the API catalog of an API Experience Hub (AEH) portal: discovers Exchange assets that are not yet published, adds selected assets to the portal, inspects the visibility of each minor version, adjusts visibility per version, and removes assets that should no longer be published. The workflow lets portal administrators control exactly which APIs — and which minor versions — are exposed to portal consumers.

**What you'll build:** A curated portal catalog with the right assets and minor-version visibility for your consumers.

## Prerequisites

Before starting, ensure:

1. **Authentication ready**
   - Valid Bearer token for Anypoint Platform
   - **AEH Administrator** or **AEH Portal Administrator** permissions

2. **Environment already bootstrapped** (not covered by this workflow — use the AEH UI for these)
   - The Salesforce Connection has been created in AEH
   - At least one Portal has been created on that connection

## Step 1: List AEH Connections

Retrieve the AEH connections the user has access to. The selected connection's ID is used as `connectionId` in every downstream management call.

**What you'll need:**
- Bearer token

**Action:** List connections and pick the one hosting the target portal.

```yaml
api: urn:api:api-experience-hub-management
operationId: getConnections
inputs: {}
outputs:
  - name: connectionId
    path: $[*].id
    labels: $[*].name
    description: AEH connection ID (Salesforce org link) backing the portal
```

**What happens next:** The chosen `connectionId` scopes every subsequent call to a single Salesforce org connection.

## Step 2: List Portals on the Connection

List the portals that live on the selected connection and pick the target `portalId`.

**What you'll need:**
- `connectionId` from Step 1

**Action:** Retrieve the available portals.

```yaml
api: urn:api:api-experience-hub-management
operationId: getAllApiPortalByConnectionId
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID from Step 1
outputs:
  - name: portalId
    path: $[*].id
    labels: $[*].name
    description: ID of the portal to curate
```

**What happens next:** You now have the `(connectionId, portalId)` pair required by every curation operation.

## Step 3: Discover Unpublished Exchange Assets

Search Exchange for assets that the connected Salesforce org has access to but that are **not yet published** in this portal. This is the candidate list for publication.

**What you'll need:**
- `connectionId` and `portalId` from previous steps
- Optional search query / filters (name, tags, categories)

**Action:** Search unpublished Exchange assets.

```yaml
api: urn:api:api-experience-hub-management
operationId: searchExchangeAssets
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID from Step 1
  portalId:
    from:
      variable: portalId
    description: Portal ID from Step 2
  searchRequest:
    userProvided: true
    description: Search criteria (free-text query, categories, tags, pagination)
    example:
      searchTerm: orders
      limit: 25
      offset: 0
outputs:
  - name: candidateAssets
    path: $.assets[*]
    labels: $.assets[*].name
    description: Exchange assets available for publication in this portal
  - name: candidateGroupId
    path: $.assets[*].groupId
    description: groupId of each candidate asset
  - name: candidateAssetId
    path: $.assets[*].assetId
    description: assetId of each candidate asset
```

**What happens next:** Present candidates to the user and let them pick one or more assets to publish. Collect their `groupId`/`assetId` pairs for Step 4.

## Step 4: Add Assets to the Portal

Publish one or more selected Exchange assets to the portal.

**What you'll need:**
- `connectionId`, `portalId`
- Asset coordinates chosen in Step 3

**Action:** Add assets to the portal catalog.

```yaml
api: urn:api:api-experience-hub-management
operationId: addAssetsToCommunity
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID from Step 1
  portalId:
    from:
      variable: portalId
    description: Portal ID from Step 2
  assetsRequest:
    userProvided: true
    description: Array of Exchange asset references to publish (groupId + assetId, optional minorVersion filter)
    example:
      assets:
        - groupId: f1e97bc6-315a-4490-82a7-23abe036327a
          assetId: orders-api
outputs:
  - name: publishedAssetIds
    path: $[*].assetId
    description: The newly published asset IDs
```

**What happens next:** The assets are now visible in the portal catalog. By default all public minor versions become visible — Step 6 adjusts that.

## Step 5: Inspect Visibility of a Published Asset

Retrieve the current visibility state for each minor version of a published asset so the admin can decide which versions to hide or expose.

**What you'll need:**
- `connectionId`, `portalId`
- `groupId`, `assetId` of the asset to inspect

```yaml
api: urn:api:api-experience-hub-management
operationId: getAllVersionsVisibilityByGA
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  groupId:
    userProvided: true
    description: Exchange groupId of the asset to inspect
  assetId:
    userProvided: true
    description: Exchange assetId of the asset to inspect
outputs:
  - name: versionVisibilities
    path: $.versions[*]
    labels: $.versions[*].minorVersion
    description: Per-minor-version visibility state (published, hidden, profile-restricted)
```

**What happens next:** Present the version list and let the admin toggle visibility per minor version in Step 6.

## Step 6: Update Asset Visibility

Update the visibility of specific minor versions (e.g., hide deprecated versions, restrict new versions to a specific user group).

**What you'll need:**
- `connectionId`, `portalId`, `groupId`, `assetId`
- Visibility changes the admin chose in Step 5

```yaml
api: urn:api:api-experience-hub-management
operationId: updateCommunityAsset
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  groupId:
    from:
      variable: groupId
    description: groupId from Step 5
  assetId:
    from:
      variable: assetId
    description: assetId from Step 5
  visibilityUpdate:
    userProvided: true
    description: Per-minor-version visibility payload
    example:
      versions:
        - minorVersion: "1.0"
          visibility: PUBLISHED
        - minorVersion: "2.0"
          visibility: HIDDEN
outputs:
  - name: updatedAssetId
    path: $.assetId
    description: Confirmed assetId with new visibility applied
```

**What happens next:** Portal consumers now see only the minor versions you marked `PUBLISHED`.

## Step 7: Remove Assets (Optional)

Remove assets that should no longer be exposed — e.g., fully deprecated APIs.

**What you'll need:**
- `connectionId`, `portalId`
- List of `(groupId, assetId)` pairs to remove

```yaml
api: urn:api:api-experience-hub-management
operationId: removeAssetFromCommunity
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  removeRequest:
    userProvided: true
    description: Array of asset coordinates to unpublish
    example:
      assets:
        - groupId: f1e97bc6-315a-4490-82a7-23abe036327a
          assetId: legacy-orders-api
outputs:
  - name: removedAssetIds
    path: $[*].assetId
    description: Assets that were successfully removed from the portal
```

**What happens next:** Consumers no longer see the removed assets. Existing contracts against those assets remain intact but cannot be created anew.

## Completion Checklist

- [ ] Connection and portal selected
- [ ] Candidate Exchange assets identified
- [ ] Selected assets published to the portal
- [ ] Minor-version visibility reviewed and adjusted
- [ ] Deprecated/unwanted assets removed (if applicable)

## What You've Built

✅ **Curated Portal Catalog** — Only the assets and minor versions you intend are visible to portal consumers, matching your publishing strategy.

## Next Steps

1. **Search the published catalog** — Use `searchCommunityAssets` (management) to confirm the final list your portal consumers will see.
2. **Manage portal members** — See the `manage-portal-members-and-prospects` skill to approve consumers who will browse the new assets.
3. **Monitor consumer contracts** — Track contract creation through the consumer API to understand adoption of each newly published asset.

## Related Jobs

- **manage-portal-members-and-prospects** — Approve and manage who can see the curated catalog
- **manage-portal-user-groups** — Define user groups used in version-level visibility restrictions
