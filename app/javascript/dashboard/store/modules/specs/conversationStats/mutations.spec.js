import types from '../../../mutation-types';
import { mutations } from '../../conversationStats';

describe('#mutations', () => {
  describe('#SET_CONV_TAB_META', () => {
    it('set conversation stats correctly', () => {
      const state = {};
      mutations[types.SET_CONV_TAB_META](state, {
        mine_count: 1,
        unassigned_count: 1,
        all_count: 2,
        open_count: 3,
        in_progress_count: 4,
        resolved_count: 5,
      });
      expect(state).toEqual({
        mineCount: 1,
        unAssignedCount: 1,
        allCount: 2,
        openCount: 3,
        inProgressCount: 4,
        resolvedCount: 5,
        companyCounts: {},
        companyStarredWaitingIds: [],
        noCompanyCount: 0,
        updatedOn: expect.any(Date),
      });
    });
  });
});
