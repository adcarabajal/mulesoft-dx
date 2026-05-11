---
name: manage-portal-user-groups
description: |
  Manage the user groups that gate access to APIs and content inside an API
  Experience Hub portal. Use when an admin needs to list, create, update, or
  delete user groups, or to manage group mappings (links between external
  identity-provider groups and AEH user groups). These groups are the unit
  used for per-version asset visibility and member assignments.
---

# Manage Portal User Groups

## Overview

User groups are the authorization primitive inside an API Experience Hub (AEH) portal. They control which members can see which APIs/minor versions, and they can be mapped to groups coming from a federated identity provider (IdP) so membership is synchronized automatically at login. This workflow covers the full user-group lifecycle and their IdP mappings.

**What you'll build:** A clean, well-scoped set of user groups (and IdP mappings) that AEH can use for asset visibility and member permissioning.

## Prerequisites

Before starting, ensure:

1. **Authentication ready**
   - Valid Bearer token for Anypoint Platform
   - **AEH Administrator** or **AEH Portal Administrator** permissions

2. **Environment already bootstrapped**
   - Connection and portal already created
   - Optional: an IdP configured on the portal (needed only for group mappings)

## Step 1: List AEH Connections

```yaml
api: urn:api:api-experience-hub-management
operationId: getConnections
inputs: {}
outputs:
  - name: connectionId
    path: $[*].id
    labels: $[*].name
    description: AEH connection ID backing the portal
```

## Step 2: List Portals on the Connection

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
    description: ID of the portal whose user groups you'll manage
```

## Step 3: List User Groups (Profiles)

Retrieve the existing user groups on the portal so the admin can decide whether to create, update, or delete them.

**What you'll need:**
- `connectionId`, `portalId`

```yaml
api: urn:api:api-experience-hub-management
operationId: getAllProfilesByPortal
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
outputs:
  - name: userGroups
    path: $.profiles[*]
    labels: $.profiles[*].name
    description: Existing user groups (profiles) on the portal
  - name: userGroupId
    path: $.profiles[*].id
    description: ID of a specific user group, used by update/delete
```

**What happens next:** Present the list and let the admin pick the next action (create/update/delete or manage mappings).

## Step 4: Create a New User Group

```yaml
api: urn:api:api-experience-hub-management
operationId: createUserGroup
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  userGroupRequest:
    userProvided: true
    description: Definition of the new user group
    example:
      name: Gold Tier Consumers
      description: Members granted access to premium APIs
outputs:
  - name: createdUserGroupId
    path: $.id
    description: The newly created user group ID
```

**What happens next:** The new group is available for asset visibility rules and member assignments.

## Step 5: Update an Existing User Group

Rename or change the description of a group. The group membership itself is updated via `manage-portal-members-and-prospects`.

**What you'll need:**
- `connectionId`, `portalId`, `userGroupId`

```yaml
api: urn:api:api-experience-hub-management
operationId: updateUserGroup
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  userGroupId:
    from:
      variable: userGroupId
    description: ID of the user group to update
  userGroupRequest:
    userProvided: true
    description: Updated name/description for the user group
    example:
      name: Gold Tier Consumers (EU)
      description: Members granted access to premium EU-region APIs
outputs:
  - name: updatedUserGroupId
    path: $.id
    description: Confirmed ID of the updated user group
```

## Step 6: Delete a User Group (Optional)

Remove a user group that is no longer needed. Verify no members or visibility rules depend on it first.

**What you'll need:**
- `connectionId`, `portalId`, `userGroupId`

```yaml
api: urn:api:api-experience-hub-management
operationId: deleteUserGroup
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  userGroupId:
    from:
      variable: userGroupId
    description: ID of the user group to delete
outputs:
  - name: deletedUserGroupId
    path: $.id
    description: Confirmation of the deleted user group
```

**What happens next:** The group is gone; any visibility rules or member assignments that referenced it need to be revisited.

## Step 7: List Group Mappings

Group mappings link a federated IdP group (SAML / OIDC) to an AEH user group so membership syncs at login.

**What you'll need:**
- `connectionId`, `portalId`

```yaml
api: urn:api:api-experience-hub-management
operationId: getGroupMappings
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
outputs:
  - name: groupMappings
    path: $.mappings[*]
    labels: $.mappings[*].idpGroupName
    description: Existing IdP-to-AEH group mappings
  - name: groupMappingId
    path: $.mappings[*].id
    description: ID used to delete a mapping
```

## Step 8: Create a Group Mapping

Link an IdP group to an AEH user group.

**What you'll need:**
- `connectionId`, `portalId`
- The AEH `userGroupId` (from Step 3) and the IdP group identifier

```yaml
api: urn:api:api-experience-hub-management
operationId: addAdditionalGroupMapping
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  mappingRequest:
    userProvided: true
    description: Mapping between an external IdP group and an AEH user group
    example:
      idpGroupName: "gold-tier-consumers"
      userGroupId: 00G1a000000abcD
outputs:
  - name: createdGroupMappingId
    path: $.id
    description: The newly created mapping ID
```

**What happens next:** Users who log in via the IdP and belong to the mapped IdP group are automatically placed into the AEH user group.

## Step 9: Delete a Group Mapping (Optional)

Remove a stale mapping — e.g., when the IdP group has been renamed or retired.

**What you'll need:**
- `connectionId`, `portalId`, `groupMappingId`

```yaml
api: urn:api:api-experience-hub-management
operationId: deleteGroupMappings
inputs:
  connectionId:
    from:
      variable: connectionId
    description: Connection ID
  portalId:
    from:
      variable: portalId
    description: Portal ID
  groupMappingId:
    from:
      variable: groupMappingId
    description: ID of the mapping to remove
outputs:
  - name: deletedGroupMappingId
    path: $.id
    description: Confirmation of the removed mapping
```

## Completion Checklist

- [ ] Connection and portal selected
- [ ] Existing user groups inventoried
- [ ] New user groups created as required
- [ ] Outdated user groups renamed or deleted
- [ ] IdP group mappings reviewed and updated

## What You've Built

✅ **Governed User-Group Model** — A set of well-named user groups and IdP mappings that cleanly drive asset visibility and member permissioning.

## Next Steps

1. **Restrict asset visibility** — See `curate-portal-assets` Step 6 to hide or expose specific minor versions per user group.
2. **Assign members** — See `manage-portal-members-and-prospects` to place portal members into the correct groups.

## Related Jobs

- **curate-portal-assets** — Apply these user groups to asset-visibility decisions
- **manage-portal-members-and-prospects** — Assign portal members into these user groups
