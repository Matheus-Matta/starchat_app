import {
  generateReportURLParams,
  parseReportURLParams,
  parseFilterURLParams,
  generateFilterURLParams,
  generateCompleteURLParams,
  parseCompareIdsParam,
  generateCompareIdsParam,
} from './reportFilterHelper';

describe('reportFilterHelper', () => {
  describe('generateReportURLParams', () => {
    it('generates URL params with from and to dates', () => {
      const params = generateReportURLParams({
        from: 1738607400,
        to: 1770229799,
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
      });
    });

    it('includes business hours when true', () => {
      const params = generateReportURLParams({
        from: 1738607400,
        to: 1770229799,
        businessHours: true,
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
        business_hours: 'true',
      });
    });

    it('excludes business hours when false', () => {
      const params = generateReportURLParams({
        from: 1738607400,
        to: 1770229799,
        businessHours: false,
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
      });
    });

    it('includes group by parameter', () => {
      const params = generateReportURLParams({
        from: 1738607400,
        to: 1770229799,
        groupBy: 3,
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
        group_by: 3,
      });
    });

    it('includes range type', () => {
      const params = generateReportURLParams({
        from: 1738607400,
        to: 1770229799,
        range: 'last7days',
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
        range: 'last7days',
      });
    });

    it('generates complete URL params with all options', () => {
      const params = generateReportURLParams({
        from: 1738607400,
        to: 1770229799,
        businessHours: true,
        groupBy: 3,
        range: 'lastYear',
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
        business_hours: 'true',
        group_by: 3,
        range: 'lastYear',
      });
    });
  });

  describe('parseReportURLParams', () => {
    it('parses from and to dates as numbers', () => {
      const result = parseReportURLParams({
        from: '1738607400',
        to: '1770229799',
      });

      expect(result).toEqual({
        from: 1738607400,
        to: 1770229799,
        businessHours: false,
        groupBy: null,
        range: null,
      });
    });

    it('parses business hours as boolean', () => {
      const result = parseReportURLParams({
        from: '1738607400',
        to: '1770229799',
        business_hours: 'true',
      });

      expect(result.businessHours).toBe(true);
    });

    it('returns false for business hours when not "true"', () => {
      const result = parseReportURLParams({
        from: '1738607400',
        to: '1770229799',
        business_hours: 'false',
      });

      expect(result.businessHours).toBe(false);
    });

    it('parses group by as number', () => {
      const result = parseReportURLParams({
        from: '1738607400',
        to: '1770229799',
        group_by: '3',
      });

      expect(result.groupBy).toBe(3);
    });

    it('parses range type', () => {
      const result = parseReportURLParams({
        from: '1738607400',
        to: '1770229799',
        range: 'last7days',
      });

      expect(result.range).toBe('last7days');
    });

    it('returns null for missing parameters', () => {
      const result = parseReportURLParams({});

      expect(result).toEqual({
        from: null,
        to: null,
        businessHours: false,
        groupBy: null,
        range: null,
      });
    });

    it('parses complete URL params with all options', () => {
      const result = parseReportURLParams({
        from: '1738607400',
        to: '1770229799',
        business_hours: 'true',
        group_by: '3',
        range: 'lastYear',
      });

      expect(result).toEqual({
        from: 1738607400,
        to: 1770229799,
        businessHours: true,
        groupBy: 3,
        range: 'lastYear',
      });
    });

    it('handles numeric values correctly', () => {
      const result = parseReportURLParams({
        from: 1738607400,
        to: 1770229799,
        group_by: 3,
      });

      expect(result.from).toBe(1738607400);
      expect(result.to).toBe(1770229799);
      expect(result.groupBy).toBe(3);
    });
  });

  describe('round-trip conversion', () => {
    it('maintains data integrity through generate and parse cycle', () => {
      const original = {
        from: 1738607400,
        to: 1770229799,
        businessHours: true,
        groupBy: 3,
        range: 'lastYear',
      };

      const urlParams = generateReportURLParams(original);
      const parsed = parseReportURLParams(urlParams);

      expect(parsed.from).toBe(original.from);
      expect(parsed.to).toBe(original.to);
      expect(parsed.businessHours).toBe(original.businessHours);
      expect(parsed.groupBy).toBe(original.groupBy);
      expect(parsed.range).toBe(original.range);
    });
  });

  describe('parseFilterURLParams', () => {
    it('parses a single value into a one-item array', () => {
      const result = parseFilterURLParams({
        agent_id: '123',
        inbox_id: '456',
        team_id: '789',
        sla_policy_id: '101',
        rating: '4',
      });

      expect(result).toEqual({
        agent_id: [123],
        inbox_id: [456],
        team_id: [789],
        sla_policy_id: 101,
        label: [],
        rating: 4,
      });
    });

    it('parses multiple comma-separated values into an array', () => {
      const result = parseFilterURLParams({
        agent_id: '123,456',
        team_id: '7',
      });

      expect(result.agent_id).toEqual([123, 456]);
      expect(result.team_id).toEqual([7]);
    });

    it('parses label as an array of strings', () => {
      const result = parseFilterURLParams({
        label: 'bug,billing',
      });

      expect(result.label).toEqual(['bug', 'billing']);
    });

    it('returns empty arrays and null for missing parameters', () => {
      const result = parseFilterURLParams({});

      expect(result).toEqual({
        agent_id: [],
        inbox_id: [],
        team_id: [],
        sla_policy_id: null,
        label: [],
        rating: null,
      });
    });
  });

  describe('generateFilterURLParams', () => {
    it('joins multiple ids with a comma', () => {
      const params = generateFilterURLParams({
        agent_id: [123, 456],
        inbox_id: [],
        team_id: [789],
        rating: null,
      });

      expect(params).toEqual({
        agent_id: '123,456',
        team_id: '789',
      });
    });

    it('includes label when present', () => {
      const params = generateFilterURLParams({
        label: ['bug', 'billing'],
      });

      expect(params).toEqual({
        label: 'bug,billing',
      });
    });

    it('returns empty object when all values are empty', () => {
      const params = generateFilterURLParams({
        agent_id: [],
        inbox_id: [],
        team_id: [],
      });

      expect(params).toEqual({});
    });
  });

  describe('generateCompleteURLParams', () => {
    it('merges date and filter params', () => {
      const params = generateCompleteURLParams({
        from: 1738607400,
        to: 1770229799,
        range: 'last7days',
        filters: {
          agent_id: [123],
          inbox_id: [456],
        },
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
        range: 'last7days',
        agent_id: '123',
        inbox_id: '456',
      });
    });

    it('handles empty filters', () => {
      const params = generateCompleteURLParams({
        from: 1738607400,
        to: 1770229799,
        range: 'last7days',
        filters: {},
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
        range: 'last7days',
      });
    });

    it('excludes empty filter values', () => {
      const params = generateCompleteURLParams({
        from: 1738607400,
        to: 1770229799,
        filters: {
          agent_id: [123],
          inbox_id: [],
          team_id: [456],
        },
      });

      expect(params).toEqual({
        from: 1738607400,
        to: 1770229799,
        agent_id: '123',
        team_id: '456',
      });
    });
  });

  describe('parseCompareIdsParam', () => {
    it('parses a comma-separated list of ids as numbers', () => {
      expect(parseCompareIdsParam({ compare_ids: '4,7,12' })).toEqual([
        4, 7, 12,
      ]);
    });

    it('returns an empty array when missing', () => {
      expect(parseCompareIdsParam({})).toEqual([]);
    });

    it('ignores non-numeric entries', () => {
      expect(parseCompareIdsParam({ compare_ids: '4,abc,7' })).toEqual([4, 7]);
    });
  });

  describe('generateCompareIdsParam', () => {
    it('joins ids into a comma-separated param', () => {
      expect(generateCompareIdsParam([4, 7, 12])).toEqual({
        compare_ids: '4,7,12',
      });
    });

    it('returns an empty object when ids are empty', () => {
      expect(generateCompareIdsParam([])).toEqual({});
    });

    it('returns an empty object when ids are not provided', () => {
      expect(generateCompareIdsParam(undefined)).toEqual({});
    });
  });
});
