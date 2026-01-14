import getters from '../getters';
import * as helpers from '../helpers';

// Mock filters since we are not testing page filters deeply here
// But getters use applyPageFilters from helpers.
// We can let it run if filters are empty.

describe('Conversation Getters', () => {
  describe('getUnAssignedChats', () => {
    const runGetter = permissionsList => {
      const state = {
        allConversations: [
          {
            id: 1,
            meta: { assignee: null, team: { id: 1 } },
            inbox_id: 1,
            status: 'open',
          }, // Team 1 (Mine), Unassigned
          {
            id: 2,
            meta: { assignee: null, team: { id: 2 } },
            inbox_id: 1,
            status: 'open',
          }, // Team 2 (Other), Unassigned
          {
            id: 3,
            meta: { assignee: { id: 99 }, team: { id: 1 } },
            inbox_id: 1,
            status: 'open',
          }, // Team 1, Assigned (Should filter out by isUnAssigned check)
        ],
        appliedFilters: [],
      };

      const rootGetters = {
        getCurrentUser: {
          id: 100,
          accounts: [
            {
              id: 1,
              role: 'agent',
              custom_role_id: 123,
              permissions: permissionsList,
            },
          ],
        },
        getCurrentAccountId: 1,
        'teams/getMyTeams': [{ id: 1 }],
      };

      const activeFilters = {
        status: 'open',
      };

      // The getter returns a function that takes activeFilters
      return getters.getUnAssignedChats(
        state,
        null,
        null,
        rootGetters
      )(activeFilters);
    };

    it('returns ALL unassigned conversations (Team + Global) when user has Unassigned Manage permission', () => {
      const permissions = [
        'conversation_team_manage',
        'conversation_unassigned_manage',
      ];
      const result = runGetter(permissions);

      // Should include ID 1 (Team) and ID 2 (Global)
      const ids = result.map(c => c.id);
      expect(ids).toContain(1);
      expect(ids).toContain(2);
      expect(ids).not.toContain(3);
      expect(result.length).toBe(2);
    });

    it('returns ONLY Team unassigned conversations when user has ONLY Team Manage permission', () => {
      const permissions = ['conversation_team_manage'];
      const result = runGetter(permissions);

      // Should include ID 1 (Team) ONLY
      const ids = result.map(c => c.id);
      expect(ids).toContain(1);
      expect(ids).not.toContain(2);
      expect(ids).not.toContain(3);
      expect(result.length).toBe(1);
    });
  });
});
